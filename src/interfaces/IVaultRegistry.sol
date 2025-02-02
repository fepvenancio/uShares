// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DataTypes} from "../types/DataTypes.sol";

interface IVaultRegistry {
    function registerVault(
        uint32 chainId,
        address vault
    ) external;

    function updateVaultStatus(
        uint32 chainId,
        address vault,
        bool active
    ) external;

    function removeVault(
        uint32 chainId,
        address vault
    ) external;

    function getVaultInfo(
        uint32 chainId,
        address vault
    ) external view returns (DataTypes.VaultInfo memory);

    function isVaultActive(
        uint32 chainId,
        address vault
    ) external view returns (bool);

    function getChainVaults(
        uint32 chainId
    ) external view returns (address[] memory);
}
