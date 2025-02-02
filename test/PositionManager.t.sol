// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./base/BaseTest.t.sol";
import {Errors} from "../src/libs/Errors.sol";
import {KeyManager} from "../src/libs/KeyManager.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";

contract PositionManagerTest is BaseTest {
    event PositionCreated(
        address indexed user,
        uint32 indexed sourceChain,
        uint32 indexed destinationChain,
        address destinationVault,
        uint256 shares
    );
    event PositionUpdated(
        bytes32 indexed positionKey,
        uint256 newShares,
        uint256 timestamp
    );
    event PositionClosed(bytes32 indexed positionKey);

    function setUp() public override {
        super.setUp();
        _registerVault();
    }

    function test_CreatePosition() public {
        vm.startPrank(handler);

        uint256 shares = 1000e6;

        vm.expectEmit(true, true, true, true);
        emit PositionCreated(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            shares
        );

        bytes32 positionKey = positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            shares
        );

        // Get position directly from mapping
        IPositionManager.Position memory pos = positions.getPosition(positionKey);

        // Verify position
        assertEq(pos.owner, user1);
        assertEq(pos.sourceChain, SOURCE_CHAIN);
        assertEq(pos.destinationChain, DEST_CHAIN);
        assertEq(pos.shares, shares);
        assertTrue(pos.active);
        assertEq(pos.destinationVault, address(vault));

        vm.stopPrank();
    }

    function test_UpdatePosition() public {
        vm.startPrank(handler);

        // Create position
        uint256 initialShares = 1000e6;
        bytes32 positionKey = positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            initialShares
        );

        // Update shares
        uint256 newShares = 2000e6;
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(
            positionKey,
            newShares,
            block.timestamp
        );

        positions.updatePosition(positionKey, newShares);

        // Verify update
        IPositionManager.Position memory pos = positions.getPosition(positionKey);
        assertEq(pos.shares, newShares);

        vm.stopPrank();
    }

    function test_ClosePosition() public {
        vm.startPrank(handler);

        // Create position
        bytes32 positionKey = positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );

        // Close position
        vm.expectEmit(true, true, true, true);
        emit PositionClosed(positionKey);

        positions.closePosition(positionKey);

        // Verify closure
        IPositionManager.Position memory pos = positions.getPosition(positionKey);
        assertFalse(pos.active);
        assertFalse(positions.isPositionActive(positionKey));

        vm.stopPrank();
    }

    function test_RevertCreatePosition_NonHandler() public {
        vm.prank(user1);
        vm.expectRevert(Errors.NotHandler.selector);
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
    }

    function test_RevertCreatePosition_VaultNotActive() public {
        vm.startPrank(handler);
        
        // Try to create position with unregistered vault
        address unregisteredVault = address(new MockVault(usdc));
        
        vm.expectRevert(Errors.VaultNotActive.selector);
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            unregisteredVault,
            1000e6
        );

        vm.stopPrank();
    }

    function testFuzz_CreateMultiplePositions(
        uint96 amount1,
        uint96 amount2
    ) public {
        vm.assume(amount1 > 0);
        vm.assume(amount2 > 0);

        vm.startPrank(handler);

        // Create positions for different users
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            amount1
        );

        positions.createPosition(
            user2,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            amount2
        );

        // Verify positions
        bytes32 key1 = KeyManager.getPositionKey(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault)
        );
        bytes32 key2 = KeyManager.getPositionKey(
            user2,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault)
        );

        IPositionManager.Position memory pos1 = positions.getPosition(key1);
        IPositionManager.Position memory pos2 = positions.getPosition(key2);

        assertEq(pos1.shares, amount1);
        assertEq(pos2.shares, amount2);

        vm.stopPrank();
    }

    function test_RevertCreatePosition_ZeroAddress() public {
        vm.startPrank(handler);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0))
        );
        positions.createPosition(
            address(0),
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        vm.stopPrank();
    }

    function test_RevertCreatePosition_ZeroSourceChain() public {
        vm.startPrank(handler);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroNumber.selector, 0));
        positions.createPosition(user1, 0, DEST_CHAIN, address(vault), 1000e6);
        vm.stopPrank();
    }

    function test_RevertCreatePosition_ZeroDestChain() public {
        vm.startPrank(handler);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroNumber.selector, 0));
        positions.createPosition(user1, SOURCE_CHAIN, 0, address(vault), 1000e6);
        vm.stopPrank();
    }

    function test_GetUserPositions() public {
        vm.startPrank(handler);
        
        // Create positions
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        
        // Get positions
        bytes32[] memory userPositions = positions.getUserPositions(user1);
        assertEq(userPositions.length, 1);
        
        vm.stopPrank();
    }

    function test_GetChainPositions() public {
        vm.startPrank(handler);
        
        // Create positions
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        
        // Get positions
        bytes32[] memory chainPositions = positions.getChainPositions(SOURCE_CHAIN);
        assertEq(chainPositions.length, 1);
        
        vm.stopPrank();
    }

    function test_GetUserPositionCount() public {
        vm.startPrank(handler);
        
        // Create positions
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        
        // Get count
        uint256 count = positions.getUserPositionCount(user1);
        assertEq(count, 1);
        
        vm.stopPrank();
    }

    function test_GetChainPositionCount() public {
        vm.startPrank(handler);
        
        // Create positions
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        
        // Get count
        uint256 count = positions.getChainPositionCount(SOURCE_CHAIN);
        assertEq(count, 1);
        
        vm.stopPrank();
    }

    function test_RevertCreatePosition_ExistingActivePosition() public {
        vm.startPrank(handler);
        
        // Create first position
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        
        // Try to create same position again
        vm.expectRevert(Errors.PositionExists.selector);
        positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        
        vm.stopPrank();
    }

    function test_RevertUpdatePosition_NonOwner() public {
        vm.startPrank(handler);
        
        // Create position
        bytes32 positionKey = positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        
        // Try to update from different handler
        vm.stopPrank();
        vm.startPrank(user2);
        vm.expectRevert(Errors.NotHandler.selector);
        positions.updatePosition(positionKey, 2000e6);
        
        vm.stopPrank();
    }

    function test_UpdateClosedPosition() public {
        vm.startPrank(handler);
        
        // Create and close position
        bytes32 positionKey = positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        positions.closePosition(positionKey);
        
        // Try to update closed position
        vm.expectRevert(Errors.PositionNotFound.selector);
        positions.updatePosition(positionKey, 2000e6);
        
        vm.stopPrank();
    }

    function test_CloseClosedPosition() public {
        vm.startPrank(handler);
        
        // Create and close position
        bytes32 positionKey = positions.createPosition(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            1000e6
        );
        positions.closePosition(positionKey);
        
        // Try to close again
        vm.expectRevert(Errors.PositionNotFound.selector);
        positions.closePosition(positionKey);
        
        vm.stopPrank();
    }
}
