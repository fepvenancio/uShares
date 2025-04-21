// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IVaultRegistry } from "../../src/interfaces/IVaultRegistry.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";

contract MockVaultRegistry is IVaultRegistry {
    mapping(uint32 => mapping(address => bool)) public vaultStatus;
    mapping(uint32 => mapping(address => DataTypes.VaultInfo)) public vaultInfo;
    mapping(uint32 => address) public tokenPools;

    function registerVault(uint32 domain, address vault) external {
        vaultInfo[domain][vault] = DataTypes.VaultInfo({
            vaultAddress: vault,
            domain: domain,
            lastUpdate: uint64(block.timestamp),
            isActive: true
        });
        vaultStatus[domain][vault] = true;
        emit VaultRegistered(domain, vault);
    }

    function updateVaultStatus(uint32 domain, address vault, bool active) external {
        vaultInfo[domain][vault].isActive = active;
        vaultStatus[domain][vault] = active;
        emit VaultUpdated(domain, vault, active);
    }

    function removeVault(uint32 domain, address vault) external {
        delete vaultInfo[domain][vault];
        delete vaultStatus[domain][vault];
        emit VaultRemoved(domain, vault);
    }

    function getVaultInfo(uint32 domain, address vault) external view returns (DataTypes.VaultInfo memory) {
        return vaultInfo[domain][vault];
    }

    function isVaultActive(uint32 domain, address vault) external view returns (bool) {
        return vaultStatus[domain][vault];
    }

    function configureTokenPool(uint32 domain, address tokenPool) external {
        tokenPools[domain] = tokenPool;
        emit TokenPoolConfigured(domain, tokenPool);
    }
}
