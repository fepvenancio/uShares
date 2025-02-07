// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "solady/tokens/ERC20.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IUSharesToken} from "./interfaces/IUSharesToken.sol";
import {ICCTToken} from "./interfaces/ICCTToken.sol";
import {ICCTP} from "./interfaces/ICCTP.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {Errors} from "./libs/Errors.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {IVaultRegistry} from "./interfaces/IVaultRegistry.sol";
import {DataTypes} from "./types/DataTypes.sol";
import "forge-std/console2.sol";

/**
 * @title UShareToken
 * @notice Cross-chain share token implementation for the uShares protocol
 * @dev Represents shares in ERC4626 vaults across different chains
 */
contract USharesToken is IUSharesToken, ICCTToken, ERC20, OwnableRoles {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Roles
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant MINTER_ROLE = _ROLE_1;
    uint256 public constant BURNER_ROLE = _ROLE_2;
    uint256 public constant TOKEN_POOL_ROLE = _ROLE_3;
    uint256 public constant CCIP_ADMIN_ROLE = _ROLE_4;

    // Protocol Constants
    uint256 public constant PROCESS_TIMEOUT = 1 hours;
    uint256 public constant MAX_TRANSACTION_SIZE = 1_000_000e6; // 1M USDC

    // CCTP V1 Domain Constants
    uint32 private constant ETHEREUM_DOMAIN = 0;
    uint32 private constant AVALANCHE_DOMAIN = 1;
    uint32 private constant OPTIMISM_DOMAIN = 2;
    uint32 private constant ARBITRUM_DOMAIN = 3;
    uint32 private constant BASE_DOMAIN = 6;
    uint32 private constant POLYGON_DOMAIN = 7;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    // Immutable state
    uint32 public immutable chainId;
    address public immutable positionManager;
    address public immutable USDC;
    IRouter public immutable router;

    // Mutable state
    IVaultRegistry public vaultRegistry;
    ICCTP public cctp;
    address public tokenPool;
    bool public paused;

    // Mappings
    mapping(uint32 => mapping(address => address)) public chainToVaultMapping;
    mapping(bytes32 => CrossChainDeposit) public deposits;
    mapping(bytes32 => CrossChainWithdrawal) public withdrawals;
    mapping(bytes32 => bool) public processedMessages;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    modifier onlyMinter() {
        if (!hasAnyRole(msg.sender, MINTER_ROLE)) revert Errors.NotMinter();
        _;
    }

    modifier onlyBurner() {
        if (!hasAnyRole(msg.sender, BURNER_ROLE)) revert Errors.NotBurner();
        _;
    }

    modifier onlyTokenPool() {
        if (!hasAnyRole(msg.sender, TOKEN_POOL_ROLE)) revert Errors.NotTokenPool();
        _;
    }

    modifier onlyPositionManager() {
        if (msg.sender != positionManager) revert Errors.NotPositionManager();
        _;
    }

    modifier onlyCCIPAdmin() {
        if (!hasAnyRole(msg.sender, CCIP_ADMIN_ROLE)) revert Errors.NotCCIPAdmin();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint32 _chainId,
        address _positionManager,
        address _ccipAdmin,
        address _cctp,
        address _usdc,
        address _router
    ) {
        Errors.verifyAddress(_positionManager);
        Errors.verifyAddress(_ccipAdmin);
        Errors.verifyAddress(_cctp);
        Errors.verifyAddress(_usdc);
        Errors.verifyAddress(_router);

        chainId = _chainId;
        positionManager = _positionManager;
        vaultRegistry = IVaultRegistry(address(0)); // Will be set by owner
        cctp = ICCTP(_cctp);
        USDC = _usdc;
        router = IRouter(_router);
        
        _initializeOwner(msg.sender);
        
        // Configure initial roles
        _grantRoles(msg.sender, ADMIN_ROLE | CCIP_ADMIN_ROLE);
        _grantRoles(_positionManager, MINTER_ROLE | BURNER_ROLE);
        _grantRoles(_ccipAdmin, CCIP_ADMIN_ROLE);
        
        emit MinterConfigured(_positionManager, true);
        emit BurnerConfigured(_positionManager, true);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function name() public pure override returns (string memory) {
        return "uShares";
    }

    function symbol() public pure override returns (string memory) {
        return "uSHR";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /*//////////////////////////////////////////////////////////////
                            ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function grantRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _grantRoles(user, roles);
    }

    function revokeRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _removeRoles(user, roles);
    }

    function renounceRoles(uint256 roles) public payable virtual override {
        _removeRoles(msg.sender, roles);
    }

    function configureMinter(address minter, bool status) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(minter);
        if (status) {
            _grantRoles(minter, MINTER_ROLE);
        } else {
            _removeRoles(minter, MINTER_ROLE);
        }
        emit MinterConfigured(minter, status);
    }

    function configureBurner(address burner, bool status) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(burner);
        if (status) {
            _grantRoles(burner, BURNER_ROLE);
        } else {
            _removeRoles(burner, BURNER_ROLE);
        }
        emit BurnerConfigured(burner, status);
    }

    function configureTokenPool(address pool, bool status) external onlyCCIPAdmin {
        _configureTokenPool(pool, status);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setVaultMapping(uint32 targetChain, address localVault, address remoteVault) external onlyCCIPAdmin {
        Errors.verifyAddress(localVault);
        Errors.verifyAddress(remoteVault);

        chainToVaultMapping[targetChain][localVault] = remoteVault;
        emit VaultMapped(targetChain, localVault, remoteVault);
    }

    function setCCTPContract(address _cctp) external onlyCCIPAdmin {
        Errors.verifyAddress(_cctp);
        cctp = ICCTP(_cctp);
    }

    function setTokenPool(address pool) external onlyCCIPAdmin {
        Errors.verifyAddress(pool);
        tokenPool = pool;
        _configureTokenPool(pool, true);
    }

    function setVaultRegistry(address _vaultRegistry) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(_vaultRegistry);
        vaultRegistry = IVaultRegistry(_vaultRegistry);
    }

    function pause() external onlyCCIPAdmin {
        paused = true;
    }

    function unpause() external onlyCCIPAdmin {
        paused = false;
    }

    /*//////////////////////////////////////////////////////////////
                            CCT IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    function lockOrBurn(LockOrBurnParams calldata params) external returns (bytes memory message) {
        if (!hasAnyRole(msg.sender, TOKEN_POOL_ROLE)) revert Errors.NotTokenPool();
        Errors.verifyAddress(params.receiver);
        Errors.verifyNumber(params.amount);

        // Check max transaction size
        if (params.amount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        // Get vault address from mapping
        address targetVault = chainToVaultMapping[uint32(params.destinationChainSelector)][msg.sender];
        Errors.verifyAddress(targetVault);

        // Get vault info from registry
        DataTypes.VaultInfo memory vaultInfo = IVaultRegistry(vaultRegistry).getVaultInfo(
            uint32(params.destinationChainSelector),
            targetVault
        );
        if (!vaultInfo.active) revert Errors.VaultNotActive();

        // Update position if it exists
        bytes32 positionKey = IPositionManager(positionManager).getPositionKey(
            msg.sender,
            chainId,
            uint32(params.destinationChainSelector),
            vaultInfo.vaultAddress
        );

        if (IPositionManager(positionManager).isHandler(msg.sender)) {
            IPositionManager(positionManager).updatePosition(positionKey, 0); // Zero shares on source chain
        }

        // Burn tokens
        _burn(msg.sender, params.amount);

        // Call CCTP to burn tokens
        USDC.safeApprove(address(cctp), params.amount);
        cctp.depositForBurn(
            params.amount,
            uint32(params.destinationChainSelector),
            bytes32(uint256(uint160(params.receiver))),
            USDC
        );

        // Return CCIP message
        return abi.encode(params.depositId, params.receiver, params.amount);
    }

    function releaseOrMint(ReleaseOrMintParams calldata params) external returns (uint256) {
        if (!hasAnyRole(msg.sender, TOKEN_POOL_ROLE)) revert Errors.NotTokenPool();
        Errors.verifyAddress(params.receiver);
        Errors.verifyNumber(params.amount);

        // Check max transaction size
        if (params.amount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        // Get vault address from mapping
        address sourceVault = chainToVaultMapping[uint32(params.sourceChainSelector)][msg.sender];
        Errors.verifyAddress(sourceVault);

        // Get vault info from registry
        DataTypes.VaultInfo memory vaultInfo = IVaultRegistry(vaultRegistry).getVaultInfo(
            uint32(params.sourceChainSelector),
            sourceVault
        );
        if (!vaultInfo.active) revert Errors.VaultNotActive();

        // Update position if it exists
        bytes32 positionKey = IPositionManager(positionManager).getPositionKey(
            msg.sender,
            uint32(params.sourceChainSelector),
            chainId,
            vaultInfo.vaultAddress
        );

        if (IPositionManager(positionManager).isHandler(msg.sender)) {
            IPositionManager(positionManager).updatePosition(positionKey, params.amount);
        }

        // Check if message has already been processed
        bytes32 messageHash = keccak256(abi.encode(params.depositId, params.amount));
        if (processedMessages[messageHash]) revert Errors.DuplicateMessage();
        processedMessages[messageHash] = true;

        // Mint tokens
        _mint(params.receiver, params.amount);

        return params.amount;
    }

    /*//////////////////////////////////////////////////////////////
                            CROSS-CHAIN DEPOSIT FLOW
    //////////////////////////////////////////////////////////////*/

    function initiateDeposit(
        address targetVault,
        uint256 usdcAmount,
        uint64 destinationChainSelector,
        uint256 minShares,
        uint256 deadline
    ) external whenNotPaused returns (bytes32 depositId) {
        // Validate inputs
        Errors.verifyAddress(targetVault);
        Errors.verifyNumber(usdcAmount);
        Errors.verifyNumber(minShares);
        if (block.timestamp > deadline) revert Errors.DepositExpired();

        // Check max transaction size
        if (usdcAmount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        // Verify vault mapping exists and vault is active
        address remoteVault = chainToVaultMapping[uint32(destinationChainSelector)][targetVault];
        if (remoteVault == address(0)) revert Errors.InvalidVault();
        if (!vaultRegistry.isVaultActive(uint32(destinationChainSelector), remoteVault)) revert Errors.VaultNotActive();

        // Convert chain selector to CCTP domain
        uint32 destinationDomain = _getDestinationDomain(uint32(destinationChainSelector));

        // Transfer USDC from user
        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Generate deposit ID
        depositId = keccak256(
            abi.encodePacked(
                msg.sender, usdcAmount, targetVault, destinationChainSelector, minShares, deadline, block.timestamp
            )
        );

        // Create deposit record
        deposits[depositId] = CrossChainDeposit({
            user: msg.sender,
            usdcAmount: usdcAmount,
            sourceVault: targetVault,
            targetVault: remoteVault,
            destinationChain: uint32(destinationChainSelector),
            vaultShares: 0,
            uSharesMinted: 0,
            cctpCompleted: false,
            sharesIssued: false,
            timestamp: block.timestamp,
            minShares: minShares,
            deadline: deadline
        });

        // Initiate CCTP burn
        USDC.safeApprove(address(cctp), usdcAmount);
        cctp.depositForBurn(
            usdcAmount,
            destinationDomain,
            bytes32(uint256(uint160(address(this)))), // Convert contract address to bytes32
            USDC
        );

        emit DepositInitiated(
            depositId, 
            msg.sender, 
            usdcAmount, 
            targetVault, 
            uint32(destinationChainSelector), 
            minShares, 
            deadline
        );
    }

    function mintSharesFromDeposit(bytes32 depositId, uint256 vaultShares) external {
        CrossChainDeposit storage deposit = deposits[depositId];
        if (!deposit.cctpCompleted) revert Errors.CCTPAlreadyCompleted();
        if (deposit.sharesIssued) revert Errors.ActiveShares();
        if (block.timestamp > deposit.deadline) revert Errors.DepositExpired();
        if (vaultShares < deposit.minShares) revert Errors.InsufficientShares();

        deposit.vaultShares = vaultShares;
        deposit.uSharesMinted = vaultShares; // 1:1 minting
        deposit.sharesIssued = true;

        // Create or update position
        bytes32 positionKey = IPositionManager(positionManager).getPositionKey(
            deposit.user,
            chainId,
            deposit.destinationChain,
            deposit.targetVault
        );

        // Try to update position first, if it fails (not found), create a new one
        try IPositionManager(positionManager).updatePosition(positionKey, vaultShares) {
            // Position updated successfully
        } catch {
            // Position doesn't exist, create it
            IPositionManager(positionManager).createPosition(
                deposit.user,
                chainId,
                deposit.destinationChain,
                deposit.targetVault,
                vaultShares
            );
        }

        _mint(deposit.user, vaultShares);
        emit SharesIssued(depositId, deposit.user, vaultShares, vaultShares);
    }

    function processCCTPCompletion(bytes32 depositId, bytes calldata attestation) external {
        CrossChainDeposit storage deposit = deposits[depositId];
        if (deposit.user == address(0)) revert Errors.InvalidDeposit();
        if (deposit.cctpCompleted) revert Errors.CCTPAlreadyCompleted();
        if (block.timestamp > deposit.deadline) revert Errors.DepositExpired();

        // Verify CCTP message format and attestation
        (uint32 sourceDomain, bytes32 sender, bytes memory message) = abi.decode(attestation, (uint32, bytes32, bytes));
        if (sourceDomain != BASE_DOMAIN) revert Errors.InvalidChain();
        
        // Verify message hasn't been processed
        bytes32 messageHash = keccak256(abi.encode(sourceDomain, sender, message));
        if (processedMessages[messageHash]) revert Errors.DuplicateMessage();
        processedMessages[messageHash] = true;

        // Verify CCTP message
        bool success = cctp.receiveMessage(sourceDomain, sender, message);
        if (!success) revert Errors.InvalidMessage();

        // Mark CCTP as completed
        deposit.cctpCompleted = true;
        emit CCTPCompleted(depositId, deposit.usdcAmount, deposit.destinationChain, deposit.targetVault);

        // Step 2: Deposit into vault and mint shares
        uint256 vaultShares = depositToVault(
            deposit.targetVault,
            deposit.usdcAmount,
            deposit.minShares
        );
        
        // Mint shares to user
        this.mintSharesFromDeposit(depositId, vaultShares);
    }

    /*//////////////////////////////////////////////////////////////
                            CROSS-CHAIN WITHDRAWAL FLOW
    //////////////////////////////////////////////////////////////*/

    function initiateWithdrawal(
        uint256 uSharesAmount,
        address targetVault,
        uint256 minUSDC,
        uint256 deadline
    ) external whenNotPaused returns (bytes32 withdrawalId) {
        Errors.verifyNumber(uSharesAmount);
        Errors.verifyAddress(targetVault);
        if (uSharesAmount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();
        if (block.timestamp > deadline) revert Errors.DepositExpired();

        // Get vault mapping to verify vault and get destination chain
        uint32 destinationChain;
        address remoteVault;
        for (uint32 i = 1; i < 100; i++) {  // Reasonable limit for chain IDs
            remoteVault = chainToVaultMapping[i][targetVault];
            if (remoteVault != address(0)) {
                destinationChain = i;
                break;
            }
        }
        if (remoteVault == address(0)) revert Errors.InvalidVault();

        // Generate withdrawal ID
        withdrawalId = keccak256(
            abi.encodePacked(
                msg.sender, uSharesAmount, targetVault, destinationChain, minUSDC, deadline, block.timestamp
            )
        );

        // Create withdrawal record
        withdrawals[withdrawalId] = CrossChainWithdrawal({
            user: msg.sender,
            uSharesAmount: uSharesAmount,
            sourceVault: targetVault,
            targetVault: remoteVault,
            destinationChain: destinationChain,
            usdcAmount: 0,
            cctpCompleted: false,
            sharesWithdrawn: false,
            timestamp: block.timestamp,
            minUSDC: minUSDC,
            deadline: deadline
        });

        // Burn uShares
        _burn(msg.sender, uSharesAmount);

        // Update position if it exists
        bytes32 positionKey = IPositionManager(positionManager).getPositionKey(
            msg.sender,
            chainId,
            destinationChain,
            remoteVault
        );

        if (IPositionManager(positionManager).isHandler(msg.sender)) {
            IPositionManager(positionManager).updatePosition(positionKey, 0);
        }

        emit WithdrawalInitiated(
            withdrawalId,
            msg.sender,
            uSharesAmount,
            targetVault,
            destinationChain,
            minUSDC,
            deadline
        );
    }

    function processWithdrawalCompletion(bytes32 withdrawalId, bytes calldata attestation) external {
        CrossChainWithdrawal storage withdrawal = withdrawals[withdrawalId];
        if (withdrawal.user == address(0)) revert Errors.InvalidWithdrawal();
        if (withdrawal.cctpCompleted) revert Errors.CCTPAlreadyCompleted();
        if (block.timestamp > withdrawal.deadline) revert Errors.WithdrawalExpired();

        // Verify CCTP message format and attestation
        (uint32 sourceDomain, bytes32 sender, bytes memory message) = abi.decode(attestation, (uint32, bytes32, bytes));
        if (sourceDomain != BASE_DOMAIN) revert Errors.InvalidChain();
        
        // Verify message hasn't been processed
        bytes32 messageHash = keccak256(abi.encode(sourceDomain, sender, message));
        if (processedMessages[messageHash]) revert Errors.DuplicateMessage();
        processedMessages[messageHash] = true;

        // Verify CCTP message
        bool success = cctp.receiveMessage(sourceDomain, sender, message);
        if (!success) revert Errors.InvalidMessage();

        // Decode USDC amount from message
        uint256 usdcAmount = abi.decode(message, (uint256));
        if (usdcAmount < withdrawal.minUSDC) revert Errors.InsufficientUSDC();

        // Mark CCTP as completed
        withdrawal.cctpCompleted = true;
        withdrawal.usdcAmount = usdcAmount;
        withdrawal.sharesWithdrawn = true;

        // Transfer USDC to user
        USDC.safeTransfer(withdrawal.user, usdcAmount);

        emit WithdrawalCompleted(withdrawalId, withdrawal.user, usdcAmount);
    }

    // Recovery function for stale withdrawals
    function recoverStaleWithdrawal(bytes32 withdrawalId) external {
        CrossChainWithdrawal storage withdrawal = withdrawals[withdrawalId];
        if (withdrawal.user == address(0)) revert Errors.InvalidWithdrawal();
        if (block.timestamp <= withdrawal.timestamp + PROCESS_TIMEOUT) revert Errors.InvalidWithdrawal();
        if (withdrawal.sharesWithdrawn) revert Errors.WithdrawalProcessed();

        // Return uShares to user since withdrawal failed
        _mint(withdrawal.user, withdrawal.uSharesAmount);

        delete withdrawals[withdrawalId];
    }

    /*//////////////////////////////////////////////////////////////
                            RECOVERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function recoverStaleDeposit(bytes32 depositId) external {
        CrossChainDeposit storage deposit = deposits[depositId];
        if (deposit.user == address(0)) revert Errors.InvalidDeposit();
        if (block.timestamp <= deposit.timestamp + PROCESS_TIMEOUT) revert Errors.InvalidDeposit();
        if (deposit.sharesIssued) revert Errors.ActiveShares();

        // Return USDC to user if CCTP hasn't completed
        if (!deposit.cctpCompleted) {
            USDC.safeTransfer(deposit.user, deposit.usdcAmount);
        }

        delete deposits[depositId];
    }

    /*//////////////////////////////////////////////////////////////
                            CROSS-CHAIN TOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external onlyPositionManager {
        Errors.verifyAddress(to);
        Errors.verifyNumber(amount);

        // Check max transaction size
        if (amount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        if (allowance(from, msg.sender) < amount) revert Errors.InsufficientAllowance();
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTokenPool() external view returns (address) {
        return tokenPool;
    }

    function getDeposit(bytes32 depositId) external view returns (CrossChainDeposit memory) {
        return deposits[depositId];
    }

    function getWithdrawal(bytes32 withdrawalId) external view returns (CrossChainWithdrawal memory) {
        return withdrawals[withdrawalId];
    }

    function getVaultMapping(uint32 targetChain, address localVault) external view returns (address) {
        return chainToVaultMapping[targetChain][localVault];
    }

    function getCCTPContract() external view returns (address) {
        return address(cctp);
    }

    function getChainId() external view returns (uint32) {
        return chainId;
    }

    function getCCIPAdmin() external view returns (address) {
        return address(this); // The contract itself is the CCIP admin
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _configureTokenPool(address pool, bool status) internal {
        Errors.verifyAddress(pool);
        if (status) {
            _grantRoles(pool, TOKEN_POOL_ROLE | MINTER_ROLE | BURNER_ROLE);
        } else {
            _removeRoles(pool, TOKEN_POOL_ROLE | MINTER_ROLE | BURNER_ROLE);
        }
        emit TokenPoolConfigured(pool, status);
        emit MinterConfigured(pool, status);
        emit BurnerConfigured(pool, status);
    }

    function depositToVault(
        address vault,
        uint256 amount,
        uint256 minShares
    ) internal returns (uint256 shares) {
        // Approve USDC for vault
        USDC.safeApprove(vault, amount);
        
        // Deposit into vault
        shares = IVault(vault).deposit(amount, address(this));
        
        // Verify minimum shares
        if (shares < minShares) revert Errors.InsufficientShares();
        
        return shares;
    }

    function _getDestinationDomain(uint32 _chainId) internal pure returns (uint32) {
        // If the chainId is already a CCTP domain, return it directly
        if (_chainId <= 7) return _chainId;

        // Otherwise, convert from chain ID to CCTP domain
        if (_chainId == 1) return ETHEREUM_DOMAIN;
        if (_chainId == 43114) return AVALANCHE_DOMAIN;
        if (_chainId == 10) return OPTIMISM_DOMAIN;
        if (_chainId == 42161) return ARBITRUM_DOMAIN;
        if (_chainId == 8453) return BASE_DOMAIN;
        if (_chainId == 137) return POLYGON_DOMAIN;
        revert Errors.InvalidChain();
    }

    error InvalidMessage();
}
