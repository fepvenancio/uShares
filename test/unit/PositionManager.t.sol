// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { PositionManager } from "../../src/PositionManager.sol";
import { PositionManagerEvents } from "../mocks/PositionManagerEvents.sol";
import { IVaultRegistry } from "../../src/interfaces/IVaultRegistry.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Errors } from "../../src/libraries/Errors.sol";
import { KeyManager } from "../../src/libraries/KeyManager.sol";
import { MockVaultRegistry } from "../mocks/MockVaultRegistry.sol";
import { BaseTest } from "../helpers/BaseTest.sol";
import { console2 } from "forge-std/Test.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract PositionManagerTest is BaseTest, PositionManagerEvents {
    PositionManager public positionManager;
    MockVaultRegistry public vaultRegistry;

    function setUp() public {
        super._setUp("BASE", 29200000);
        vm.startPrank(users.admin);

        // Deploy contracts
        vaultRegistry = new MockVaultRegistry();
        positionManager = new PositionManager(address(vaultRegistry));

        // Set up vault and handler
        vaultRegistry.updateVaultStatus(destinationChain, users.vault, true);
        vaultRegistry.updateVaultStatus(destinationChain + 1, users.vault, true);
        positionManager.configureHandler(users.handler, true);

        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(address(positionManager.vaultRegistry()), address(vaultRegistry));
        assertTrue(positionManager.hasAnyRole(users.admin, positionManager.ADMIN_ROLE()));
        assertTrue(positionManager.hasAnyRole(address(positionManager), positionManager.HANDLER_ROLE()));
    }

    function test_CreatePosition() public {
        vm.startPrank(users.handler);

        bytes32 expectedKey = KeyManager.getPositionKey(users.user, sourceChain, destinationChain, users.vault);

        vm.expectEmit(true, true, true, true);
        emit PositionCreated(users.user, sourceChain, destinationChain, users.vault, initialShares);

        bytes32 positionKey = positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        assertEq(positionKey, expectedKey);

        DataTypes.Position memory position = positionManager.getPosition(positionKey);
        assertEq(position.owner, users.user);
        assertEq(position.sourceChain, sourceChain);
        assertEq(position.destinationChain, destinationChain);
        assertEq(position.destinationVault, users.vault);
        assertEq(position.shares, initialShares);
        assertTrue(position.active);

        vm.stopPrank();
    }

    function test_UpdatePosition() public {
        vm.startPrank(users.handler);

        // Create position first
        bytes32 positionKey = positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        uint256 newShares = 2000;

        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(positionKey, newShares, block.timestamp);

        positionManager.updatePosition(positionKey, newShares);

        DataTypes.Position memory position = positionManager.getPosition(positionKey);
        assertEq(position.shares, newShares);

        vm.stopPrank();
    }

    function test_ClosePosition() public {
        vm.startPrank(users.handler);

        // Create position first
        bytes32 positionKey = positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        vm.expectEmit(true, true, true, true);
        emit PositionClosed(positionKey);

        positionManager.closePosition(positionKey);

        DataTypes.Position memory position = positionManager.getPosition(positionKey);
        assertFalse(position.active);
        assertEq(position.shares, 0);

        vm.stopPrank();
    }

    function test_GetUserPositions() public {
        vm.startPrank(users.handler);

        // Create multiple positions
        bytes32 positionKey1 = positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        bytes32 positionKey2 =
            positionManager.createPosition(users.user, sourceChain, destinationChain + 1, users.vault, initialShares);

        bytes32[] memory positions = positionManager.getUserPositions(users.user);
        assertEq(positions.length, 2);
        assertEq(positions[0], positionKey1);
        assertEq(positions[1], positionKey2);

        vm.stopPrank();
    }

    function test_RevertWhen_NonHandlerCreatesPosition() public {
        vm.startPrank(users.user);

        vm.expectRevert(Ownable.Unauthorized.selector);
        positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        vm.stopPrank();
    }

    function test_RevertWhen_VaultNotActive() public {
        vm.startPrank(users.handler);

        address inactiveVault = makeAddr("inactiveVault");

        vm.expectRevert(Errors.VaultNotActive.selector);
        positionManager.createPosition(users.user, sourceChain, destinationChain, inactiveVault, initialShares);

        vm.stopPrank();
    }

    function test_RevertWhen_PositionAlreadyExists() public {
        vm.startPrank(users.handler);

        // Create first position
        positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        // Try to create same position again
        vm.expectRevert(Errors.PositionExists.selector);
        positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        vm.stopPrank();
    }

    function test_RevertWhen_UpdatingNonExistentPosition() public {
        vm.startPrank(users.handler);

        bytes32 nonExistentKey = bytes32(uint256(1));

        vm.expectRevert(Errors.PositionNotFound.selector);
        positionManager.updatePosition(nonExistentKey, initialShares);

        vm.stopPrank();
    }

    function test_RevertWhen_ClosingNonExistentPosition() public {
        vm.startPrank(users.handler);

        bytes32 nonExistentKey = bytes32(uint256(1));

        vm.expectRevert(Errors.PositionNotFound.selector);
        positionManager.closePosition(nonExistentKey);

        vm.stopPrank();
    }

    function test_ConfigureHandler() public {
        vm.startPrank(users.admin);

        address newHandler = makeAddr("newHandler");

        vm.expectEmit(true, true, true, true);
        emit HandlerConfigured(newHandler, true);

        positionManager.configureHandler(newHandler, true);
        assertTrue(positionManager.isHandler(newHandler));

        vm.expectEmit(true, true, true, true);
        emit HandlerConfigured(newHandler, false);

        positionManager.configureHandler(newHandler, false);
        assertFalse(positionManager.isHandler(newHandler));

        vm.stopPrank();
    }

    function test_RevertWhen_NonAdminConfiguresHandler() public {
        vm.startPrank(users.user);

        address newHandler = makeAddr("newHandler");

        vm.expectRevert(); // Will revert with OwnableRoles error
        positionManager.configureHandler(newHandler, true);

        vm.stopPrank();
    }

    function test_IsPositionActive() public {
        vm.startPrank(users.handler);

        // Create position
        bytes32 positionKey = positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        assertTrue(positionManager.isPositionActive(positionKey));

        // Close position
        positionManager.closePosition(positionKey);
        assertFalse(positionManager.isPositionActive(positionKey));

        vm.stopPrank();
    }

    function test_GetUserPositionCount() public {
        vm.startPrank(users.handler);

        assertEq(positionManager.getUserPositionCount(users.user), 0);

        // Create positions
        positionManager.createPosition(users.user, sourceChain, destinationChain, users.vault, initialShares);

        assertEq(positionManager.getUserPositionCount(users.user), 1);

        positionManager.createPosition(users.user, sourceChain, destinationChain + 1, users.vault, initialShares);

        assertEq(positionManager.getUserPositionCount(users.user), 2);

        vm.stopPrank();
    }

    function test_GetPositionKey() public {
        bytes32 expectedKey = KeyManager.getPositionKey(users.user, sourceChain, destinationChain, users.vault);
        bytes32 actualKey = positionManager.getPositionKey(users.user, sourceChain, destinationChain, users.vault);
        assertEq(actualKey, expectedKey);
    }

    function test_RevertWhen_ZeroAddressUser() public {
        vm.startPrank(users.handler);

        vm.expectRevert(Errors.ZeroAddress.selector);
        positionManager.createPosition(address(0), sourceChain, destinationChain, users.vault, initialShares);

        vm.stopPrank();
    }

    function test_RevertWhen_ZeroAddressVault() public {
        vm.startPrank(users.handler);

        vm.expectRevert(Errors.ZeroAddress.selector);
        positionManager.createPosition(users.user, sourceChain, destinationChain, address(0), initialShares);

        vm.stopPrank();
    }

    function test_RevertWhen_InvalidChainId() public {
        vm.startPrank(users.handler);

        vm.expectRevert(Errors.ZeroChainId.selector);
        positionManager.createPosition(users.user, 0, destinationChain, users.vault, initialShares);

        vm.expectRevert(Errors.ZeroChainId.selector);
        positionManager.createPosition(users.user, sourceChain, 0, users.vault, initialShares);

        vm.stopPrank();
    }

    function test_RevertWhen_ZeroAddressHandler() public {
        vm.startPrank(users.admin);

        vm.expectRevert(Errors.ZeroAddress.selector);
        positionManager.configureHandler(address(0), true);

        vm.stopPrank();
    }
}
