// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IVaultRegistry} from "../../src/interfaces/IVaultRegistry.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";

contract MockVaultRegistry is IVaultRegistry {
    mapping(uint32 => address[]) public chainVaults;
    mapping(bytes32 => DataTypes.VaultInfo) public vaults;

    function setVaultInfo(uint32 chainId, address vault, DataTypes.VaultInfo memory info) external {
        bytes32 key = keccak256(abi.encode(chainId, vault));
        vaults[key] = info;
    }

    function registerVault(uint32 chainId, address vault) external {
        bytes32 key = keccak256(abi.encode(chainId, vault));
        vaults[key] = DataTypes.VaultInfo({
            vaultAddress: vault,
            chainId: chainId,
            totalShares: 0,
            lastUpdate: uint64(block.timestamp),
            active: true
        });
        chainVaults[chainId].push(vault);
    }

    function updateVaultStatus(uint32 chainId, address vault, bool active) external {
        bytes32 key = keccak256(abi.encode(chainId, vault));
        vaults[key].active = active;
    }

    function removeVault(uint32 chainId, address vault) external {
        bytes32 key = keccak256(abi.encode(chainId, vault));
        delete vaults[key];
    }

    function updateVaultShares(uint32 chainId, address vault, uint96 newTotalShares) external {
        bytes32 key = keccak256(abi.encode(chainId, vault));
        vaults[key].totalShares = newTotalShares;
        vaults[key].lastUpdate = uint64(block.timestamp);
    }

    function getVaultInfo(uint32 chainId, address vault) external view returns (DataTypes.VaultInfo memory) {
        bytes32 key = keccak256(abi.encode(chainId, vault));
        return vaults[key];
    }

    function isVaultActive(uint32 chainId, address vault) external view returns (bool) {
        bytes32 key = keccak256(abi.encode(chainId, vault));
        return vaults[key].active;
    }

    function getChainVaults(uint32 chainId) external view returns (address[] memory) {
        return chainVaults[chainId];
    }
} 