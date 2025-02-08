// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DataTypes} from "../libs/DataTypes.sol";

interface IVaultRegistry {
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
    function updateVaultStatus(uint32 domain, address vault, bool active) external;

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
    function getVaultInfo(uint32 domain, address vault) external view returns (DataTypes.VaultInfo memory);

    /**
     * @notice Get all vaults for a domain
     * @param domain The domain ID
     * @return Array of vault addresses
     */
    function getChainVaults(uint32 domain) external view returns (address[] memory);

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
    ) external view returns (uint256);

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
    ) external returns (uint256);

    /**
     * @notice Check if a vault is active
     * @param domain The domain ID
     * @param vault The vault address
     * @return Whether the vault is active
     */
    function isVaultActive(uint32 domain, address vault) external view returns (bool);
}
