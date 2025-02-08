// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "./base/BaseTest.t.sol";
import {DataTypes} from "../src/types/DataTypes.sol";
import {KeyManager} from "../src/libs/KeyManager.sol";
import {VaultRegistry} from "../src/VaultRegistry.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";

contract VaultRegistryTest is BaseTest {
    uint256 constant INITIAL_SHARES = 1000e6;
    uint256 constant UPDATED_SHARES = 2000e6;

    VaultRegistry registry;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        registry = new VaultRegistry();
        registry.grantRole(registry.ADMIN_ROLE(), admin);
        vm.stopPrank();
    }

    function test_InitialState() public {
        assertFalse(registry.paused());
    }

    function test_RegisterVault() public {
        vm.startPrank(admin);
        emit VaultRegistered(OPTIMISM_CHAIN, address(optimismVault), true);
        registry.registerVault(OPTIMISM_CHAIN, address(optimismVault));
        vm.stopPrank();
    }

    function test_UpdateVaultStatus() public {
        vm.startPrank(admin);

        // First register the vault
        registry.registerVault(OPTIMISM_CHAIN, address(optimismVault));

        // Then update its status
        emit VaultUpdated(OPTIMISM_CHAIN, address(optimismVault), false);
        registry.updateVaultStatus(OPTIMISM_CHAIN, address(optimismVault), false);

        // Verify the update
        assertFalse(registry.isVaultActive(OPTIMISM_CHAIN, address(optimismVault)));

        vm.stopPrank();
    }

    function test_RevertWhen_RegisterZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert("Zero address");
        registry.registerVault(OPTIMISM_CHAIN, address(0));

        vm.stopPrank();
    }

    function test_RevertWhen_RegisterZeroChainId() public {
        vm.startPrank(admin);

        vm.expectRevert("Zero chain ID");
        registry.registerVault(0, address(optimismVault));

        vm.stopPrank();
    }

    function test_RevertWhen_RegisterInvalidVault() public {
        vm.startPrank(admin);

        address invalidVault = makeAddr("invalidVault");

        vm.expectRevert("Invalid vault");
        registry.registerVault(OPTIMISM_CHAIN, invalidVault);

        vm.stopPrank();
    }

    function test_DeactivateAndRemoveVault() public {
        vm.startPrank(admin);

        // First register the vault
        registry.registerVault(OPTIMISM_CHAIN, address(optimismVault));

        // Then deactivate it
        emit VaultUpdated(OPTIMISM_CHAIN, address(optimismVault), false);
        registry.updateVaultStatus(OPTIMISM_CHAIN, address(optimismVault), false);

        // Verify deactivation
        assertFalse(registry.isVaultActive(OPTIMISM_CHAIN, address(optimismVault)));

        // Finally remove it
        emit VaultRemoved(OPTIMISM_CHAIN, address(optimismVault));
        registry.removeVault(OPTIMISM_CHAIN, address(optimismVault));

        vm.stopPrank();
    }

    function test_RemoveInactiveVault() public {
        vm.startPrank(admin);

        // First register and deactivate the vault
        registry.registerVault(OPTIMISM_CHAIN, address(optimismVault));
        registry.updateVaultStatus(OPTIMISM_CHAIN, address(optimismVault), false);

        // Then remove it
        emit VaultRemoved(OPTIMISM_CHAIN, address(optimismVault));
        registry.removeVault(OPTIMISM_CHAIN, address(optimismVault));

        // Verify removal
        DataTypes.VaultInfo memory info = registry.getVaultInfo(OPTIMISM_CHAIN, address(optimismVault));
        assertFalse(info.active);
        assertEq(info.shares, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedAccess() public {
        vm.startPrank(user);

        vm.expectRevert("AccessControl: account 0x2e234dae75c793f67a35089c9d99245e1c58470b is missing role 0x0000000000000000000000000000000000000000000000000000000000000000");
        registry.registerVault(OPTIMISM_CHAIN, address(optimismVault));

        vm.expectRevert("AccessControl: account 0x2e234dae75c793f67a35089c9d99245e1c58470b is missing role 0x0000000000000000000000000000000000000000000000000000000000000000");
        registry.updateVaultStatus(OPTIMISM_CHAIN, address(optimismVault), false);

        vm.expectRevert("AccessControl: account 0x2e234dae75c793f67a35089c9d99245e1c58470b is missing role 0x0000000000000000000000000000000000000000000000000000000000000000");
        registry.removeVault(OPTIMISM_CHAIN, address(optimismVault));

        vm.stopPrank();
    }

    function test_RevertWhen_NonexistentVault() public {
        vm.startPrank(admin);

        address nonexistentVault = makeAddr("nonexistentVault");
        bytes32 vaultKey = KeyManager.getVaultKey(OPTIMISM_CHAIN, nonexistentVault);

        vm.expectRevert("Vault not found");
        registry.updateVaultStatus(OPTIMISM_CHAIN, nonexistentVault, false);

        vm.expectRevert("Vault not found");
        registry.removeVault(OPTIMISM_CHAIN, nonexistentVault);

        vm.stopPrank();
    }

    function test_RevertWhen_UpdateZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert("Zero address");
        registry.updateVaultStatus(OPTIMISM_CHAIN, address(0x123), false);

        vm.stopPrank();
    }

    function test_UpdateVaultShares() public {
        vm.startPrank(admin);

        // First register the vault
        registry.registerVault(OPTIMISM_CHAIN, address(optimismVault));

        // Update shares
        emit SharesUpdated(OPTIMISM_CHAIN, address(optimismVault), INITIAL_SHARES);
        registry.updateVaultShares(OPTIMISM_CHAIN, address(optimismVault), INITIAL_SHARES);

        // Verify update
        DataTypes.VaultInfo memory info = registry.getVaultInfo(OPTIMISM_CHAIN, address(optimismVault));
        assertEq(info.shares, INITIAL_SHARES);

        // Update shares again
        emit SharesUpdated(OPTIMISM_CHAIN, address(optimismVault), UPDATED_SHARES);
        registry.updateVaultShares(OPTIMISM_CHAIN, address(optimismVault), UPDATED_SHARES);

        // Verify second update
        info = registry.getVaultInfo(OPTIMISM_CHAIN, address(optimismVault));
        assertEq(info.shares, UPDATED_SHARES);

        vm.stopPrank();
    }

    function test_RevertWhen_UpdateSharesNonexistentVault() public {
        vm.startPrank(admin);

        address nonexistentVault = makeAddr("nonexistentVault");

        vm.expectRevert("Vault not found");
        registry.updateVaultShares(OPTIMISM_CHAIN, nonexistentVault, INITIAL_SHARES);

        vm.stopPrank();
    }

    function test_RevertWhen_UpdateSharesPaused() public {
        vm.startPrank(admin);

        // First register the vault
        registry.registerVault(OPTIMISM_CHAIN, address(optimismVault));

        // Pause the registry
        registry.pause();

        // Try to update shares while paused
        vm.expectRevert("Pausable: paused");
        registry.updateVaultShares(OPTIMISM_CHAIN, address(optimismVault), INITIAL_SHARES);

        vm.stopPrank();
    }

    event VaultRegistered(uint256 indexed chainId, address indexed vault, bool active);
    event VaultUpdated(uint256 indexed chainId, address indexed vault, bool active);
    event VaultRemoved(uint256 indexed chainId, address indexed vault);
    event SharesUpdated(uint256 indexed chainId, address indexed vault, uint256 shares);
}
