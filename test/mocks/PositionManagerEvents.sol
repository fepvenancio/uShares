// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

contract PositionManagerEvents {
    event PositionCreated(
        address indexed user,
        uint32 indexed sourceChain,
        uint32 indexed destinationChain,
        address destinationVault,
        uint256 shares
    );
    event PositionUpdated(bytes32 indexed positionKey, uint256 shares, uint256 timestamp);
    event PositionClosed(bytes32 indexed positionKey);
    event HandlerConfigured(address indexed handler, bool status);
}
