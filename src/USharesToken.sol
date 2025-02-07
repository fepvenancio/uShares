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
 * @title USharesToken
 * @notice Cross-chain share token implementation for the uShares protocol
 * @dev Represents shares in ERC4626 vaults across different chains, implementing
 *      cross-chain token (CCT) standard and Circle's CCTP for USDC transfers
 * @custom:security-contact security@ushares.com
 */
contract USharesToken is IUSharesToken, ICCTToken, ERC20, OwnableRoles {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for admin operations
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    
    /// @notice Role identifier for minting tokens
    uint256 public constant MINTER_ROLE = _ROLE_1;
    
    /// @notice Role identifier for burning tokens
    uint256 public constant BURNER_ROLE = _ROLE_2;
    
    /// @notice Role identifier for token pool operations
    uint256 public constant TOKEN_POOL_ROLE = _ROLE_3;
    
    /// @notice Role identifier for CCIP admin operations
    uint256 public constant CCIP_ADMIN_ROLE = _ROLE_4;

    /// @notice Timeout period for processing cross-chain operations
    uint256 public constant PROCESS_TIMEOUT = 1 hours;
    
    /// @notice Maximum transaction size in USDC (1M USDC)
    uint256 public constant MAX_TRANSACTION_SIZE = 1_000_000e6;

    /// @notice CCTP domain identifier for Ethereum
    uint32 private constant ETHEREUM_DOMAIN = 0;
    /// @notice CCTP domain identifier for Avalanche
    uint32 private constant AVALANCHE_DOMAIN = 1;
    /// @notice CCTP domain identifier for Optimism
    uint32 private constant OPTIMISM_DOMAIN = 2;
    /// @notice CCTP domain identifier for Arbitrum
    uint32 private constant ARBITRUM_DOMAIN = 3;
    /// @notice CCTP domain identifier for Base
    uint32 private constant BASE_DOMAIN = 6;
    /// @notice CCTP domain identifier for Polygon
    uint32 private constant POLYGON_DOMAIN = 7;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain ID where this contract is deployed
    uint32 public immutable chainId;
    
    /// @notice Address of the position manager contract
    address public immutable positionManager;
    
    /// @notice Address of the USDC token contract
    address public immutable USDC;
    
    /// @notice Address of the CCIP router contract
    IRouter public immutable router;

    /// @notice Address of the vault registry contract
    IVaultRegistry public vaultRegistry;
    
    /// @notice Address of the CCTP contract
    ICCTP public cctp;
    
    /// @notice Address of the token pool
    address public tokenPool;
    
    /// @notice Pause state of the contract
    bool public paused;

    /// @notice Mapping of chain ID and local vault to remote vault address
    mapping(uint32 => mapping(address => address)) public chainToVaultMapping;
    
    /// @notice Mapping of deposit ID to cross-chain deposit details
    mapping(bytes32 => CrossChainDeposit) public deposits;
    
    /// @notice Mapping of withdrawal ID to cross-chain withdrawal details
    mapping(bytes32 => CrossChainWithdrawal) public withdrawals;
    
    /// @notice Mapping to track processed CCTP messages
    mapping(bytes32 => bool) public processedMessages;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures the contract is not paused
    modifier whenNotPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    /// @notice Ensures caller has minter role
    modifier onlyMinter() {
        if (!hasAnyRole(msg.sender, MINTER_ROLE)) revert Errors.NotMinter();
        _;
    }

    /// @notice Ensures caller has burner role
    modifier onlyBurner() {
        if (!hasAnyRole(msg.sender, BURNER_ROLE)) revert Errors.NotBurner();
        _;
    }

    /// @notice Ensures caller has token pool role
    modifier onlyTokenPool() {
        if (!hasAnyRole(msg.sender, TOKEN_POOL_ROLE)) revert Errors.NotTokenPool();
        _;
    }

    /// @notice Ensures caller is the position manager
    modifier onlyPositionManager() {
        if (msg.sender != positionManager) revert Errors.NotPositionManager();
        _;
    }

    /// @notice Ensures caller has CCIP admin role
    modifier onlyCCIPAdmin() {
        if (!hasAnyRole(msg.sender, CCIP_ADMIN_ROLE)) revert Errors.NotCCIPAdmin();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the USharesToken contract
     * @dev Sets up initial state and grants roles to deployer
     * @param _name Token name (unused)
     * @param _symbol Token symbol (unused)
     * @param _chainId Chain ID where contract is deployed
     * @param _positionManager Address of position manager contract
     * @param _ccipAdmin Address of CCIP admin
     * @param _cctp Address of CCTP contract
     * @param _usdc Address of USDC token contract
     * @param _router Address of CCIP router contract
     */
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

    /**
     * @notice Returns the name of the token
     * @return string Token name
     */
    function name() public pure override returns (string memory) {
        return "uShares";
    }

    /**
     * @notice Returns the symbol of the token
     * @return string Token symbol
     */
    function symbol() public pure override returns (string memory) {
        return "uSHR";
    }

    /**
     * @notice Returns the number of decimals used by the token
     * @return uint8 Number of decimals (6)
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /*//////////////////////////////////////////////////////////////
                            ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Grants roles to a user
     * @dev Only callable by admin
     * @param user Address to grant roles to
     * @param roles Roles to grant
     */
    function grantRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _grantRoles(user, roles);
    }

    /**
     * @notice Revokes roles from a user
     * @dev Only callable by admin
     * @param user Address to revoke roles from
     * @param roles Roles to revoke
     */
    function revokeRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _removeRoles(user, roles);
    }

    /**
     * @notice Allows a user to renounce their own roles
     * @param roles Roles to renounce
     */
    function renounceRoles(uint256 roles) public payable virtual override {
        _removeRoles(msg.sender, roles);
    }

    /**
     * @notice Configures a minter address
     * @dev Only callable by admin
     * @param minter Address to configure as minter
     * @param status True to grant minter role, false to revoke
     * @custom:emits MinterConfigured event
     */
    function configureMinter(address minter, bool status) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(minter);
        if (status) {
            _grantRoles(minter, MINTER_ROLE);
        } else {
            _removeRoles(minter, MINTER_ROLE);
        }
        emit MinterConfigured(minter, status);
    }

    /**
     * @notice Configures a burner address
     * @dev Only callable by admin
     * @param burner Address to configure as burner
     * @param status True to grant burner role, false to revoke
     * @custom:emits BurnerConfigured event
     */
    function configureBurner(address burner, bool status) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(burner);
        if (status) {
            _grantRoles(burner, BURNER_ROLE);
        } else {
            _removeRoles(burner, BURNER_ROLE);
        }
        emit BurnerConfigured(burner, status);
    }

    /**
     * @notice Configures a token pool address
     * @dev Only callable by CCIP admin
     * @param pool Address to configure as token pool
     * @param status True to grant token pool role, false to revoke
     * @custom:emits TokenPoolConfigured, MinterConfigured, and BurnerConfigured events
     */
    function configureTokenPool(address pool, bool status) external onlyCCIPAdmin {
        _configureTokenPool(pool, status);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Maps a local vault to a remote vault on another chain
     * @dev Only callable by CCIP admin
     * @param targetChain Chain ID of the remote vault
     * @param localVault Address of the local vault
     * @param remoteVault Address of the remote vault on the target chain
     * @custom:emits VaultMapped event
     */
    function setVaultMapping(uint32 targetChain, address localVault, address remoteVault) external onlyCCIPAdmin {
        Errors.verifyAddress(localVault);
        Errors.verifyAddress(remoteVault);

        chainToVaultMapping[targetChain][localVault] = remoteVault;
        emit VaultMapped(targetChain, localVault, remoteVault);
    }

    /**
     * @notice Updates the CCTP contract address
     * @dev Only callable by CCIP admin
     * @param _cctp New CCTP contract address
     */
    function setCCTPContract(address _cctp) external onlyCCIPAdmin {
        Errors.verifyAddress(_cctp);
        cctp = ICCTP(_cctp);
    }

    /**
     * @notice Sets the token pool address and configures its roles
     * @dev Only callable by CCIP admin
     * @param pool Address of the new token pool
     * @custom:emits TokenPoolConfigured, MinterConfigured, and BurnerConfigured events
     */
    function setTokenPool(address pool) external onlyCCIPAdmin {
        Errors.verifyAddress(pool);
        tokenPool = pool;
        _configureTokenPool(pool, true);
    }

    /**
     * @notice Updates the vault registry address
     * @dev Only callable by admin
     * @param _vaultRegistry New vault registry address
     */
    function setVaultRegistry(address _vaultRegistry) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(_vaultRegistry);
        vaultRegistry = IVaultRegistry(_vaultRegistry);
    }

    /**
     * @notice Sets the pause state of the contract
     * @dev Only callable by CCIP admin
     */
    function pause() external onlyCCIPAdmin {
        paused = true;
    }

    /**
     * @notice Unpauses the contract
     * @dev Only callable by CCIP admin
     */
    function unpause() external onlyCCIPAdmin {
        paused = false;
    }

    /*//////////////////////////////////////////////////////////////
                            CCT IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks or burns tokens for cross-chain transfer
     * @dev Implements CCT standard for token locking/burning
     * @param params Parameters for the lock/burn operation
     * @return message Encoded message for cross-chain communication
     * @custom:requirements
     * - Caller must have TOKEN_POOL_ROLE
     * - Amount must not exceed MAX_TRANSACTION_SIZE
     * - Target vault must be registered and active
     */
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

    /**
     * @notice Releases or mints tokens from cross-chain transfer
     * @dev Implements CCT standard for token release/minting
     * @param params Parameters for the release/mint operation
     * @return uint256 Amount of tokens released/minted
     * @custom:requirements
     * - Caller must have TOKEN_POOL_ROLE
     * - Amount must not exceed MAX_TRANSACTION_SIZE
     * - Source vault must be registered and active
     * - Message must not be previously processed
     */
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

    /**
     * @notice Initiates a cross-chain deposit of USDC to mint uShares
     * @dev Handles the first step of the cross-chain deposit process
     * @param targetVault Address of the vault on the source chain
     * @param usdcAmount Amount of USDC to deposit
     * @param destinationChainSelector Chain ID where shares will be minted
     * @param minShares Minimum number of shares to receive
     * @param deadline Timestamp after which the deposit is invalid
     * @return depositId Unique identifier for tracking the deposit
     * @custom:emits DepositInitiated event
     * @custom:requirements
     * - Contract must not be paused
     * - Target vault must be registered and active
     * - USDC amount must not exceed MAX_TRANSACTION_SIZE
     * - Deadline must be in the future
     * - User must have approved sufficient USDC
     */
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

    /**
     * @notice Mints shares from a cross-chain deposit
     * @dev Called after CCTP completion to mint shares to the user
     * @param depositId Unique identifier for the deposit
     * @param vaultShares Amount of vault shares to mint
     * @custom:emits SharesIssued event
     * @custom:requirements
     * - CCTP must be completed
     * - Shares must not already be issued
     * - Deposit must not be expired
     * - Vault shares must meet minimum requirement
     */
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

    /**
     * @notice Processes the completion of a CCTP transfer for a deposit
     * @dev Verifies CCTP message, updates deposit state, and mints shares
     * @param depositId Unique identifier for the deposit
     * @param attestation CCTP message attestation data
     * @custom:emits CCTPCompleted event
     * @custom:emits SharesIssued event
     * @custom:requirements
     * - Deposit must exist
     * - CCTP must not be already completed
     * - Deposit must not be expired
     * - CCTP message must be valid and from correct domain
     * - Message must not be previously processed
     */
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

    /**
     * @notice Initiates a cross-chain withdrawal of shares
     * @dev Burns uShares tokens and creates withdrawal record
     * @param uSharesAmount Amount of uShares to withdraw
     * @param targetVault Address of the vault to withdraw from
     * @param minUSDC Minimum USDC amount to receive
     * @param deadline Timestamp after which withdrawal is invalid
     * @return withdrawalId Unique identifier for tracking the withdrawal
     * @custom:emits WithdrawalInitiated event
     * @custom:requirements
     * - Contract must not be paused
     * - Amount must not exceed MAX_TRANSACTION_SIZE
     * - Deadline must be in the future
     * - Target vault must be registered and mapped
     */
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

    /**
     * @notice Processes the completion of a CCTP transfer for a withdrawal
     * @dev Verifies CCTP message and transfers USDC to user
     * @param withdrawalId Unique identifier for the withdrawal
     * @param attestation CCTP message attestation data
     * @custom:emits WithdrawalCompleted event
     * @custom:requirements
     * - Withdrawal must exist
     * - CCTP must not be already completed
     * - Withdrawal must not be expired
     * - CCTP message must be valid and from correct domain
     * - Message must not be previously processed
     * - USDC amount must meet minimum requirement
     */
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
    /**
     * @notice Recovers tokens from a stale withdrawal
     * @dev Returns uShares to user if withdrawal wasn't processed
     * @param withdrawalId Unique identifier for the withdrawal
     * @custom:requirements
     * - Withdrawal must exist
     * - Process timeout must have elapsed
     * - Shares must not be already withdrawn
     */
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

    /**
     * @notice Recovers USDC from a stale deposit
     * @dev Returns USDC to user if CCTP wasn't completed
     * @param depositId Unique identifier for the deposit
     * @custom:requirements
     * - Deposit must exist
     * - Process timeout must have elapsed
     * - Shares must not be already issued
     */
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

    /**
     * @notice Mints new uShares tokens
     * @dev Only callable by position manager
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @custom:requirements
     * - Caller must be position manager
     * - Amount must not exceed MAX_TRANSACTION_SIZE
     */
    function mint(address to, uint256 amount) external onlyPositionManager {
        Errors.verifyAddress(to);
        Errors.verifyNumber(amount);

        // Check max transaction size
        if (amount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        _mint(to, amount);
    }

    /**
     * @notice Burns uShares tokens from caller
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burns uShares tokens from specified address
     * @dev Requires approval from token owner
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @custom:requirements
     * - Caller must have sufficient allowance
     */
    function burnFrom(address from, uint256 amount) external {
        if (allowance(from, msg.sender) < amount) revert Errors.InsufficientAllowance();
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the token pool address
     * @return address The token pool address
     */
    function getTokenPool() external view returns (address) {
        return tokenPool;
    }

    /**
     * @notice Gets deposit details by ID
     * @param depositId Unique identifier for the deposit
     * @return CrossChainDeposit Deposit details
     */
    function getDeposit(bytes32 depositId) external view returns (CrossChainDeposit memory) {
        return deposits[depositId];
    }

    /**
     * @notice Gets withdrawal details by ID
     * @param withdrawalId Unique identifier for the withdrawal
     * @return CrossChainWithdrawal Withdrawal details
     */
    function getWithdrawal(bytes32 withdrawalId) external view returns (CrossChainWithdrawal memory) {
        return withdrawals[withdrawalId];
    }

    /**
     * @notice Gets the mapped vault address for a given chain and local vault
     * @param targetChain Chain ID to query
     * @param localVault Local vault address
     * @return address The mapped remote vault address
     */
    function getVaultMapping(uint32 targetChain, address localVault) external view returns (address) {
        return chainToVaultMapping[targetChain][localVault];
    }

    /**
     * @notice Gets the CCTP contract address
     * @return address The CCTP contract address
     */
    function getCCTPContract() external view returns (address) {
        return address(cctp);
    }

    /**
     * @notice Gets the chain ID where this contract is deployed
     * @return uint32 The chain ID
     */
    function getChainId() external view returns (uint32) {
        return chainId;
    }

    /**
     * @notice Gets the CCIP admin address
     * @return address The CCIP admin address (this contract)
     */
    function getCCIPAdmin() external view returns (address) {
        return address(this); // The contract itself is the CCIP admin
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Configures a token pool's roles internally
     * @dev Grants or revokes TOKEN_POOL_ROLE, MINTER_ROLE, and BURNER_ROLE
     * @param pool Address to configure
     * @param status True to grant roles, false to revoke
     * @custom:emits TokenPoolConfigured, MinterConfigured, and BurnerConfigured events
     */
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

    /**
     * @notice Deposits USDC into a vault
     * @dev Approves USDC for vault and performs deposit
     * @param vault Address of the vault to deposit into
     * @param amount Amount of USDC to deposit
     * @param minShares Minimum shares expected from deposit
     * @return shares Number of shares received from deposit
     */
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

    /**
     * @notice Converts chain ID to CCTP domain
     * @dev Maps common chain IDs to their corresponding CCTP domains
     * @param _chainId Chain ID to convert
     * @return uint32 Corresponding CCTP domain
     */
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
