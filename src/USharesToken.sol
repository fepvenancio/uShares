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
        if (paused) revert Errors.Paused();
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
        Errors.verifyAddress(_positionManager);
        Errors.verifyAddress(_ccipAdmin);
        Errors.verifyAddress(_cctp);
        Errors.verifyAddress(_usdc);
        Errors.verifyAddress(_router);

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
        if (!tokenPools[msg.sender]) revert Errors.NotTokenPool();
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

    // Cross-chain deposit flow
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
            uint32(destinationChainSelector), 
            bytes32(uint256(uint160(address(this)))), 
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

        // Step 1: Verify CCTP message
        cctp.receiveMessage(attestation, bytes(""));

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

    // Withdrawal flow
    function withdraw(uint256 uSharesAmount, address vault) external whenNotPaused {
        Errors.verifyNumber(uSharesAmount);
        if (uSharesAmount > MAX_TRANSACTION_SIZE) revert Errors.ExceedsMaxSize();

        // Burn uShares
        _burn(msg.sender, uSharesAmount);

        // Withdraw USDC from vault
        uint256 usdcAmount = IVault(vault).withdraw(uSharesAmount, msg.sender, address(this));
        if (usdcAmount == 0) revert Errors.InvalidAmount();

        // Transfer USDC to user
        USDC.safeTransfer(msg.sender, usdcAmount);
    }

    // Admin functions
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

    function configureMinter(address minter, bool status) external onlyOwner {
        Errors.verifyAddress(minter);
        minters[minter] = status;
        emit MinterConfigured(minter, status);
    }

    function configureBurner(address burner, bool status) external onlyOwner {
        Errors.verifyAddress(burner);
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
        Errors.verifyAddress(pool);
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
        Errors.verifyAddress(newAdmin);
        address oldAdmin = ccipAdmin;
        ccipAdmin = newAdmin;
        emit CCIPAdminUpdated(oldAdmin, newAdmin);
    }

    function setVaultRegistry(address _vaultRegistry) external onlyOwner {
        Errors.verifyAddress(_vaultRegistry);
        vaultRegistry = IVaultRegistry(_vaultRegistry);
    }

    // Recovery functions
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

    // Internal functions
    function _configureTokenPool(address pool, bool status) internal {
        Errors.verifyAddress(pool);
        tokenPools[pool] = status;
        // Token pools need both minting and burning permissions
        minters[pool] = status;
        burners[pool] = status;
        emit TokenPoolConfigured(pool, status);
        emit MinterConfigured(pool, status);
        emit BurnerConfigured(pool, status);
    }

    // Internal function for vault deposits
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
}
