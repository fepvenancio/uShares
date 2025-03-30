// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IVaultRegistry {
    event VaultRegistered(uint32 indexed domain, address indexed vault);
    event VaultUpdated(
        uint32 indexed domain,
        address indexed vault,
        bool active
    );
    event VaultRemoved(uint32 indexed domain, address indexed vault);
    event TokenPoolConfigured(uint32 indexed domain, address indexed tokenPool);

    /**
     * @notice Register a new vault
     * @param domain The domain ID
     * @param vault The vault address
     */
    function registerVault(uint32 domain, address vault) external;

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
    ) external;

    /**
     * @notice Remove a vault
     * @param domain The domain ID
     * @param vault The vault address
     */
    function removeVault(uint32 domain, address vault) external;

    /**
     * @notice Get vault information
     * @param domain The domain ID
     * @param vault The vault address
     * @return The vault information
     */
    function getVaultInfo(
        uint32 domain,
        address vault
    ) external view returns (DataTypes.VaultInfo memory);

    /**
     * @notice Check if a vault is active
     * @param domain The domain ID
     * @param vault The vault address
     * @return Whether the vault is active
     */
    function isVaultActive(
        uint32 domain,
        address vault
    ) external view returns (bool);

    function configureTokenPool(uint32 domain, address tokenPool) external;
}
