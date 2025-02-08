// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "solady/tokens/ERC20.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IUSharesToken} from "./interfaces/IUSharesToken.sol";
import {IVaultRegistry} from "./interfaces/IVaultRegistry.sol";
import {ICCTP} from "./interfaces/ICCTP.sol";
import {DataTypes} from "./libs/DataTypes.sol";
import {Errors} from "./libs/Errors.sol";
import {ITokenReceiver} from "./interfaces/ITokenReceiver.sol";

/**
 * @title USharesToken
 * @notice Implementation of the UShares token contract
 * @dev This contract is responsible for managing the UShares token and its cross-chain functionality
 */
contract USharesToken is IUSharesToken, ERC20, OwnableRoles {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant MINTER_ROLE = _ROLE_1;
    uint256 internal constant BURNER_ROLE = _ROLE_2;

    uint256 internal constant MIN_USDC_AMOUNT = 1e6; // 1 USDC
    uint256 internal constant MAX_USDC_AMOUNT = 1000000e6; // 1M USDC

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CCTPSet(address indexed cctp);
    event TokenPoolConfigured(address indexed tokenPool, bool enabled);
    event VaultMappingSet(uint32 indexed destinationChain, address indexed tokenPool, address indexed vault);
    event TokensRecovered(address indexed token, address indexed to, uint256 amount);
    event LimitsUpdated(uint256 minAmount, uint256 maxAmount);
    event MaxSlippageUpdated(uint256 maxSlippage);
    event SharesUpdated(uint32 indexed chainId, address indexed vault, uint256 shares);
    event RemoteTokenMessengerSet(uint32 indexed domain, bytes32 indexed messenger);
    event RemoteTokenMessengerRemoved(uint32 indexed domain);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice Whether this chain is the issuing chain
    bool public immutable isIssuingChain;

    /// @notice The vault registry contract
    address public vaultRegistry;

    /// @notice The CCTP contract
    address public cctp;

    /// @notice The chain ID where this token was originally deployed
    uint32 public immutable issuingDomain;

    /// @notice The token pool contract
    address public tokenPool;

    /// @notice Minimum amount for transactions
    uint256 public minAmount = 1e6; // 1 USDC

    /// @notice Maximum amount for transactions
    uint256 public maxAmount = 1000000e6; // 1M USDC

    /// @notice Maximum slippage allowed (10000 = 100%)
    uint256 public maxSlippage = 100; // 1%

    /// @notice Mapping of domain to vault mapping
    mapping(uint32 => mapping(address => address)) public domainToVaultMapping;

    /// @notice Mapping of deposit IDs to deposit data
    mapping(bytes32 => DataTypes.CrossChainDeposit) private _deposits;
    function deposits(bytes32 depositId) external view returns (DataTypes.CrossChainDeposit memory) {
        return _deposits[depositId];
    }

    /// @notice Mapping of withdrawal IDs to withdrawal data
    mapping(bytes32 => DataTypes.CrossChainWithdrawal) private _withdrawals;
    function withdrawals(bytes32 withdrawalId) external view returns (DataTypes.CrossChainWithdrawal memory) {
        return _withdrawals[withdrawalId];
    }

    /// @notice Mapping to track processed CCTP messages
    mapping(bytes32 => bool) public processedMessages;

    /// @notice The USDC token contract
    address public immutable USDC;

    /// @notice The domain where this contract is deployed
    uint32 public immutable domain;

    /// @notice The CCTP message body version
    uint32 public immutable messageBodyVersion;

    /// @notice Mapping of domain to remote token messenger
    mapping(uint32 => bytes32) public remoteTokenMessengers;

    /// @notice The token receiver contract for vault interactions
    address public tokenReceiver;

    /*//////////////////////////////////////////////////////////////
                            MISSING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the chain ID
     * @return The chain ID
     */
    function chainId() external view returns (uint32) {
        return domain;
    }

    /**
     * @notice Get the vault mapping for a chain and local vault
     * @param chainId The chain ID
     * @param localVault The local vault address
     * @return The mapped vault address
     */
    function chainToVaultMapping(uint32 chainId, address localVault) external view returns (address) {
        return domainToVaultMapping[chainId][localVault];
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint32 _domain,
        bool _isIssuingChain,
        address _cctp,
        address _usdc,
        address _tokenReceiver
    ) {
        Errors.verifyAddress(_cctp);
        Errors.verifyAddress(_usdc);
        Errors.verifyAddress(_tokenReceiver);

        domain = _domain;
        isIssuingChain = _isIssuingChain;
        cctp = _cctp;
        USDC = _usdc;
        tokenReceiver = _tokenReceiver;

        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ADMIN_ROLE | MINTER_ROLE | BURNER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRoles(ADMIN_ROLE) {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRoles(ADMIN_ROLE) {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Set the vault registry contract
     * @param _vaultRegistry The address of the vault registry contract
     */
    function setVaultRegistry(address _vaultRegistry) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(_vaultRegistry);
        vaultRegistry = _vaultRegistry;
        emit VaultRegistrySet(_vaultRegistry);
    }

    /**
     * @notice Set the CCTP contract
     * @param _cctp The address of the CCTP contract
     */
    function setCCTP(address _cctp) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(_cctp);
        cctp = _cctp;
        emit CCTPSet(_cctp);
    }

    /**
     * @notice Configure the token pool contract
     * @param _tokenPool The address of the token pool contract
     * @param enabled Whether to enable or disable the token pool
     */
    function configureTokenPool(address _tokenPool, bool enabled) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(_tokenPool);
        if (enabled) {
            tokenPool = _tokenPool;
        } else {
            tokenPool = address(0);
        }
        emit TokenPoolConfigured(_tokenPool, enabled);
    }

    /**
     * @notice Initiate a cross-chain deposit
     * @param targetVault The address of the vault on the destination chain
     * @param usdcAmount The amount of USDC to deposit
     * @param destinationDomain The destination domain ID
     * @param minShares The minimum amount of shares to receive
     * @param deadline The deadline for the deposit
     * @return depositId The ID of the deposit
     */
    function initiateDeposit(
        address targetVault,
        uint256 usdcAmount,
        uint32 destinationDomain,
        uint256 minShares,
        uint256 deadline
    ) external whenNotPaused returns (bytes32) {
        // Verify destination chain and vault
        if (!IVaultRegistry(vaultRegistry).isVaultActive(destinationDomain, targetVault)) revert Errors.VaultNotActive();

        // Verify vault mapping
        address expectedVault = domainToVaultMapping[destinationDomain][tokenPool];
        if (expectedVault == address(0) || expectedVault != targetVault) revert Errors.InvalidVault();

        // Check transaction size
        if (usdcAmount < minAmount || usdcAmount > maxAmount) revert Errors.InvalidAmount();

        // Check deadline
        if (block.timestamp > deadline) revert Errors.InvalidDeadline();

        // Transfer USDC from user
        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Generate deposit ID
        bytes32 depositId = keccak256(
            abi.encodePacked(
                msg.sender,
                destinationDomain,
                targetVault,
                usdcAmount,
                minShares,
                deadline,
                block.timestamp
            )
        );

        // Store deposit details
        _deposits[depositId] = DataTypes.CrossChainDeposit({
            user: msg.sender,
            usdcAmount: usdcAmount,
            destinationDomain: destinationDomain,
            targetVault: targetVault,
            deadline: deadline,
            status: DataTypes.CrossChainStatus.Pending,
            cctpCompleted: false
        });

        // Approve USDC for CCTP
        USDC.safeApprove(cctp, usdcAmount);

        // Initiate CCTP burn
        uint64 nonce = ICCTP(cctp).depositForBurn(
            usdcAmount,
            destinationDomain,
            bytes32(uint256(uint160(targetVault))),
            USDC
        );

        emit DepositInitiated(depositId, msg.sender, usdcAmount, targetVault, destinationDomain, minShares, deadline);

        return depositId;
    }

    /**
     * @notice Process a CCTP completion
     * @param depositId The ID of the deposit
     * @param attestation The CCTP attestation data
     */
    function processCCTPCompletion(
        bytes32 depositId,
        bytes calldata attestation
    ) external whenNotPaused {
        DataTypes.CrossChainDeposit storage deposit = _deposits[depositId];
        if (deposit.status != DataTypes.CrossChainStatus.Pending) revert Errors.InvalidDeposit();
        if (block.timestamp > deposit.deadline) revert Errors.DepositExpired();

        // Process CCTP mint
        bool success = ICCTP(cctp).receiveMessage(
            deposit.destinationDomain,
            bytes32(uint256(uint160(deposit.targetVault))),
            attestation
        );
        if (!success) revert Errors.CCTPMessageFailed();

        // Deposit USDC into vault through TokenReceiver
        uint256 vaultShares = ITokenReceiver(tokenReceiver).depositToVault(
            deposit.targetVault,
            USDC,
            deposit.usdcAmount
        );

        // Mint uShares to the depositor
        _mint(deposit.user, vaultShares);
        emit Minted(deposit.user, vaultShares);

        // Update vault shares
        uint256 newShares = IVaultRegistry(vaultRegistry).updateVaultShares(
            deposit.destinationDomain,
            deposit.targetVault,
            deposit.usdcAmount
        );

        deposit.status = DataTypes.CrossChainStatus.Completed;
        deposit.cctpCompleted = true;

        emit CCTPCompleted(
            depositId,
            deposit.usdcAmount,
            deposit.destinationDomain,
            deposit.targetVault
        );
        emit SharesUpdated(deposit.destinationDomain, deposit.targetVault, newShares);
    }

    /**
     * @notice Initiate a cross-chain withdrawal
     * @param uSharesAmount The amount of uShares tokens to withdraw
     * @param targetVault The vault to withdraw from
     * @param minUSDC The minimum amount of USDC to receive
     * @param deadline The deadline for the withdrawal
     * @return withdrawalId The ID of the withdrawal
     */
    function initiateWithdrawal(
        uint256 uSharesAmount,
        address targetVault,
        uint256 minUSDC,
        uint256 deadline
    ) external whenNotPaused returns (bytes32) {
        // Verify vault is active
        if (!IVaultRegistry(vaultRegistry).isVaultActive(domain, targetVault)) revert Errors.VaultNotActive();

        // Check transaction size
        if (uSharesAmount < minAmount || uSharesAmount > maxAmount) revert Errors.InvalidAmount();

        // Check deadline
        if (block.timestamp > deadline) revert Errors.InvalidDeadline();

        // Generate withdrawal ID
        bytes32 withdrawalId = keccak256(
            abi.encodePacked(
                msg.sender,
                domain,
                targetVault,
                uSharesAmount,
                minUSDC,
                deadline,
                block.timestamp
            )
        );

        // Store withdrawal details
        _withdrawals[withdrawalId] = DataTypes.CrossChainWithdrawal({
            user: msg.sender,
            usdcAmount: uSharesAmount,
            destinationDomain: domain,
            targetVault: targetVault,
            deadline: deadline,
            status: DataTypes.CrossChainStatus.Pending,
            cctpCompleted: false
        });

        // Burn tokens
        _burn(msg.sender, uSharesAmount);

        // Initiate CCTP burn for withdrawal
        uint64 nonce = ICCTP(cctp).depositForBurn(
            uSharesAmount,
            domain,
            bytes32(uint256(uint160(msg.sender))), // Recipient is the withdrawing user
            USDC
        );

        // Update vault shares
        uint256 newShares = IVaultRegistry(vaultRegistry).updateVaultShares(
            domain,
            targetVault,
            uSharesAmount
        );

        emit WithdrawalInitiated(withdrawalId, msg.sender, uSharesAmount, targetVault, domain, minUSDC, deadline);
        emit SharesUpdated(domain, targetVault, newShares);

        return withdrawalId;
    }

    /**
     * @notice Process a withdrawal completion
     * @param withdrawalId The ID of the withdrawal
     * @param attestation The CCTP attestation data
     */
    function processWithdrawalCompletion(
        bytes32 withdrawalId,
        bytes calldata attestation
    ) external whenNotPaused {
        DataTypes.CrossChainWithdrawal storage withdrawal = _withdrawals[withdrawalId];
        if (withdrawal.status != DataTypes.CrossChainStatus.Pending) revert Errors.InvalidWithdrawal();
        if (block.timestamp > withdrawal.deadline) revert Errors.WithdrawalExpired();

        // Process CCTP mint
        bool success = ICCTP(cctp).receiveMessage(
            withdrawal.destinationDomain,
            bytes32(uint256(uint160(withdrawal.targetVault))),
            attestation
        );
        if (!success) revert Errors.CCTPMessageFailed();

        withdrawal.status = DataTypes.CrossChainStatus.Completed;
        withdrawal.cctpCompleted = true;

        emit WithdrawalCompleted(
            withdrawalId,
            withdrawal.user,
            withdrawal.usdcAmount
        );
    }

    /**
     * @notice Mint new tokens
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRoles(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burn tokens
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyRoles(BURNER_ROLE) whenNotPaused {
        _burn(from, amount);
        emit Burned(from, amount);
    }

    /**
     * @notice Set the vault mapping for a chain and token pool
     * @param destinationChain The destination chain ID
     * @param _tokenPool The token pool address
     * @param vault The vault address
     */
    function setVaultMapping(
        uint32 destinationChain,
        address _tokenPool,
        address vault
    ) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyChainId(destinationChain);
        Errors.verifyAddress(_tokenPool);
        Errors.verifyAddress(vault);

        domainToVaultMapping[destinationChain][_tokenPool] = vault;
        emit VaultMappingSet(destinationChain, _tokenPool, vault);
    }

    /**
     * @notice Emergency function to recover stuck tokens
     * @param token The token to recover
     * @param to The address to send tokens to
     * @param amount The amount to recover
     */
    function recoverTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(to);
        if (amount == 0) revert Errors.InvalidAmount();
        
        // Don't allow recovery of uShares tokens
        if (token == address(this)) revert Errors.InvalidToken(token);
        
        token.safeTransfer(to, amount);
        emit TokensRecovered(token, to, amount);
    }

    /**
     * @notice Update transaction limits
     * @param _minAmount New minimum amount
     * @param _maxAmount New maximum amount
     */
    function updateLimits(
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyRoles(ADMIN_ROLE) {
        if (_minAmount == 0 || _maxAmount == 0) revert Errors.InvalidAmount();
        if (_minAmount >= _maxAmount) revert Errors.InvalidConfig();
        
        minAmount = _minAmount;
        maxAmount = _maxAmount;
        emit LimitsUpdated(_minAmount, _maxAmount);
    }

    /**
     * @notice Update maximum allowed slippage
     * @param _maxSlippage New maximum slippage (100 = 1%)
     */
    function updateMaxSlippage(uint256 _maxSlippage) external onlyRoles(ADMIN_ROLE) {
        if (_maxSlippage == 0 || _maxSlippage > 10000) revert Errors.InvalidConfig();
        
        maxSlippage = _maxSlippage;
        emit MaxSlippageUpdated(_maxSlippage);
    }

    /**
     * @notice Set a remote token messenger for a domain
     * @param domainId The domain ID
     * @param messenger The token messenger address as bytes32
     */
    function setRemoteTokenMessenger(uint32 domainId, bytes32 messenger) external onlyRoles(ADMIN_ROLE) {
        if (messenger == bytes32(0)) revert Errors.InvalidConfig();
        remoteTokenMessengers[domainId] = messenger;
        emit RemoteTokenMessengerSet(domainId, messenger);
    }

    /**
     * @notice Remove a remote token messenger for a domain
     * @param domainId The domain ID
     */
    function removeRemoteTokenMessenger(uint32 domainId) external onlyRoles(ADMIN_ROLE) {
        delete remoteTokenMessengers[domainId];
        emit RemoteTokenMessengerRemoved(domainId);
    }

    /**
     * @notice Initiate a deposit with a specified caller on the destination chain
     * @param targetVault The address of the vault on the destination chain
     * @param usdcAmount The amount of USDC to deposit
     * @param destinationDomain The destination domain ID
     * @param minShares The minimum amount of shares to receive
     * @param deadline The deadline for the deposit
     * @param destinationCaller The allowed caller of receiveMessage on destination domain
     * @return depositId The ID of the deposit
     */
    function initiateDepositWithCaller(
        address targetVault,
        uint256 usdcAmount,
        uint32 destinationDomain,
        uint256 minShares,
        uint256 deadline,
        bytes32 destinationCaller
    ) external whenNotPaused returns (bytes32) {
        // Verify destination chain and vault
        if (!IVaultRegistry(vaultRegistry).isVaultActive(destinationDomain, targetVault)) revert Errors.VaultNotActive();

        // Verify vault mapping
        address expectedVault = domainToVaultMapping[destinationDomain][tokenPool];
        if (expectedVault == address(0) || expectedVault != targetVault) revert Errors.InvalidVault();

        // Check transaction size
        if (usdcAmount < minAmount || usdcAmount > maxAmount) revert Errors.InvalidAmount();

        // Check deadline
        if (block.timestamp > deadline) revert Errors.InvalidDeadline();

        // Check slippage
        uint256 expectedShares = IVaultRegistry(vaultRegistry).calculateShares(destinationDomain, targetVault, usdcAmount);
        uint256 maxSlippageAmount = (expectedShares * maxSlippage) / 10000;
        if (expectedShares - minShares > maxSlippageAmount) revert Errors.ExcessiveSlippage();

        // Transfer USDC from user
        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Generate deposit ID
        bytes32 depositId = keccak256(
            abi.encodePacked(
                msg.sender,
                destinationDomain,
                targetVault,
                usdcAmount,
                minShares,
                deadline,
                block.timestamp
            )
        );

        // Store deposit details
        _deposits[depositId] = DataTypes.CrossChainDeposit({
            user: msg.sender,
            usdcAmount: usdcAmount,
            destinationDomain: destinationDomain,
            targetVault: targetVault,
            deadline: deadline,
            status: DataTypes.CrossChainStatus.Pending,
            cctpCompleted: false
        });

        // Approve USDC for CCTP
        USDC.safeApprove(cctp, usdcAmount);

        // Initiate CCTP burn with caller
        uint64 nonce = ICCTP(cctp).depositForBurnWithCaller(
            usdcAmount,
            destinationDomain,
            bytes32(uint256(uint160(targetVault))),
            USDC,
            destinationCaller
        );

        emit DepositInitiated(depositId, msg.sender, usdcAmount, targetVault, destinationDomain, minShares, deadline);

        return depositId;
    }

    /**
     * @notice Set the token receiver contract
     * @param _tokenReceiver The address of the token receiver contract
     */
    function setTokenReceiver(address _tokenReceiver) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(_tokenReceiver);
        tokenReceiver = _tokenReceiver;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function name() public pure override returns (string memory) {
        return "UShares Token";
    }

    function symbol() public pure override returns (string memory) {
        return "USH";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
