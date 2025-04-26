// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { DataTypes } from "../libraries/types/DataTypes.sol";

interface IPositionManager {
    function createPosition(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault,
        uint256 shares
    )
        external
        returns (bytes32 positionKey);

    function updatePosition(bytes32 positionKey, uint256 newShares) external;

    function closePosition(bytes32 positionKey) external;

    function getPosition(bytes32 positionKey) external view returns (DataTypes.Position memory);

    function getUserPositions(address user) external view returns (bytes32[] memory);

    function isPositionActive(bytes32 positionKey) external view returns (bool);

    function getUserPositionCount(address user) external view returns (uint256);

    function getPositionKey(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault
    )
        external
        pure
        returns (bytes32);
}
