// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IVaultRegistry } from "../../interfaces/IVaultRegistry.sol";
import { BaseModule } from "../../libraries/base/BaseModule.sol";
import { Errors } from "../../libraries/core/Errors.sol";
import { Events } from "../../libraries/core/Events.sol";
import { VaultLogic } from "../../libraries/logic/VaultLogic.sol";

/**
 * @title VaultRegistry
 * @notice Registry for tracking vaults and their shares across chains
 */
contract VaultRegistry is BaseModule, IVaultRegistry {
    using VaultLogic for address;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseModule(moduleId_, moduleVersion_) { }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a vault is active
     * @param vault The vault address
     * @return Whether the vault is active
     */
    function isVaultActive(address vault) external view returns (bool) {
        return vaults[vault];
    }

    /**
     * @notice Register a new vault
     * @param vault The vault address
     */
    function registerVault(address vault) external onlyRegistry {
        Errors.verifyAddress(vault);
        vault.isUSDCVault(_usdc);

        vaults[vault] = true;

        emit Events.VaultRegistered(vault);
    }

    /**
     * @notice Update a vault's status
     * @param vault The vault address
     * @param active Whether the vault is active
     */
    function updateVaultStatus(address vault, bool active) external onlyRegistry {
        Errors.verifyAddress(vault);

        vaults[vault] = active;
        emit Events.VaultUpdated(vault, active);
    }

    /**
     * @notice Remove a vault
     * @param vault The vault address
     */
    function removeVault(address vault) external onlyRegistry {
        Errors.verifyAddress(vault);
        Errors.verifyIfActive(vaults[vault]);

        delete vaults[vault];
        emit Events.VaultRemoved(vault);
    }
}
