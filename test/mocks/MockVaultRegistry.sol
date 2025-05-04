// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IVaultRegistry } from "../../src/interfaces/IVaultRegistry.sol";

import { Events } from "../../src/libraries/core/Events.sol";
import { DataTypes } from "../../src/libraries/types/DataTypes.sol";

contract MockVaultRegistry is IVaultRegistry {
    mapping(address => bool) public vaultStatus;
    mapping(uint32 => address) public tokenPools;

    function registerVault(address vault) external {
        vaultStatus[vault] = true;
    }

    function updateVaultStatus(address vault, bool active) external {
        vaultStatus[vault] = active;
    }

    function removeVault(address vault) external {
        delete vaultStatus[vault];
    }

    function isVaultActive(address vault) external view returns (bool) {
        return vaultStatus[vault];
    }
}
