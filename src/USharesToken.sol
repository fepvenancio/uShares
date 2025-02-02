// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
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
contract USharesToken is IUSharesToken, ICCTToken, ERC20, Ownable {
    using SafeTransferLib for address;

    // State variables
    uint32 public immutable chainId;
    address public immutable positionManager;
    IVaultRegistry public vaultRegistry;
    address public ccipAdmin;
    ICCTP public cctp;
    IRouter public immutable router;
    address public tokenPool;

    // Role management
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;
    mapping(address => bool) public tokenPools;

    // Vault mappings
    mapping(uint32 => mapping(address => address)) public chainToVaultMapping;

    // Cross-chain deposit tracking
    mapping(bytes32 => CrossChainDeposit) public deposits;

    // Message deduplication
    mapping(bytes32 => bool) public processedMessages;

    // Constants
    uint256 public constant PROCESS_TIMEOUT = 1 hours;
    uint256 public constant MAX_TRANSACTION_SIZE = 1_000_000e6; // 1M USDC
    address public immutable USDC;

    // Emergency control
    bool public paused;

    // Events from IUSharesToken are inherited

    modifier whenNotPaused() {
        require(!paused, "Protocol paused");
        _;
    }

    modifier onlyMinter() {
        if (!minters[msg.sender]) revert Errors.NotMinter();
        _;
    }

    modifier onlyBurner() {
        if (!burners[msg.sender]) revert Errors.NotBurner();
        _;
    }

    modifier onlyTokenPool() {
        if (!tokenPools[msg.sender]) revert Errors.NotTokenPool();
        _;
    }

    modifier onlyPositionManager() {
        if (msg.sender != positionManager) revert Errors.NotPositionManager();
        _;
    }

    modifier onlyCCIPAdmin() {
        if (msg.sender != ccipAdmin) revert Errors.NotCCIPAdmin();
        _;
    }

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
        Errors.verifyNotZero(_positionManager);
        Errors.verifyNotZero(_ccipAdmin);
        Errors.verifyNotZero(_cctp);
        Errors.verifyNotZero(_usdc);
        Errors.verifyNotZero(_router);

        chainId = _chainId;
        positionManager = _positionManager;
        vaultRegistry = IVaultRegistry(address(0)); // Will be set by owner
        ccipAdmin = _ccipAdmin;
        cctp = ICCTP(_cctp);
        USDC = _usdc;
        router = IRouter(_router);
        _initializeOwner(msg.sender);

        // Configure initial roles
        minters[_positionManager] = true;
        burners[_positionManager] = true;
        emit MinterConfigured(_positionManager, true);
        emit BurnerConfigured(_positionManager, true);
    }

    // CCT Implementation
    function lockOrBurn(LockOrBurnParams calldata params) external returns (bytes memory message) {
        if (!tokenPools[msg.sender]) revert Errors.NotTokenPool();
        Errors.verifyNotZero(params.receiver);
        Errors.verifyNotZero(params.amount);

        // Check max transaction size instead of rate limit
        if (params.amount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        // Get vault address from mapping
        address targetVault = chainToVaultMapping[uint32(params.destinationChainSelector)][msg.sender];
        Errors.verifyNotZero(targetVault);

        // Get vault info from registry
        DataTypes.VaultInfo memory vaultInfo =
            IVaultRegistry(vaultRegistry).getVaultInfo(uint32(params.destinationChainSelector), targetVault);
        if (!vaultInfo.active) revert Errors.VaultNotActive();

        // Update position if it exists
        bytes32 positionKey = IPositionManager(positionManager).getPositionKey(
            msg.sender, chainId, uint32(params.destinationChainSelector), vaultInfo.vaultAddress
        );

        if (IPositionManager(positionManager).isHandler(msg.sender)) {
            IPositionManager(positionManager).updatePosition(positionKey, 0); // Zero shares on source chain
        }

        // Burn tokens
        _burn(msg.sender, params.amount);

        // Return CCIP message
        return abi.encode(params.depositId, params.receiver, params.amount);
    }

    function releaseOrMint(ReleaseOrMintParams calldata params) external returns (uint256) {
        if (!tokenPools[msg.sender]) revert Errors.NotTokenPool();
        Errors.verifyNotZero(params.receiver);
        Errors.verifyNotZero(params.amount);

        // Check max transaction size instead of rate limit
        if (params.amount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        // Get vault address from mapping
        address sourceVault = chainToVaultMapping[uint32(params.sourceChainSelector)][msg.sender];
        Errors.verifyNotZero(sourceVault);

        // Get vault info from registry
        DataTypes.VaultInfo memory vaultInfo =
            IVaultRegistry(vaultRegistry).getVaultInfo(uint32(params.sourceChainSelector), sourceVault);
        if (!vaultInfo.active) revert Errors.VaultNotActive();

        // Update position if it exists
        bytes32 positionKey = IPositionManager(positionManager).getPositionKey(
            msg.sender, uint32(params.sourceChainSelector), chainId, vaultInfo.vaultAddress
        );

        if (IPositionManager(positionManager).isHandler(msg.sender)) {
            IPositionManager(positionManager).updatePosition(positionKey, params.amount);
        }

        // Check if message has already been processed
        bytes32 messageHash = keccak256(abi.encode(params.depositId, params.amount));
        require(!processedMessages[messageHash], Errors.DuplicateMessage());
        processedMessages[messageHash] = true;

        // Mint tokens
        _mint(params.receiver, params.amount);

        return params.amount;
    }

    // Cross-chain deposit flow
    function initiateDeposit(
        address targetVault,
        uint256 usdcAmount,
        uint64 destinationChainSelector,
        uint256 minShares,
        uint256 deadline
    ) external whenNotPaused returns (bytes32 depositId) {
        // Validate inputs
        Errors.verifyNotZero(targetVault);
        Errors.verifyNotZero(usdcAmount);
        Errors.verifyNotZero(minShares);
        require(block.timestamp <= deadline, "Expired");

        // Verify vault mapping exists
        address remoteVault = chainToVaultMapping[uint32(destinationChainSelector)][targetVault];
        require(remoteVault != address(0), "Invalid vault mapping");

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
            expectedShares: 0,
            cctpCompleted: false,
            sharesIssued: false,
            timestamp: block.timestamp,
            minShares: minShares,
            deadline: deadline
        });

        // Initiate CCTP burn
        USDC.safeApprove(address(cctp), usdcAmount);
        cctp.depositForBurn(
            usdcAmount, uint32(destinationChainSelector), bytes32(uint256(uint160(address(this)))), USDC
        );

        // Create CCIP message for token pool
        bytes memory message = abi.encode(depositId, msg.sender, usdcAmount, minShares);

        emit DepositInitiated(
            depositId, msg.sender, usdcAmount, targetVault, uint32(destinationChainSelector), minShares, deadline
        );
    }

    function processCCTPCompletion(bytes32 depositId, bytes memory attestation) external whenNotPaused {
        CrossChainDeposit storage deposit = deposits[depositId];
        require(deposit.user != address(0), "Invalid deposit");
        require(!deposit.cctpCompleted, "CCTP already completed");
        require(block.timestamp <= deposit.deadline, "Deposit expired");

        // Verify CCTP message format and content
        bytes memory message = abi.encode(depositId, deposit.usdcAmount);
        require(cctp.verifyMessageHash(message, attestation), "Invalid attestation");

        // Store message hash to prevent replay
        bytes32 messageHash = keccak256(message);
        require(!processedMessages[messageHash], "Message already processed");
        processedMessages[messageHash] = true;

        // Decode and verify message content
        (bytes32 msgDepositId, uint256 amount) = abi.decode(message, (bytes32, uint256));
        require(msgDepositId == depositId, "Deposit ID mismatch");
        require(amount == deposit.usdcAmount, "Amount mismatch");

        // Update deposit state
        deposit.cctpCompleted = true;

        // Record message in CCTP mock for test verification
        cctp.receiveMessage(message, attestation);

        emit CCTPCompleted(depositId, deposit.usdcAmount, deposit.destinationChain);
    }

    function mintSharesFromDeposit(bytes32 depositId, uint256 vaultShares) external whenNotPaused onlyTokenPool {
        CrossChainDeposit storage deposit = deposits[depositId];
        require(deposit.user != address(0), "Invalid deposit");
        require(deposit.cctpCompleted, "CCTP not completed");
        require(!deposit.sharesIssued, "Shares already issued");
        require(block.timestamp <= deposit.deadline, "Deposit expired");
        require(vaultShares >= deposit.minShares, "Insufficient shares");

        // Mint UShares tokens to user
        _mint(deposit.user, vaultShares);

        // Update vault shares
        IVault(deposit.sourceVault).deposit(deposit.usdcAmount, deposit.user);

        deposit.sharesIssued = true;
        deposit.expectedShares = vaultShares;

        emit SharesIssued(depositId, deposit.user, vaultShares);
    }

    // Admin functions
    function setVaultMapping(uint32 targetChain, address localVault, address remoteVault) external onlyCCIPAdmin {
        Errors.verifyNotZero(localVault);
        Errors.verifyNotZero(remoteVault);

        chainToVaultMapping[targetChain][localVault] = remoteVault;
        emit VaultMapped(targetChain, localVault, remoteVault);
    }

    function setCCTPContract(address _cctp) external onlyCCIPAdmin {
        Errors.verifyNotZero(_cctp);
        cctp = ICCTP(_cctp);
    }

    function configureMinter(address minter, bool status) external onlyOwner {
        Errors.verifyNotZero(minter);
        minters[minter] = status;
        emit MinterConfigured(minter, status);
    }

    function configureBurner(address burner, bool status) external onlyOwner {
        Errors.verifyNotZero(burner);
        burners[burner] = status;
        emit BurnerConfigured(burner, status);
    }

    function configureTokenPool(address pool, bool status) external onlyCCIPAdmin {
        _configureTokenPool(pool, status);
    }

    function getTokenPool() external view returns (address) {
        return tokenPool;
    }

    function setTokenPool(address pool) external onlyCCIPAdmin {
        Errors.verifyNotZero(pool);
        tokenPool = pool;
        // Configure token pool permissions
        _configureTokenPool(pool, true);
    }

    function pause() external onlyCCIPAdmin {
        paused = true;
    }

    function unpause() external onlyCCIPAdmin {
        paused = false;
    }

    function setCCIPAdmin(address newAdmin) external onlyOwner {
        Errors.verifyNotZero(newAdmin);
        address oldAdmin = ccipAdmin;
        ccipAdmin = newAdmin;
        emit CCIPAdminUpdated(oldAdmin, newAdmin);
    }

    function setVaultRegistry(address _vaultRegistry) external onlyOwner {
        Errors.verifyNotZero(_vaultRegistry);
        vaultRegistry = IVaultRegistry(_vaultRegistry);
    }

    // Recovery functions
    function recoverStaleDeposit(bytes32 depositId) external {
        CrossChainDeposit storage deposit = deposits[depositId];
        require(deposit.user != address(0), "Invalid deposit");
        require(block.timestamp > deposit.timestamp + PROCESS_TIMEOUT, "Not stale");
        require(!deposit.sharesIssued, "Shares already issued");

        // Return USDC to user if CCTP hasn't completed
        if (!deposit.cctpCompleted) {
            USDC.safeTransfer(deposit.user, deposit.usdcAmount);
        }

        delete deposits[depositId];
    }

    // View functions
    function getDeposit(bytes32 depositId) external view returns (CrossChainDeposit memory) {
        return deposits[depositId];
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
        return ccipAdmin;
    }

    // ERC20 Implementation
    function name() public pure override returns (string memory) {
        return "uShares";
    }

    function symbol() public pure override returns (string memory) {
        return "uSHR";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Cross-chain token functions
    function mint(address to, uint256 amount) external onlyPositionManager {
        Errors.verifyNotZero(to);
        Errors.verifyNotZero(amount);

        // Check max transaction size instead of rate limit
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

    // Internal functions
    function _configureTokenPool(address pool, bool status) internal {
        Errors.verifyNotZero(pool);
        tokenPools[pool] = status;
        // Token pools need both minting and burning permissions
        minters[pool] = status;
        burners[pool] = status;
        emit TokenPoolConfigured(pool, status);
        emit MinterConfigured(pool, status);
        emit BurnerConfigured(pool, status);
    }
}
