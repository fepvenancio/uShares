// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IVaultRegistry} from "./interfaces/IVaultRegistry.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {KeyManager} from "./libs/KeyManager.sol";
import {Errors} from "./libs/Errors.sol";

/**
 * @title PositionManager
 * @notice Manages user positions across different chains and vaults
 * @dev Tracks and manages user positions in cross-chain vaults
 */
contract PositionManager is IPositionManager, Ownable {
    using SafeTransferLib for ERC20;
    using KeyManager for *;

    // State variables
    IVaultRegistry public immutable vaultRegistry;
    mapping(address => bool) public handlers;

    // Position storage - userKey (source) => vaultId => Position
    mapping(bytes32 => Position) public positions;

    // User tracking - address => positionKeys[]
    mapping(address => bytes32[]) public userPositions;

    // Chain tracking - sourceChain => positionKeys[]
    mapping(uint32 => bytes32[]) public chainPositions;

    modifier onlyHandler() {
        if (!handlers[msg.sender]) revert Errors.NotHandler();
        _;
    }

    constructor(address _vaultRegistry) {
        Errors.verifyNotZero(_vaultRegistry);
        vaultRegistry = IVaultRegistry(_vaultRegistry);
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Create a new position for a user
     * @param owner User address
     * @param sourceChain Chain ID where user initiates deposit
     * @param destinationChain Chain ID where vault exists
     * @param destinationVault Vault identifier
     * @param shares Initial share amount
     * @return positionKey Unique position identifier
     */
    function createPosition(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault,
        uint256 shares
    ) external returns (bytes32 positionKey) {
        // Validate caller is handler
        if (!handlers[msg.sender]) revert Errors.NotHandler();

        // Validate inputs
        Errors.verifyNotZero(owner);
        Errors.verifyNotZero(sourceChain);
        Errors.verifyNotZero(destinationChain);
        Errors.verifyNotZero(destinationVault);

        // Validate vault is active
        if (!vaultRegistry.isVaultActive(destinationChain, destinationVault)) {
            revert Errors.VaultNotActive();
        }

        // Generate position key
        positionKey = KeyManager.getPositionKey(
            owner,
            sourceChain,
            destinationChain,
            destinationVault
        );

        // Check if position already exists
        if (positions[positionKey].active) revert Errors.PositionExists();

        // Store position
        positions[positionKey] = Position({
            owner: owner,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            destinationVault: destinationVault,
            shares: shares,
            active: true,
            timestamp: uint64(block.timestamp)
        });

        // Update tracking
        userPositions[owner].push(positionKey);
        chainPositions[sourceChain].push(positionKey);

        emit PositionCreated(
            owner,
            sourceChain,
            destinationChain,
            destinationVault,
            shares
        );
    }

    /**
     * @notice Update shares for an existing position
     * @param positionKey Unique position identifier
     * @param newShares New share amount
     */
    function updatePosition(
        bytes32 positionKey,
        uint256 newShares
    ) external onlyHandler {
        // Validate input and position exists
        Errors.verifyNotZero(positionKey);

        Position storage position = positions[positionKey];
        if (!position.active) revert Errors.PositionNotFound();

        // Update position
        position.shares = newShares;
        position.timestamp = block.timestamp;

        emit PositionUpdated(
            positionKey,
            newShares,
            block.timestamp
        );
    }

    /**
     * @notice Close an existing position
     * @param positionKey Unique position identifier
     */
    function closePosition(bytes32 positionKey) external onlyHandler {
        // Validate position exists
        Position storage position = positions[positionKey];
        if (!position.active) revert Errors.PositionNotFound();

        // Deactivate position
        position.active = false;
        position.shares = 0;
        position.timestamp = block.timestamp;

        emit PositionClosed(positionKey);
    }

    /**
     * @notice Get all position keys for a user
     * @param user User address
     * @return Array of position keys
     */
    function getUserPositions(
        address user
    ) external view returns (bytes32[] memory) {
        return userPositions[user];
    }

    /**
     * @notice Get all position keys for a source chain
     * @param sourceChain Source chain ID
     * @return Array of position keys
     */
    function getChainPositions(
        uint32 sourceChain
    ) external view returns (bytes32[] memory) {
        return chainPositions[sourceChain];
    }

    /**
     * @notice Check if a position exists and is active
     * @param positionKey Position identifier
     * @return bool Position status
     */
    function isPositionActive(
        bytes32 positionKey
    ) external view returns (bool) {
        return positions[positionKey].active;
    }

    /**
     * @notice Get total positions for a user
     * @param user User address
     * @return uint256 Number of positions
     */
    function getUserPositionCount(
        address user
    ) external view returns (uint256) {
        return userPositions[user].length;
    }

    /**
     * @notice Get total positions for a chain
     * @param sourceChain Chain ID
     * @return uint256 Number of positions
     */
    function getChainPositionCount(
        uint32 sourceChain
    ) external view returns (uint256) {
        return chainPositions[sourceChain].length;
    }

    function configureHandler(address handler, bool status) external onlyOwner {
        Errors.verifyNotZero(handler);
        handlers[handler] = status;
        emit HandlerConfigured(handler, status);
    }

    function isHandler(address handler) external view returns (bool) {
        return handlers[handler];
    }

    function getPosition(
        bytes32 positionKey
    ) external view returns (Position memory) {
        Position memory pos = positions[positionKey];
        return
            Position({
                owner: pos.owner,
                sourceChain: pos.sourceChain,
                destinationChain: pos.destinationChain,
                destinationVault: pos.destinationVault,
                shares: pos.shares,
                active: pos.active,
                timestamp: pos.timestamp
            });
    }

    function getPositionKey(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault
    ) external pure returns (bytes32) {
        return KeyManager.getPositionKey(owner, sourceChain, destinationChain, destinationVault);
    }
}
