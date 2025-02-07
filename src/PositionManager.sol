// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
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
contract PositionManager is IPositionManager, OwnableRoles {
    using SafeTransferLib for ERC20;
    using KeyManager for *;

    // Roles
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant HANDLER_ROLE = _ROLE_1;

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
        if (!hasAnyRole(msg.sender, HANDLER_ROLE)) revert Errors.NotHandler();
        _;
    }

    constructor(address _vaultRegistry) {
        Errors.verifyAddress(_vaultRegistry);
        vaultRegistry = IVaultRegistry(_vaultRegistry);
        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ADMIN_ROLE | HANDLER_ROLE);
    }

    /**
     * @notice Create a new position for a user
     * @param user User address
     * @param sourceChain Chain ID where user initiates deposit
     * @param destinationChain Chain ID where vault exists
     * @param vault Vault identifier
     * @param shares Initial share amount
     * @return positionKey Unique position identifier
     */
    function createPosition(
        address user,
        uint32 sourceChain,
        uint32 destinationChain,
        address vault,
        uint256 shares
    ) external onlyHandler returns (bytes32 positionKey) {
        // Validate inputs
        Errors.verifyAddress(user);
        Errors.verifyChainId(sourceChain);
        Errors.verifyChainId(destinationChain);
        Errors.verifyAddress(vault);

        // Validate vault is active
        if (!vaultRegistry.isVaultActive(destinationChain, vault)) {
            revert Errors.VaultNotActive();
        }

        // Generate position key
        positionKey = KeyManager.getPositionKey(user, sourceChain, destinationChain, vault);

        // Check if position already exists
        if (positions[positionKey].active) revert Errors.PositionExists();

        // Store position
        positions[positionKey] = Position({
            owner: user,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            destinationVault: vault,
            shares: shares,
            active: true,
            timestamp: uint64(block.timestamp)
        });

        // Update tracking
        userPositions[user].push(positionKey);
        chainPositions[sourceChain].push(positionKey);

        emit PositionCreated(user, sourceChain, destinationChain, vault, shares);
    }

    /**
     * @notice Update shares for an existing position
     * @param positionKey Unique position identifier
     * @param shares New share amount
     */
    function updatePosition(bytes32 positionKey, uint256 shares) external onlyHandler {
        Errors.verifyBytes32(positionKey);

        // Get position
        Position storage position = positions[positionKey];
        if (!position.active) revert Errors.PositionNotFound();

        // Update shares
        position.shares = shares;
        position.timestamp = block.timestamp;

        emit PositionUpdated(positionKey, shares, block.timestamp);
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
    function getUserPositions(address user) external view returns (bytes32[] memory) {
        return userPositions[user];
    }

    /**
     * @notice Get all position keys for a source chain
     * @param sourceChain Source chain ID
     * @return Array of position keys
     */
    function getChainPositions(uint32 sourceChain) external view returns (bytes32[] memory) {
        return chainPositions[sourceChain];
    }

    /**
     * @notice Check if a position exists and is active
     * @param positionKey Position identifier
     * @return bool Position status
     */
    function isPositionActive(bytes32 positionKey) external view returns (bool) {
        return positions[positionKey].active;
    }

    /**
     * @notice Get total positions for a user
     * @param user User address
     * @return uint256 Number of positions
     */
    function getUserPositionCount(address user) external view returns (uint256) {
        return userPositions[user].length;
    }

    /**
     * @notice Get total positions for a chain
     * @param sourceChain Chain ID
     * @return uint256 Number of positions
     */
    function getChainPositionCount(uint32 sourceChain) external view returns (uint256) {
        return chainPositions[sourceChain].length;
    }

    // Role management functions
    function grantRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _grantRoles(user, roles);
    }

    function revokeRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _removeRoles(user, roles);
    }

    function renounceRoles(uint256 roles) public payable virtual override {
        _removeRoles(msg.sender, roles);
    }

    function configureHandler(address handler, bool status) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(handler);
        if (status) {
            _grantRoles(handler, HANDLER_ROLE);
        } else {
            _removeRoles(handler, HANDLER_ROLE);
        }
        handlers[handler] = status;
        emit HandlerConfigured(handler, status);
    }

    function isHandler(address handler) external view returns (bool) {
        return hasAnyRole(handler, HANDLER_ROLE);
    }

    function getPosition(bytes32 positionKey) external view returns (Position memory) {
        Position memory pos = positions[positionKey];
        return Position({
            owner: pos.owner,
            sourceChain: pos.sourceChain,
            destinationChain: pos.destinationChain,
            destinationVault: pos.destinationVault,
            shares: pos.shares,
            active: pos.active,
            timestamp: pos.timestamp
        });
    }

    function getPositionKey(address owner, uint32 sourceChain, uint32 destinationChain, address destinationVault)
        external
        pure
        returns (bytes32)
    {
        return KeyManager.getPositionKey(owner, sourceChain, destinationChain, destinationVault);
    }
}
