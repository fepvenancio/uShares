// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "./base/BaseTest.t.sol";
import {DataTypes} from "../src/types/DataTypes.sol";
import {KeyManager} from "../src/libs/KeyManager.sol";
import {PositionManager} from "../src/PositionManager.sol";

contract PositionManagerTest is BaseTest {
    PositionManager positions;
    address handler = makeAddr("handler");

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        positions = new PositionManager();
        positions.grantRole(positions.HANDLER_ROLE(), handler);
        vm.stopPrank();
    }

    function test_CreatePosition() public {
        uint256 shares = 1000e6;

        vm.startPrank(handler);

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit PositionCreated(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), shares);

        // Create position
        bytes32 positionKey = positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), shares);

        // Verify position state
        DataTypes.Position memory pos = positions.getPosition(positionKey);

        // Check position fields
        assertEq(pos.owner, user);
        assertEq(pos.sourceChain, BASE_CHAIN);
        assertEq(pos.destinationChain, OPTIMISM_CHAIN);
        assertEq(pos.destinationVault, address(baseVault));
        assertEq(pos.shares, shares);
        assertTrue(pos.active);

        vm.stopPrank();
    }

    function test_UpdatePosition() public {
        uint256 initialShares = 1000e6;
        uint256 newShares = 2000e6;

        vm.startPrank(handler);

        // Create initial position
        bytes32 positionKey = positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), initialShares);

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(positionKey, newShares);

        // Update position
        positions.updatePosition(positionKey, newShares);

        // Verify position state
        DataTypes.Position memory pos = positions.getPosition(positionKey);
        assertEq(pos.shares, newShares);

        vm.stopPrank();
    }

    function test_ClosePosition() public {
        vm.startPrank(handler);

        // Create position
        bytes32 positionKey = positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit PositionClosed(positionKey);

        // Close position
        positions.closePosition(positionKey);

        // Verify position state
        DataTypes.Position memory pos = positions.getPosition(positionKey);
        assertFalse(pos.active);

        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedCreatePosition() public {
        vm.prank(user);

        vm.expectRevert(abi.encodeWithSelector(PositionManager.Unauthorized.selector));
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);
    }

    function test_RevertWhen_InvalidVault() public {
        vm.startPrank(handler);

        address unregisteredVault = makeAddr("unregisteredVault");

        vm.expectRevert("Invalid vault");
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, unregisteredVault, 1000e6);

        vm.stopPrank();
    }

    function test_GetUserPositions() public {
        uint256 amount1 = 1000e6;
        uint256 amount2 = 2000e6;

        vm.startPrank(handler);

        // Create positions
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), amount1);
        positions.createPosition(user, OPTIMISM_CHAIN, BASE_CHAIN, address(optimismVault), amount2);

        // Get user positions
        bytes32[] memory userPositions = positions.getUserPositions(user);

        // Verify positions
        assertEq(userPositions.length, 2);

        vm.stopPrank();
    }

    function test_GetChainPositions() public {
        vm.startPrank(handler);

        // Create position
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);

        // Get chain positions
        bytes32[] memory chainPositions = positions.getChainPositions(BASE_CHAIN);

        // Verify positions
        assertEq(chainPositions.length, 1);

        vm.stopPrank();
    }

    function test_GetUserPositionCount() public {
        vm.startPrank(handler);

        // Create position
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);

        // Get user position count
        uint256 count = positions.getUserPositionCount(user);

        // Verify count
        assertEq(count, 1);

        vm.stopPrank();
    }

    function test_GetChainPositionCount() public {
        vm.startPrank(handler);

        // Create position
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);

        // Get chain position count
        uint256 count = positions.getChainPositionCount(BASE_CHAIN);

        // Verify count
        assertEq(count, 1);

        vm.stopPrank();
    }

    function test_GetPositionKey() public {
        vm.startPrank(handler);

        // Create position
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);

        // Create another position with same parameters
        positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);

        // Verify that positions are unique
        assertEq(positions.getUserPositionCount(user), 2);

        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedUpdatePosition() public {
        vm.startPrank(handler);

        // Create position
        bytes32 positionKey = positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);

        vm.stopPrank();

        // Try to update position as unauthorized user
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(PositionManager.Unauthorized.selector));
        positions.updatePosition(positionKey, 2000e6);
    }

    function test_RevertWhen_UpdateInactivePosition() public {
        vm.startPrank(handler);

        // Create position
        bytes32 positionKey = positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);
        positions.closePosition(positionKey);

        // Try to update inactive position
        vm.expectRevert("Position not active");
        positions.updatePosition(positionKey, 2000e6);

        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedClosePosition() public {
        vm.startPrank(handler);

        // Create position
        bytes32 positionKey = positions.createPosition(user, BASE_CHAIN, OPTIMISM_CHAIN, address(baseVault), 1000e6);
        positions.closePosition(positionKey);

        // Try to close position again
        vm.expectRevert("Position not active");
        positions.closePosition(positionKey);

        vm.stopPrank();
    }

    event PositionCreated(address indexed owner, uint256 sourceChain, uint256 destinationChain, address destinationVault, uint256 shares);
    event PositionUpdated(bytes32 indexed positionKey, uint256 newShares);
    event PositionClosed(bytes32 indexed positionKey);
}
