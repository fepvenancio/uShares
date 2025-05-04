// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IVaultRegistry {
    /**
     * @notice Register a new vault
     * @param vault The vault address
     */
    function registerVault(address vault) external;

    /**
     * @notice Update a vault's status
     * @param vault The vault address
     * @param active Whether the vault is active
     */
    function updateVaultStatus(address vault, bool active) external;

    /**
     * @notice Remove a vault
     * @param vault The vault address
     */
    function removeVault(address vault) external;

    /**
     * @notice Get vault information
     * @param vault The vault address
     * @return The vault information
     */
    function isVaultActive(address vault) external view returns (bool);
}
