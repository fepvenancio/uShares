// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./base/BaseTest.t.sol";
import {DataTypes} from "../src/types/DataTypes.sol";
import {Errors} from "../src/libs/Errors.sol";
import {KeyManager} from "../src/libs/KeyManager.sol";
import {IVaultRegistry} from "../src/interfaces/IVaultRegistry.sol";

contract VaultRegistryTest is BaseTest {
    event VaultRegistered(uint32 indexed chainId, address indexed vault, bool active);
    event VaultUpdated(uint32 indexed chainId, address indexed vault, bool active);
    event VaultRemoved(uint32 indexed chainId, address indexed vault);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public virtual override {
        super.setUp();
        // Verify contract not paused
        assertFalse(registry.paused());

        // Register initial vault
        vm.startPrank(deployer);
        emit VaultRegistered(DEST_CHAIN, address(vault), true);

        registry.registerVault(DEST_CHAIN, address(vault));

        // Verify registration
        bytes32 vaultKey = KeyManager.getVaultKey(DEST_CHAIN, address(vault));
        DataTypes.VaultInfo memory vaultInfo = registry.getVaultInfo(DEST_CHAIN, address(vault));

        assertTrue(vaultInfo.active);
        assertEq(vaultInfo.vaultAddress, address(vault));
        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(address(registry.usdc()), address(usdc));
    }

    function test_UpdateVaultStatus() public {
        vm.startPrank(deployer);

        // Update vault status to inactive
        emit VaultUpdated(DEST_CHAIN, address(vault), false);
        registry.updateVaultStatus(DEST_CHAIN, address(vault), false);

        assertFalse(registry.isVaultActive(DEST_CHAIN, address(vault)));
        vm.stopPrank();
    }

    function test_RevertRegisterVault_ZeroAddress() public {
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        registry.registerVault(DEST_CHAIN, address(0));
        vm.stopPrank();
    }

    function test_RevertRegisterVault_ZeroChainId() public {
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroNumber.selector, 0));
        registry.registerVault(0, address(vault));
        vm.stopPrank();
    }

    function test_RevertRegisterVault_InvalidVault() public {
        vm.startPrank(deployer);

        // Deploy an invalid vault (not ERC4626 compliant)
        MockVault invalidVault = new MockVault(ERC20(address(0))); // Invalid asset address

        // Try to register invalid vault
        vm.expectRevert(Errors.InvalidAsset.selector);
        registry.registerVault(DEST_CHAIN, address(invalidVault));
        vm.stopPrank();
    }

    function test_DeactivateVault() public {
        vm.startPrank(deployer);

        // Deactivate vault (no need to register again since it's done in setUp)
        emit VaultUpdated(DEST_CHAIN, address(vault), false);
        registry.updateVaultStatus(DEST_CHAIN, address(vault), false);

        // Verify deactivation
        assertFalse(registry.isVaultActive(DEST_CHAIN, address(vault)));
        vm.stopPrank();
    }

    function test_RevertRemoveActiveVault() public {
        vm.startPrank(deployer);

        // Try to remove while active (vault is registered and active from setUp)
        vm.expectRevert(Errors.VaultActive.selector);
        registry.removeVault(DEST_CHAIN, address(vault));

        // Deactivate first
        registry.updateVaultStatus(DEST_CHAIN, address(vault), false);

        // Now removal should succeed
        emit VaultRemoved(DEST_CHAIN, address(vault));
        registry.removeVault(DEST_CHAIN, address(vault));

        vm.stopPrank();
    }

    function test_RemoveVault() public {
        vm.startPrank(deployer);

        // First deactivate the vault (since it's already registered in setUp)
        registry.updateVaultStatus(DEST_CHAIN, address(vault), false);

        // Remove vault
        emit VaultRemoved(DEST_CHAIN, address(vault));
        registry.removeVault(DEST_CHAIN, address(vault));

        // After removal, the vault info should be zero-initialized
        DataTypes.VaultInfo memory info = registry.getVaultInfo(DEST_CHAIN, address(vault));
        assertEq(info.vaultAddress, address(0));
        assertEq(info.chainId, 0);
        assertEq(info.totalShares, 0);
        assertEq(info.lastUpdate, 0);
        assertFalse(info.active);
        vm.stopPrank();
    }

    function test_RevertUnauthorizedOperations() public {
        vm.startPrank(user1);

        vm.expectRevert(Errors.Unauthorized.selector);
        registry.registerVault(DEST_CHAIN, address(vault));

        vm.expectRevert(Errors.Unauthorized.selector);
        registry.updateVaultStatus(DEST_CHAIN, address(vault), false);

        vm.expectRevert(Errors.Unauthorized.selector);
        registry.removeVault(DEST_CHAIN, address(vault));

        vm.stopPrank();
    }

    function test_RevertDuplicateRegistration() public {
        vm.startPrank(deployer);

        // Try to register the same vault again
        vm.expectRevert(Errors.VaultExists.selector);
        registry.registerVault(DEST_CHAIN, address(vault));

        vm.stopPrank();
    }

    function test_RevertOperationsOnNonexistentVault() public {
        vm.startPrank(deployer);

        // Try operations on a non-existent vault
        address nonexistentVault = address(0x123);
        bytes32 vaultKey = KeyManager.getVaultKey(DEST_CHAIN, nonexistentVault);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        registry.updateVaultStatus(DEST_CHAIN, nonexistentVault, false);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        registry.removeVault(DEST_CHAIN, nonexistentVault);

        vm.stopPrank();
    }

    function test_RevertUpdateNonExistentVault() public {
        vm.startPrank(deployer);

        // Try to update non-existent vault
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        registry.updateVaultStatus(DEST_CHAIN, address(0x123), false);
        vm.stopPrank();
    }
}
