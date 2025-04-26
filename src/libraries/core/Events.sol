// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title Events
 * @notice Library containing events used in the UShares protocol
 */
library Events {
    // Proxy
    event ProxyCreated(address indexed proxy, uint256 moduleId);

    // Position Manager
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

    // Vault Registry
    event VaultRegistered(uint32 indexed domain, address indexed vault);
    event VaultUpdated(uint32 indexed domain, address indexed vault, bool active);
    event VaultRemoved(uint32 indexed domain, address indexed vault);
    event TokenPoolConfigured(uint32 indexed domain, address indexed tokenPool);
}
