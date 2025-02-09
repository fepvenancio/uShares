// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {IVaultRegistry} from "./interfaces/IVaultRegistry.sol";
import {DataTypes} from "./libs/DataTypes.sol";
import {Errors} from "./libs/Errors.sol";
import {KeyManager} from "./libs/KeyManager.sol";
import {VaultLib} from "./libs/VaultLib.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title VaultRegistry
 * @notice Registry for tracking vaults and their shares across chains
 */
contract VaultRegistry is IVaultRegistry, OwnableRoles {
    using VaultLib for address;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant REGISTRY_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The USDC token contract
    address public immutable usdc;

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice Mapping of vault key to vault info
    mapping(bytes32 => DataTypes.VaultInfo) public vaults;

    /// @notice Mapping of domain to token pool
    mapping(uint32 => address) public domainToTokenPool;

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
        _grantRoles(msg.sender, ADMIN_ROLE);
        _grantRoles(msg.sender, REGISTRY_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a vault is active
     * @param domain The domain ID
     * @param vault The vault address
     * @return Whether the vault is active
     */
    function _isVaultActive(
        uint32 domain,
        address vault
    ) internal view returns (bool) {
        return vaults[KeyManager.getVaultKey(domain, vault)].isActive;
    }

    /**
     * @notice Check if a vault is active
     * @param domain The domain ID
     * @param vault The vault address
     * @return Whether the vault is active
     */
    function isVaultActive(
        uint32 domain,
        address vault
    ) external view returns (bool) {
        return _isVaultActive(domain, vault);
    }

    /**
     * @notice Register a new vault
     * @param domain The domain ID
     * @param vault The vault address
     */
    function registerVault(
        uint32 domain,
        address vault
    ) external onlyRoles(REGISTRY_ROLE) whenNotPaused {
        Errors.verifyChainId(domain);
        Errors.verifyAddress(vault);
        vault.isUSDCVault(usdc);

        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        Errors.verifyAddress(vaults[vaultKey].vaultAddress);

        vaults[vaultKey] = DataTypes.VaultInfo({
            vaultAddress: vault,
            domain: domain,
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
    function updateVaultStatus(
        uint32 domain,
        address vault,
        bool active
    ) external onlyRoles(REGISTRY_ROLE) whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        DataTypes.VaultInfo storage vaultInfo = vaults[vaultKey];
        Errors.verifyAddress(vaultInfo.vaultAddress);

        vaultInfo.isActive = active;
        emit VaultUpdated(domain, vault, active);
    }

    /**
     * @notice Remove a vault
     * @param domain The domain ID
     * @param vault The vault address
     */
    function removeVault(
        uint32 domain,
        address vault
    ) external onlyRoles(REGISTRY_ROLE) whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        DataTypes.VaultInfo memory vaultInfo = vaults[vaultKey];
        Errors.verifyAddress(vaultInfo.vaultAddress);
        Errors.verifyIfActive(vaultInfo.isActive);

        delete vaults[vaultKey];
        emit VaultRemoved(domain, vault);
    }

    /**
     * @notice Get vault information
     * @param domain The domain ID
     * @param vault The vault address
     * @return The vault information
     */
    function getVaultInfo(
        uint32 domain,
        address vault
    ) external view returns (DataTypes.VaultInfo memory) {
        return vaults[KeyManager.getVaultKey(domain, vault)];
    }

    /**
     * @notice Configure token pool for a domain
     * @param domain The domain ID
     * @param tokenPool The token pool address
     */
    function configureTokenPool(
        uint32 domain,
        address tokenPool
    ) external onlyRoles(REGISTRY_ROLE) whenNotPaused {
        Errors.verifyNumber(domain);
        Errors.verifyAddress(tokenPool);
        domainToTokenPool[domain] = tokenPool;
        emit TokenPoolConfigured(domain, tokenPool);
    }
}
