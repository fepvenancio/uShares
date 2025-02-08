// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IVaultRegistry} from "./interfaces/IVaultRegistry.sol";
import {DataTypes} from "./libs/DataTypes.sol";
import {Errors} from "./libs/Errors.sol";
import {KeyManager} from "./libs/KeyManager.sol";
import {RateLimiter} from "./libs/RateLimiter.sol";
import {IERC20} from "./interfaces/IERC20.sol";

/**
 * @title VaultRegistry
 * @notice Registry for tracking vaults and their shares across chains
 */
contract VaultRegistry is IVaultRegistry, OwnableRoles {
    using SafeTransferLib for address;
    using RateLimiter for RateLimiter.TokenBucket;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant HANDLER_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultRegistered(uint32 indexed domain, address indexed vault);
    event VaultDeregistered(uint32 indexed domain, address indexed vault);
    event SharesUpdated(uint32 indexed domain, address indexed vault, uint256 shares);
    event RateLimitConfigured(uint32 indexed domain, address indexed vault, RateLimiter.Config config);
    event TokenPoolConfigured(uint32 indexed domain, address indexed tokenPool);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The USDC token contract
    address public immutable usdc;

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice Mapping of vault key to vault info
    mapping(bytes32 => DataTypes.VaultInfo) public vaults;

    /// @notice Mapping of vault key to rate limit
    mapping(bytes32 => RateLimiter.TokenBucket) internal vaultRateLimits;

    /// @notice Mapping of domain to token pool
    mapping(uint32 => address) public domainToTokenPool;

    /// @notice Mapping of vault key to pending USDC amount
    mapping(bytes32 => uint256) public pendingUSDC;

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

    constructor(address _usdc) {
        Errors.verifyAddress(_usdc);
        usdc = _usdc;

        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ADMIN_ROLE | HANDLER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate the number of shares for a given USDC amount
     * @param domain The domain ID
     * @param vault The vault address
     * @param usdcAmount The amount of USDC
     * @return The number of shares
     */
    function calculateShares(
        uint32 domain,
        address vault,
        uint256 usdcAmount
    ) external view returns (uint256) {
        if (!_isVaultActive(domain, vault)) revert Errors.VaultNotActive();
        
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        
        // Get current vault shares and total USDC
        uint256 totalShares = vaults[vaultKey].totalShares;
        uint256 totalUSDC = IERC20(usdc).balanceOf(vault);
        
        // If no shares exist yet, use 1:1 ratio
        if (totalShares == 0 || totalUSDC == 0) {
            return usdcAmount;
        }
        
        // Calculate shares based on current ratio
        return (usdcAmount * totalShares) / totalUSDC;
    }

    /**
     * @notice Track pending USDC for a vault
     * @param domain The domain ID
     * @param vault The vault address
     * @param amount The USDC amount to add to pending
     */
    function addPendingUSDC(
        uint32 domain,
        address vault,
        uint256 amount
    ) external onlyRoles(HANDLER_ROLE) {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        pendingUSDC[vaultKey] += amount;
    }

    /**
     * @notice Remove USDC from pending after settlement
     * @param domain The domain ID
     * @param vault The vault address
     * @param amount The USDC amount to remove from pending
     */
    function removePendingUSDC(
        uint32 domain,
        address vault,
        uint256 amount
    ) external onlyRoles(HANDLER_ROLE) {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        if (amount > pendingUSDC[vaultKey]) revert Errors.InvalidAmount();
        pendingUSDC[vaultKey] -= amount;
    }

    /**
     * @notice Update the shares for a vault
     * @param domain The domain ID
     * @param vault The vault address
     * @param shares The new share amount
     * @return The updated share amount
     */
    function updateVaultShares(
        uint32 domain,
        address vault,
        uint256 shares
    ) external onlyRoles(HANDLER_ROLE) returns (uint256) {
        if (!_isVaultActive(domain, vault)) revert Errors.VaultNotActive();
        
        // Update shares
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        DataTypes.VaultInfo storage vaultInfo = vaults[vaultKey];
        vaultInfo.totalShares = uint96(shares);
        
        emit SharesUpdated(domain, vault, vaultInfo.totalShares);
        
        return vaultInfo.totalShares;
    }

    /**
     * @notice Check if a vault is active
     * @param domain The domain ID
     * @param vault The vault address
     * @return Whether the vault is active
     */
    function _isVaultActive(uint32 domain, address vault) internal view returns (bool) {
        return vaults[KeyManager.getVaultKey(domain, vault)].isActive;
    }

    /**
     * @notice Check if a vault is active
     * @param domain The domain ID
     * @param vault The vault address
     * @return Whether the vault is active
     */
    function isVaultActive(uint32 domain, address vault) external view returns (bool) {
        return _isVaultActive(domain, vault);
    }

    /**
     * @notice Register a new vault
     * @param domain The domain ID
     * @param vault The vault address
     */
    function registerVault(uint32 domain, address vault) external onlyRoles(ADMIN_ROLE) whenNotPaused {
        Errors.verifyChainId(domain);
        Errors.verifyAddress(vault);

        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        if (vaults[vaultKey].vaultAddress != address(0)) revert Errors.VaultExists();

        vaults[vaultKey] = DataTypes.VaultInfo({
            vaultAddress: vault,
            domain: domain,
            totalShares: 0,
            lastUpdate: uint64(block.timestamp),
            isActive: true
        });

        emit VaultRegistered(domain, vault);
    }

    /**
     * @notice Update a vault's status
     * @param domain The domain ID
     * @param vault The vault address
     * @param active Whether the vault is active
     */
    function updateVaultStatus(uint32 domain, address vault, bool active) external onlyRoles(ADMIN_ROLE) whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        DataTypes.VaultInfo storage vaultInfo = vaults[vaultKey];
        if (vaultInfo.vaultAddress == address(0)) revert Errors.VaultNotFound();

        vaultInfo.isActive = active;
        emit VaultDeregistered(domain, vault);
    }

    /**
     * @notice Remove a vault
     * @param domain The domain ID
     * @param vault The vault address
     */
    function removeVault(uint32 domain, address vault) external onlyRoles(ADMIN_ROLE) whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        DataTypes.VaultInfo memory vaultInfo = vaults[vaultKey];
        if (vaultInfo.vaultAddress == address(0)) revert Errors.VaultNotFound();
        if (vaultInfo.isActive) revert Errors.VaultActive();

        delete vaults[vaultKey];
        emit VaultDeregistered(domain, vault);
    }

    /**
     * @notice Get vault information
     * @param domain The domain ID
     * @param vault The vault address
     * @return The vault information
     */
    function getVaultInfo(uint32 domain, address vault) external view returns (DataTypes.VaultInfo memory) {
        return vaults[KeyManager.getVaultKey(domain, vault)];
    }

    /**
     * @notice Get all vaults for a domain
     * @param domain The domain ID
     * @return Array of vault addresses
     */
    function getChainVaults(uint32 domain) external view returns (address[] memory) {
        uint256 count = 0;
        bytes32[] memory keys = new bytes32[](100); // Max 100 vaults per domain

        // First pass: count active vaults
        for (uint256 i = 0; i < 100; i++) {
            bytes32 key = KeyManager.getVaultKey(domain, address(uint160(i)));
            if (vaults[key].vaultAddress != address(0)) {
                keys[count] = key;
                count++;
            }
        }

        // Second pass: build return array
        address[] memory addresses = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addresses[i] = vaults[keys[i]].vaultAddress;
        }

        return addresses;
    }

    /**
     * @notice Configure token pool for a domain
     * @param domain The domain ID
     * @param tokenPool The token pool address
     */
    function configureTokenPool(uint32 domain, address tokenPool) external onlyRoles(ADMIN_ROLE) whenNotPaused {
        Errors.verifyChainId(domain);
        Errors.verifyAddress(tokenPool);
        domainToTokenPool[domain] = tokenPool;
        emit TokenPoolConfigured(domain, tokenPool);
    }
}
