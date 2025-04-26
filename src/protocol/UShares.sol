// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IERC4626 } from "../interfaces/IERC4626.sol";
import { IMessageTransmitter } from "../interfaces/IMessageTransmitter.sol";
import { IPositionManager } from "../interfaces/IPositionManager.sol";
import { ITokenMessenger } from "../interfaces/ITokenMessenger.sol";
import { IVaultRegistry } from "../interfaces/IVaultRegistry.sol";
import { CCTPAdapter } from "../libraries/logic/CCTPAdapter.sol";
import { USharesToken } from "./USharesToken.sol";

import { Errors } from "../libraries/core/Errors.sol";
import { DataTypes } from "../libraries/types/DataTypes.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title UShares
 * @notice Main entry point for the UShares protocol
 * @dev Handles deposits, withdrawals, and cross-chain operations
 */
contract UShares is CCTPAdapter, OwnableRoles, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for admin operations
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    /// @notice Role identifier for bridge operations
    uint256 public constant BRIDGE_ROLE = _ROLE_1;
    /// @notice Maximum timeout period for pending operations
    uint256 public constant MAX_TIMEOUT = 1 days;
    /// @notice Basis points denominator
    uint256 private constant BASIS_POINTS = 10_000;
    /// @notice Maximum fee in basis points (1%)
    uint256 private constant MAX_FEE = 100;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The UShares token contract
    USharesToken public immutable uSharesToken;

    /// @notice The position manager contract
    IPositionManager public immutable positionManager;

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice Mapping of domain to minimum deposit amount
    mapping(uint32 => uint256) public minDeposit;

    /// @notice Mapping of domain to maximum deposit amount
    mapping(uint32 => uint256) public maxDeposit;

    /// @notice Mapping to track pending deposits
    mapping(bytes32 => DataTypes.PendingDeposit) public pendingDeposits;

    /// @notice Mapping of source chain to UShares contract
    mapping(uint32 => address) public sourceChainUShares;

    /// @notice Mapping to track pending withdrawals
    mapping(bytes32 => DataTypes.PendingWithdrawal) public pendingWithdrawals;

    /// @notice Protocol fee in basis points
    uint256 public protocolFee;
    /// @notice Fee collector address
    address public feeCollector;
    /// @notice Chain-specific fees
    mapping(uint32 => uint256) public chainFees;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event DepositInitiated(
        address indexed user, uint32 destinationChain, address indexed vault, uint256 amount, uint256 minSharesExpected
    );

    event WithdrawalInitiated(
        address indexed user, uint32 destinationChain, address indexed vault, uint256 shares, uint256 minUsdcExpected
    );

    event LimitsUpdated(uint32 domain, uint256 minAmount, uint256 maxAmount);

    event CrossChainDepositCompleted(
        bytes32 indexed depositId, address indexed user, address indexed vault, uint256 shares
    );

    event CrossChainWithdrawalInitiated(
        bytes32 indexed withdrawalId,
        address indexed user,
        address indexed vault,
        uint256 shares,
        uint256 minUsdcExpected
    );

    event CrossChainWithdrawalCompleted(
        bytes32 indexed withdrawalId, address indexed user, address indexed vault, uint256 usdcAmount
    );

    event DepositTimeout(bytes32 indexed depositId, address user, uint256 amount);
    event WithdrawalTimeout(bytes32 indexed withdrawalId, address user, uint256 shares);
    event EmergencyWithdraw(address token, uint256 amount, address to);

    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event ChainFeeUpdated(uint32 chain, uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address oldCollector, address newCollector);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    modifier validAmount(uint32 domain, uint256 amount) {
        if (amount < minDeposit[domain] || amount > maxDeposit[domain]) {
            revert Errors.InvalidAmount();
        }
        _;
    }

    modifier onlyBridge() {
        if (!hasAnyRole(msg.sender, BRIDGE_ROLE)) revert Errors.NotBridge();
        _;
    }

    modifier validDeadline(uint256 deadline) {
        if (deadline <= block.timestamp) revert Errors.InvalidDeadline();
        if (deadline > block.timestamp + MAX_TIMEOUT) revert Errors.DeadlineTooFar();
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert Errors.ZeroAddress();
        _;
    }

    modifier validFee(uint256 fee) {
        if (fee > MAX_FEE) revert Errors.InvalidFee();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _usdc,
        ITokenMessenger _cctpTokenMessenger,
        USharesToken _uSharesToken,
        IVaultRegistry _vaultRegistry,
        IPositionManager _positionManager,
        IMessageTransmitter _messageTransmitter
    )
        CCTPAdapter(_usdc, _cctpTokenMessenger, _messageTransmitter, _vaultRegistry)
    {
        uSharesToken = _uSharesToken;
        vaultRegistry = _vaultRegistry;
        positionManager = _positionManager;

        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ADMIN_ROLE);
        _grantRoles(address(_cctpTokenMessenger), BRIDGE_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                    Fallback and Receive Functions
    //////////////////////////////////////////////////////////////*/
    // Explicitly reject any Ether sent to the contract
    fallback() external payable {
        revert Errors.Fallback();
    }

    // Explicitly reject any Ether transfered to the contract
    receive() external payable {
        revert Errors.CantReceiveETH();
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit USDC to get vault exposure
     * @param amount Amount of USDC to deposit
     * @param destinationChain Chain ID where vault exists
     * @param vault Vault address to deposit into
     * @param minSharesExpected Minimum shares expected to receive
     * @param deadline Timestamp after which transaction reverts
     */
    function deposit(
        uint256 amount,
        uint32 destinationChain,
        address vault,
        uint256 minSharesExpected,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        validAmount(destinationChain, amount)
        validAddress(vault)
    {
        if (block.timestamp > deadline) revert Errors.DeadlineExpired();
        if (!vaultRegistry.isVaultActive(destinationChain, vault)) {
            revert Errors.VaultNotActive();
        }

        // Calculate fees
        uint256 fee = _calculateFee(amount, destinationChain);
        uint256 depositAmount = amount - fee;

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Handle fees
        if (fee > 0 && feeCollector != address(0)) {
            usdc.safeTransfer(feeCollector, fee);
        }

        // If same chain, deposit directly
        if (destinationChain == block.chainid) {
            _handleSameChainDeposit(msg.sender, vault, depositAmount, minSharesExpected);
        } else {
            // Handle cross-chain deposit
            _handleCrossChainDeposit(msg.sender, destinationChain, vault, depositAmount, minSharesExpected, deadline);
        }

        emit DepositInitiated(msg.sender, destinationChain, vault, depositAmount, minSharesExpected);
    }

    /**
     * @notice Withdraw USDC from vault position
     * @param shares Amount of shares to withdraw
     * @param destinationChain Chain ID where vault exists
     * @param vault Vault address to withdraw from
     * @param minUsdcExpected Minimum USDC expected to receive
     * @param deadline Timestamp after which transaction reverts
     */
    function withdraw(
        uint256 shares,
        uint32 destinationChain,
        address vault,
        uint256 minUsdcExpected,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        validAddress(vault)
    {
        if (block.timestamp > deadline) revert Errors.DeadlineExpired();
        if (!vaultRegistry.isVaultActive(destinationChain, vault)) {
            revert Errors.VaultNotActive();
        }

        // If same chain, withdraw directly
        if (destinationChain == block.chainid) {
            _handleSameChainWithdrawal(msg.sender, vault, shares, minUsdcExpected);
            // Burn after successful withdrawal
            uSharesToken.burnFrom(msg.sender, shares);
        } else {
            // Handle cross-chain withdrawal
            _handleCrossChainWithdrawal(msg.sender, destinationChain, vault, shares, minUsdcExpected, deadline);
            // For cross-chain, burn immediately as position is tracked
            uSharesToken.burnFrom(msg.sender, shares);
        }

        emit WithdrawalInitiated(msg.sender, destinationChain, vault, shares, minUsdcExpected);
    }

    /**
     * @notice Update deposit limits for a domain
     * @param domain The domain ID
     * @param _minDeposit Minimum deposit amount
     * @param _maxDeposit Maximum deposit amount
     */
    function updateLimits(uint32 domain, uint256 _minDeposit, uint256 _maxDeposit) external onlyRoles(ADMIN_ROLE) {
        if (_minDeposit >= _maxDeposit) revert Errors.InvalidConfig();

        minDeposit[domain] = _minDeposit;
        maxDeposit[domain] = _maxDeposit;

        emit LimitsUpdated(domain, _minDeposit, _maxDeposit);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRoles(ADMIN_ROLE) {
        paused = true;
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRoles(ADMIN_ROLE) {
        paused = false;
    }

    /**
     * @notice Complete a cross-chain deposit on the destination chain
     * @param depositId The unique deposit identifier
     */
    function completeDeposit(bytes32 depositId) external onlyBridge {
        DataTypes.PendingDeposit memory pendingDeposit = pendingDeposits[depositId];
        if (pendingDeposit.timestamp == 0) revert Errors.InvalidDeposit();
        if (block.timestamp > pendingDeposit.timestamp + MAX_TIMEOUT) revert Errors.DepositExpired();
        if (sourceChainUShares[pendingDeposit.sourceChain] == address(0)) revert Errors.InvalidSource();

        // Clear pending deposit
        delete pendingDeposits[depositId];

        // Get the vault
        address vault = pendingDeposit.vault;
        if (!vaultRegistry.isVaultActive(uint32(block.chainid), vault)) {
            revert Errors.VaultNotActive();
        }

        // Approve and deposit into vault
        usdc.safeApprove(vault, pendingDeposit.amount);
        uint256 shares = IERC4626(vault).deposit(pendingDeposit.amount, address(this));
        if (shares < pendingDeposit.minSharesExpected) revert Errors.InsufficientShares();

        // Update position with actual shares
        bytes32 positionKey = positionManager.getPositionKey(
            pendingDeposit.user, pendingDeposit.sourceChain, uint32(block.chainid), vault
        );
        positionManager.updatePosition(positionKey, shares);

        // Mint uShares tokens to user
        uSharesToken.mint(pendingDeposit.user, shares);

        emit CrossChainDepositCompleted(depositId, pendingDeposit.user, vault, shares);
    }

    /**
     * @notice Handle cross-chain withdrawal completion
     * @param withdrawalId The unique withdrawal identifier
     */
    function completeWithdrawal(bytes32 withdrawalId) external onlyBridge {
        DataTypes.PendingWithdrawal memory withdrawal = pendingWithdrawals[withdrawalId];
        if (withdrawal.timestamp == 0) revert Errors.InvalidWithdrawal();
        if (block.timestamp > withdrawal.timestamp + MAX_TIMEOUT) revert Errors.WithdrawalExpired();

        // Clear pending withdrawal
        delete pendingWithdrawals[withdrawalId];

        // Withdraw from vault
        uint256 usdcAmount = IERC4626(withdrawal.vault).redeem(withdrawal.shares, address(this), address(this));

        if (usdcAmount < withdrawal.minUsdcExpected) revert Errors.InsufficientUSDC();

        // Bridge USDC back to user
        _transferUsdcWithMessage(withdrawal.destinationChain, withdrawal.user, usdcAmount, "");

        emit CrossChainWithdrawalCompleted(withdrawalId, withdrawal.user, withdrawal.vault, usdcAmount);
    }

    /**
     * @notice Clean up timed out deposits
     * @param depositIds Array of deposit IDs to clean up
     */
    function cleanupTimedOutDeposits(bytes32[] calldata depositIds) external {
        for (uint256 i = 0; i < depositIds.length; i++) {
            DataTypes.PendingDeposit memory timedOutDeposit = pendingDeposits[depositIds[i]];
            if (timedOutDeposit.timestamp != 0 && block.timestamp > timedOutDeposit.timestamp + MAX_TIMEOUT) {
                // Refund logic would be handled by governance
                delete pendingDeposits[depositIds[i]];
                emit DepositTimeout(depositIds[i], timedOutDeposit.user, timedOutDeposit.amount);
            }
        }
    }

    /**
     * @notice Clean up timed out withdrawals
     * @param withdrawalIds Array of withdrawal IDs to clean up
     */
    function cleanupTimedOutWithdrawals(bytes32[] calldata withdrawalIds) external {
        for (uint256 i = 0; i < withdrawalIds.length; i++) {
            DataTypes.PendingWithdrawal memory withdrawal = pendingWithdrawals[withdrawalIds[i]];
            if (withdrawal.timestamp != 0 && block.timestamp > withdrawal.timestamp + MAX_TIMEOUT) {
                delete pendingWithdrawals[withdrawalIds[i]];
                emit WithdrawalTimeout(withdrawalIds[i], withdrawal.user, withdrawal.shares);
            }
        }
    }

    /**
     * @notice Emergency withdraw stuck tokens
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyRoles(ADMIN_ROLE) whenNotPaused {
        Errors.verifyAddress(token);
        token.safeTransfer(owner(), amount);
        emit EmergencyWithdraw(token, amount, owner());
    }

    /**
     * @notice Set protocol fee
     * @param newFee New fee in basis points
     */
    function setProtocolFee(uint256 newFee) external onlyRoles(ADMIN_ROLE) validFee(newFee) {
        uint256 oldFee = protocolFee;
        protocolFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Set chain-specific fee
     * @param chain Chain ID
     * @param newFee New fee in basis points
     */
    function setChainFee(uint32 chain, uint256 newFee) external onlyRoles(ADMIN_ROLE) validFee(newFee) {
        uint256 oldFee = chainFees[chain];
        chainFees[chain] = newFee;
        emit ChainFeeUpdated(chain, oldFee, newFee);
    }

    /**
     * @notice Set fee collector address
     * @param newCollector New fee collector address
     */
    function setFeeCollector(address newCollector) external onlyRoles(ADMIN_ROLE) validAddress(newCollector) {
        address oldCollector = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(oldCollector, newCollector);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate total fee for operation
     * @param amount Base amount
     * @param destinationChain Destination chain ID
     * @return Total fee amount
     */
    function _calculateFee(uint256 amount, uint32 destinationChain) internal view returns (uint256) {
        uint256 totalFeeRate = protocolFee + chainFees[destinationChain];
        return (amount * totalFeeRate) / BASIS_POINTS;
    }

    /**
     * @notice Handle deposit on same chain
     * @param user User address
     * @param vault Vault address
     * @param amount Amount of USDC
     * @param minSharesExpected Minimum shares expected
     */
    function _handleSameChainDeposit(address user, address vault, uint256 amount, uint256 minSharesExpected) internal {
        // Approve vault to spend USDC
        usdc.safeApprove(vault, amount);

        // Deposit into vault
        uint256 shares = IERC4626(vault).deposit(amount, address(this));
        if (shares < minSharesExpected) revert Errors.InsufficientShares();

        // Create position and store position key
        positionManager.createPosition(user, uint32(block.chainid), uint32(block.chainid), vault, shares);

        // Mint uShares tokens
        uSharesToken.mint(user, shares);
    }

    function _handleCrossChainDeposit(
        address user,
        uint32 destinationChain,
        address vault,
        uint256 amount,
        uint256 minSharesExpected,
        // solhint-disable-next-line no-unused-vars
        uint256 deadline // Required for interface compatibility
    )
        internal
    {
        bytes32 depositId =
            keccak256(abi.encode(user, uint32(block.chainid), destinationChain, vault, amount, block.timestamp));

        // Store pending deposit info
        pendingDeposits[depositId] = DataTypes.PendingDeposit({
            user: user,
            sourceChain: uint32(block.chainid),
            vault: vault,
            amount: amount,
            minSharesExpected: minSharesExpected,
            timestamp: uint64(block.timestamp)
        });

        // Encode deposit data
        bytes memory message = abi.encode(depositId, user, vault, amount, minSharesExpected);

        // Bridge USDC with message
        _transferUsdcWithMessage(destinationChain, address(this), amount, message);
    }

    /**
     * @notice Handle received message from CCTP
     * @param sourceDomain Source domain of the message
     * @param message The message data
     */
    function _handleReceivedMessage(
        uint32 sourceDomain,
        bytes memory message,
        // solhint-disable-next-line no-unused-vars
        bytes memory attestation // Required by CCTP interface
    )
        internal
        override
    {
        // Decode message
        (bytes32 depositId, address user, address vault, uint256 amount, uint256 minSharesExpected) =
            abi.decode(message, (bytes32, address, address, uint256, uint256));

        // Complete deposit
        _completeDeposit(depositId, sourceDomain, user, vault, amount, minSharesExpected);
    }

    /**
     * @notice Internal function to complete deposit
     */
    function _completeDeposit(
        bytes32 depositId,
        uint32 sourceDomain,
        address user,
        address vault,
        uint256 amount,
        uint256 minSharesExpected
    )
        internal
    {
        // Verify vault is active
        if (!vaultRegistry.isVaultActive(uint32(block.chainid), vault)) {
            revert Errors.VaultNotActive();
        }

        // Approve and deposit into vault
        usdc.safeApprove(vault, amount);
        uint256 shares = IERC4626(vault).deposit(amount, address(this));
        if (shares < minSharesExpected) revert Errors.InsufficientShares();

        // Create or update position
        bytes32 positionKey = positionManager.getPositionKey(user, sourceDomain, uint32(block.chainid), vault);

        // If position doesn't exist, create it
        if (!positionManager.isPositionActive(positionKey)) {
            positionManager.createPosition(user, sourceDomain, uint32(block.chainid), vault, shares);
        } else {
            positionManager.updatePosition(positionKey, shares);
        }

        // Mint uShares tokens to user
        uSharesToken.mint(user, shares);

        emit CrossChainDepositCompleted(depositId, user, vault, shares);
    }

    function _handleCrossChainWithdrawal(
        address user,
        uint32 destinationChain,
        address vault,
        uint256 shares,
        uint256 minUsdcExpected,
        // solhint-disable-next-line no-unused-vars
        uint256 deadline // Required for interface compatibility
    )
        internal
    {
        bytes32 withdrawalId =
            keccak256(abi.encode(user, uint32(block.chainid), destinationChain, vault, shares, block.timestamp));

        pendingWithdrawals[withdrawalId] = DataTypes.PendingWithdrawal({
            user: user,
            sourceChain: uint32(block.chainid),
            destinationChain: destinationChain,
            vault: vault,
            shares: shares,
            minUsdcExpected: minUsdcExpected,
            timestamp: uint64(block.timestamp)
        });

        emit CrossChainWithdrawalInitiated(withdrawalId, user, vault, shares, minUsdcExpected);
    }

    /**
     * @notice Handle withdrawal on same chain
     * @param user User address
     * @param vault Vault address
     * @param shares Amount of shares
     * @param minUsdcExpected Minimum USDC expected
     */
    function _handleSameChainWithdrawal(
        address user,
        address vault,
        uint256 shares,
        uint256 minUsdcExpected
    )
        internal
    {
        // Withdraw from vault
        uint256 usdcAmount = IERC4626(vault).redeem(shares, user, address(this));

        if (usdcAmount < minUsdcExpected) revert Errors.InsufficientUSDC();

        // Update position
        bytes32 positionKey = positionManager.getPositionKey(user, uint32(block.chainid), uint32(block.chainid), vault);
        positionManager.closePosition(positionKey);
    }
}
