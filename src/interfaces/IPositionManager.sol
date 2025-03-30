// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IPositionManager {
    // Events
    event PositionCreated(
        address indexed user,
        uint32 indexed sourceChain,
        uint32 indexed destinationChain,
        address destinationVault,
        uint256 shares
    );

    event PositionUpdated(bytes32 indexed positionKey, uint256 newShares, uint256 timestamp);

    event PositionClosed(bytes32 indexed positionKey);

    event HandlerConfigured(address indexed handler, bool status);

    // Functions
    function configureHandler(address handler, bool status) external;

    function isHandler(address handler) external view returns (bool);

    function createPosition(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault,
        uint256 shares
    ) external returns (bytes32 positionKey);

    function updatePosition(bytes32 positionKey, uint256 newShares) external;

    function closePosition(bytes32 positionKey) external;

    function getPosition(bytes32 positionKey) external view returns (DataTypes.Position memory);

    function getUserPositions(address user) external view returns (bytes32[] memory);

    function isPositionActive(bytes32 positionKey) external view returns (bool);

    function getUserPositionCount(address user) external view returns (uint256);

    function getPositionKey(address owner, uint32 sourceChain, uint32 destinationChain, address destinationVault)
        external
        pure
        returns (bytes32);
}
