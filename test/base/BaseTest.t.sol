// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {VaultRegistry} from "../../src/VaultRegistry.sol";
import {PositionManager} from "../../src/PositionManager.sol";
import {IVaultRegistry} from "../../src/interfaces/IVaultRegistry.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockVault} from "../mocks/MockVault.sol";

abstract contract BaseTest is Test {
    // Test accounts
    address deployer = makeAddr("deployer");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address vaultOwner = makeAddr("vaultOwner");
    address handler = makeAddr("handler");

    // Test constants
    uint32 constant SOURCE_CHAIN = 1; // Ethereum
    uint32 constant DEST_CHAIN = 8453; // Base
    uint256 constant INITIAL_BALANCE = 1000000e6; // 1M USDC

    // Contracts
    MockUSDC public usdc;
    MockVault internal vault;
    VaultRegistry internal registry;
    PositionManager public positions;

    function setUp() public virtual {
        vm.startPrank(deployer);

        // Deploy mock contracts for external dependencies
        usdc = new MockUSDC();
        vault = new MockVault(usdc);

        // Deploy real contracts we're testing
        registry = new VaultRegistry(address(usdc));
        positions = new PositionManager(address(registry));

        // Configure test handler
        positions.configureHandler(handler, true);

        // Setup test balances
        usdc.mint(user1, INITIAL_BALANCE);
        usdc.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();
    }

    function _registerVault() internal {
        vm.startPrank(deployer);
        // Register vault in registry
        registry.registerVault(DEST_CHAIN, address(vault));
        vm.stopPrank();
    }
}
