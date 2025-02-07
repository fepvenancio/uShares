// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPositionManager} from "../../src/interfaces/IPositionManager.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";

contract MockPositionManager is IPositionManager {
    mapping(bytes32 => DataTypes.Position) public positions;
    mapping(address => bool) public handlers;

    function configureHandler(address handler, bool status) external {
        handlers[handler] = status;
    }

    function isHandler(address handler) external view returns (bool) {
        return handlers[handler];
    }

    function createPosition(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault,
        uint256 shares
    ) external returns (bytes32 positionKey) {
        positionKey = getPositionKey(owner, sourceChain, destinationChain, destinationVault);
        positions[positionKey] = DataTypes.Position({
            owner: owner,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            destinationVault: destinationVault,
            shares: shares,
            active: true,
            timestamp: block.timestamp
        });
        return positionKey;
    }

    function updatePosition(bytes32 positionKey, uint256 newShares) external {
        positions[positionKey].shares = newShares;
    }

    function closePosition(bytes32 positionKey) external {
        positions[positionKey].active = false;
    }

    function getPosition(bytes32 positionKey) external view returns (DataTypes.Position memory) {
        return positions[positionKey];
    }

    function getUserPositions(address user) external view returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function getChainPositions(uint32 chainId) external view returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function isPositionActive(bytes32 positionKey) external view returns (bool) {
        return positions[positionKey].active;
    }

    function getChainPositionCount(uint32 sourceChain) external view returns (uint256) {
        return 0;
    }

    function getUserPositionCount(address user) external view returns (uint256) {
        return 0;
    }

    function getPositionKey(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(owner, sourceChain, destinationChain, destinationVault));
    }
} 