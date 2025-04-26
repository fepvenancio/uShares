// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IPositionManager } from "./interfaces/IPositionManager.sol";
import { IVaultRegistry } from "./interfaces/IVaultRegistry.sol";

import { Errors } from "./libraries/core/Errors.sol";
import { KeyManager } from "./libraries/core/KeyManager.sol";
import { DataTypes } from "./libraries/types/DataTypes.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

/**
 * @title PositionManager
 * @notice Manages user positions across different chains and vaults
 * @dev Tracks and manages user positions in cross-chain vaults
 * @custom:security-contact security@ushares.com
 */
contract PositionManager is IPositionManager, OwnableRoles {
    using KeyManager for *;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for admin operations
    uint256 public constant ADMIN_ROLE = _ROLE_0;

    /// @notice Role identifier for handler operations (creating/updating positions)
    uint256 public constant HANDLER_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the vault registry contract
    IVaultRegistry public immutable vaultRegistry;

    /// @notice Mapping of position keys to Position structs
    /// @dev Key format: keccak256(abi.encode(owner, sourceChain, destinationChain, destinationVault))
    mapping(bytes32 => DataTypes.Position) public positions;

    /// @notice Mapping of user addresses to their position keys
    mapping(address => bytes32[]) public userPositions;

    /// @notice Mapping of domain ID to token pool address
    mapping(uint32 => address) public domainTokenPools;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the PositionManager contract
    /// @param _vaultRegistry Address of the vault registry contract
    constructor(address _vaultRegistry) {
        Errors.verifyAddress(_vaultRegistry);

        vaultRegistry = IVaultRegistry(_vaultRegistry);

        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ADMIN_ROLE);
        _grantRoles(address(this), HANDLER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                            POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new position for a user
     * @dev Validates inputs and vault status before creating position
     * @param user User address who owns the position
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
    )
        external
        onlyRoles(HANDLER_ROLE)
        returns (bytes32 positionKey)
    {
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
        positions[positionKey] = DataTypes.Position({
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

        emit PositionCreated(user, sourceChain, destinationChain, vault, shares);
    }

    /**
     * @notice Updates shares for an existing position
     * @dev Only active positions can be updated
     * @param positionKey Unique position identifier
     * @param shares New share amount
     */
    function updatePosition(bytes32 positionKey, uint256 shares) external onlyRoles(HANDLER_ROLE) {
        Errors.verifyBytes32(positionKey);

        // Get position
        DataTypes.Position storage position = positions[positionKey];
        if (!position.active) revert Errors.PositionNotFound();

        // Update shares
        position.shares = shares;
        position.timestamp = uint64(block.timestamp);

        emit PositionUpdated(positionKey, shares, block.timestamp);
    }

    /**
     * @notice Closes an existing position
     * @dev Sets position to inactive and zeros out shares
     * @param positionKey Unique position identifier
     */
    function closePosition(bytes32 positionKey) external onlyRoles(HANDLER_ROLE) {
        // Validate position exists
        DataTypes.Position storage position = positions[positionKey];
        if (!position.active) revert Errors.PositionNotFound();

        // Deactivate position
        position.active = false;
        position.shares = 0;
        position.timestamp = uint64(block.timestamp);

        emit PositionClosed(positionKey);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets all position keys for a user
     * @param user User address
     * @return Array of position keys
     */
    function getUserPositions(address user) external view returns (bytes32[] memory) {
        return userPositions[user];
    }

    /**
     * @notice Checks if a position exists and is active
     * @param positionKey Position identifier
     * @return bool Position status
     */
    function isPositionActive(bytes32 positionKey) external view returns (bool) {
        return positions[positionKey].active;
    }

    /**
     * @notice Gets total positions for a user
     * @param user User address
     * @return uint256 Number of positions
     */
    function getUserPositionCount(address user) external view returns (uint256) {
        return userPositions[user].length;
    }

    /**
     * @notice Configures handler status for an address
     * @dev Only callable by admin
     * @param handler Address to configure
     * @param status Handler status to set
     */
    function configureHandler(address handler, bool status) external onlyRoles(ADMIN_ROLE) {
        Errors.verifyAddress(handler);
        if (status) {
            _grantRoles(handler, HANDLER_ROLE);
        } else {
            _removeRoles(handler, HANDLER_ROLE);
        }

        emit HandlerConfigured(handler, status);
    }

    /**
     * @notice Checks if an address is a handler
     * @param handler Address to check
     * @return bool Handler status
     */
    function isHandler(address handler) external view returns (bool) {
        return hasAnyRole(handler, HANDLER_ROLE);
    }

    /**
     * @notice Gets position details
     * @param positionKey Position identifier
     * @return Position struct containing position details
     */
    function getPosition(bytes32 positionKey) external view returns (DataTypes.Position memory) {
        DataTypes.Position memory pos = positions[positionKey];
        return DataTypes.Position({
            owner: pos.owner,
            sourceChain: pos.sourceChain,
            destinationChain: pos.destinationChain,
            destinationVault: pos.destinationVault,
            shares: pos.shares,
            active: pos.active,
            timestamp: pos.timestamp
        });
    }

    /**
     * @notice Generates a position key from components
     * @param owner Position owner address
     * @param sourceChain Source domain ID
     * @param destinationChain Destination domain ID
     * @param destinationVault Destination vault address
     * @return bytes32 Generated position key
     */
    function getPositionKey(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault
    )
        external
        pure
        returns (bytes32)
    {
        return KeyManager.getPositionKey(owner, sourceChain, destinationChain, destinationVault);
    }
}
