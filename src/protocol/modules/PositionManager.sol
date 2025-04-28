// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IPositionManager } from "../../interfaces/IPositionManager.sol";
import { IVaultRegistry } from "../../interfaces/IVaultRegistry.sol";
import { BaseModule } from "libraries/base/BaseModule.sol";
import { Errors } from "libraries/core/Errors.sol";
import { Events } from "libraries/core/Events.sol";

import { KeyLogic } from "libraries/logic/KeyLogic.sol";
import { DataTypes } from "libraries/types/DataTypes.sol";

/**
 * @title PositionManager
 * @notice Manages user positions across different chains and vaults
 */
contract PositionManager is BaseModule, IPositionManager {
    using KeyLogic for *;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of user addresses to their position keys
    address public _vaultRegistry;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the PositionManager contract
    constructor(
        uint256 moduleId_,
        bytes32 moduleVersion_,
        address vaultRegistry_
    )
        BaseModule(moduleId_, moduleVersion_)
    {
        _vaultRegistry = vaultRegistry_;
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
        onlyHandler
        returns (bytes32 positionKey)
    {
        // Validate inputs
        Errors.verifyAddress(user);
        Errors.verifyChainId(sourceChain);
        Errors.verifyChainId(destinationChain);
        Errors.verifyAddress(vault);

        // Validate vault is active
        if (!IVaultRegistry(_vaultRegistry).isVaultActive(destinationChain, vault)) {
            revert Errors.VaultNotActive();
        }

        // Generate position key
        positionKey = KeyLogic.getPositionKey(user, sourceChain, destinationChain, vault);

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

        emit Events.PositionCreated(user, sourceChain, destinationChain, vault, shares);
    }

    /**
     * @notice Updates shares for an existing position
     * @dev Only active positions can be updated
     * @param positionKey Unique position identifier
     * @param shares New share amount
     */
    function updatePosition(bytes32 positionKey, uint256 shares) external onlyHandler {
        Errors.verifyBytes32(positionKey);

        // Get position
        DataTypes.Position storage position = positions[positionKey];
        if (!position.active) revert Errors.PositionNotFound();

        // Update shares
        position.shares = shares;
        position.timestamp = uint64(block.timestamp);

        emit Events.PositionUpdated(positionKey, shares, block.timestamp);
    }

    /**
     * @notice Closes an existing position
     * @dev Sets position to inactive and zeros out shares
     * @param positionKey Unique position identifier
     */
    function closePosition(bytes32 positionKey) external onlyHandler {
        // Validate position exists
        // TODO: DUST !? what if theres dust left in the position?
        DataTypes.Position storage position = positions[positionKey];
        if (!position.active) revert Errors.PositionNotFound();

        // Deactivate position
        position.active = false;
        position.shares = 0;
        position.timestamp = uint64(block.timestamp);

        emit Events.PositionClosed(positionKey);
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
        return KeyLogic.getPositionKey(owner, sourceChain, destinationChain, destinationVault);
    }
}
