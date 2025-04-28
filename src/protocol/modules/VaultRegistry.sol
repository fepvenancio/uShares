// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC4626 } from "../../interfaces/IERC4626.sol";
import { IVaultRegistry } from "../../interfaces/IVaultRegistry.sol";

import { BaseModule } from "../../libraries/base/BaseModule.sol";
import { Errors } from "../../libraries/core/Errors.sol";
import { Events } from "../../libraries/core/Events.sol";
import { KeyManager } from "../../libraries/logic/KeyManager.sol";
import { VaultLib } from "../../libraries/logic/VaultLib.sol";
import { DataTypes } from "../../libraries/types/DataTypes.sol";

/**
 * @title VaultRegistry
 * @notice Registry for tracking vaults and their shares across chains
 */
contract VaultRegistry is BaseModule, IVaultRegistry {
    using VaultLib for address;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice Whether the contract is paused
    bool public paused;

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

    constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseModule(moduleId_, moduleVersion_) { }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
    function registerVault(uint32 domain, address vault) external onlyRegistry whenNotPaused {
        Errors.verifyChainId(domain);
        Errors.verifyAddress(vault);
        vault.isUSDCVault(_usdc);

        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        Errors.verifyAddress(vaults[vaultKey].vaultAddress);

        vaults[vaultKey] = DataTypes.VaultInfo({
            vaultAddress: vault,
            domain: domain,
            lastUpdate: uint64(block.timestamp),
            isActive: true
        });

        emit Events.VaultRegistered(domain, vault);
    }

    /**
     * @notice Update a vault's status
     * @param domain The domain ID
     * @param vault The vault address
     * @param active Whether the vault is active
     */
    function updateVaultStatus(uint32 domain, address vault, bool active) external onlyRegistry whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        DataTypes.VaultInfo storage vaultInfo = vaults[vaultKey];
        Errors.verifyAddress(vaultInfo.vaultAddress);

        vaultInfo.isActive = active;
        emit Events.VaultUpdated(domain, vault, active);
    }

    /**
     * @notice Remove a vault
     * @param domain The domain ID
     * @param vault The vault address
     */
    function removeVault(uint32 domain, address vault) external onlyRegistry whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(domain, vault);
        DataTypes.VaultInfo memory vaultInfo = vaults[vaultKey];
        Errors.verifyAddress(vaultInfo.vaultAddress);
        Errors.verifyIfActive(vaultInfo.isActive);

        delete vaults[vaultKey];
        emit Events.VaultRemoved(domain, vault);
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
}
