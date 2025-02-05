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
    event SharesUpdated(uint32 indexed chainId, address indexed vault, uint256 totalShares);
    event SharePriceUpdated(uint32 indexed chainId, address indexed vault, uint256 sharePrice);
    event Paused(address account);
    event Unpaused(address account);

    uint96 constant INITIAL_SHARES = 1000e6;
    uint96 constant UPDATED_SHARES = 2000e6;
    uint256 constant SHARE_PRICE = 1e6; // 1:1 initial share price in USDC terms

    function setUp() public virtual override {
        super.setUp();
        // Verify contract not paused
        assertFalse(registry.paused());

        // Register initial vault
        vm.startPrank(deployer);
        emit VaultRegistered(DEST_CHAIN, address(vault), true);
        registry.registerVault(DEST_CHAIN, address(vault));
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
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroChainId.selector));
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

    // New tests for share tracking and validation
    function test_UpdateVaultShares() public {
        vm.startPrank(deployer);
        
        // Update shares
        emit SharesUpdated(DEST_CHAIN, address(vault), INITIAL_SHARES);
        registry.updateVaultShares(DEST_CHAIN, address(vault), INITIAL_SHARES);

        // Verify shares were updated
        DataTypes.VaultInfo memory info = registry.getVaultInfo(DEST_CHAIN, address(vault));
        assertEq(info.totalShares, INITIAL_SHARES);

        // Update shares again
        emit SharesUpdated(DEST_CHAIN, address(vault), UPDATED_SHARES);
        registry.updateVaultShares(DEST_CHAIN, address(vault), UPDATED_SHARES);

        // Verify shares were updated
        info = registry.getVaultInfo(DEST_CHAIN, address(vault));
        assertEq(info.totalShares, UPDATED_SHARES);

        vm.stopPrank();
    }

    function test_SharePriceValidation() public {
        vm.startPrank(deployer);

        // Register vault for the current chain first
        registry.registerVault(uint32(block.chainid), address(vault));

        // Mock initial share price
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(ERC4626.convertToAssets.selector, 1e6),
            abi.encode(SHARE_PRICE)
        );

        // First update should always succeed and set initial share price
        emit SharesUpdated(uint32(block.chainid), address(vault), INITIAL_SHARES);
        registry.updateVaultShares(uint32(block.chainid), address(vault), INITIAL_SHARES);

        // Clear previous mock
        vm.clearMockedCalls();

        // Simulate a share price change within threshold
        uint256 newPrice = SHARE_PRICE * 109 / 100; // 9% increase
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(ERC4626.convertToAssets.selector, 1e6),
            abi.encode(newPrice)
        );

        // Update should succeed
        registry.updateVaultShares(uint32(block.chainid), address(vault), UPDATED_SHARES);

        // Clear previous mock
        vm.clearMockedCalls();

        // Simulate a share price change above threshold (11% from the last price)
        newPrice = newPrice * 111 / 100; // 11% increase from last price
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(ERC4626.convertToAssets.selector, 1e6),
            abi.encode(newPrice)
        );

        // Update should revert with SuspiciousSharePriceChange
        vm.expectRevert(Errors.SuspiciousSharePriceChange.selector);
        registry.updateVaultShares(uint32(block.chainid), address(vault), UPDATED_SHARES);

        vm.stopPrank();
    }

    function test_ValidateVaultOperation() public {
        vm.startPrank(deployer);

        // Register vault for the current chain first
        registry.registerVault(uint32(block.chainid), address(vault));

        // Set up initial state
        registry.updateVaultShares(uint32(block.chainid), address(vault), INITIAL_SHARES);

        // Mock maxDeposit call
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(ERC4626.maxDeposit.selector, address(registry)),
            abi.encode(1000e6)
        );

        // Mock convertToAssets call to avoid share price validation issues
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(ERC4626.convertToAssets.selector, 1e6),
            abi.encode(SHARE_PRICE)
        );

        // Test valid operation
        bool isValid = registry.validateVaultOperation(uint32(block.chainid), address(vault), 500e6);
        assertTrue(isValid);

        // Test operation exceeding capacity
        isValid = registry.validateVaultOperation(uint32(block.chainid), address(vault), 1500e6);
        assertFalse(isValid);

        // Test inactive vault
        registry.updateVaultStatus(uint32(block.chainid), address(vault), false);
        isValid = registry.validateVaultOperation(uint32(block.chainid), address(vault), 100e6);
        assertFalse(isValid);

        vm.stopPrank();
    }

    function test_RevertUpdateSharesNonexistentVault() public {
        vm.startPrank(deployer);
        address nonexistentVault = address(0x123);
        
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        registry.updateVaultShares(DEST_CHAIN, nonexistentVault, INITIAL_SHARES);
        
        vm.stopPrank();
    }

    function test_RevertUpdateSharesPaused() public {
        vm.startPrank(deployer);
        
        // Pause the contract
        registry.pause();
        
        vm.expectRevert(Errors.Paused.selector);
        registry.updateVaultShares(DEST_CHAIN, address(vault), INITIAL_SHARES);
        
        vm.stopPrank();
    }

    function test_CrossChainVaultValidation() public {
        vm.startPrank(deployer);

        // Test validation for vault on different chain
        // Should only check basic validity, not share price
        bool isValid = registry.validateVaultOperation(DEST_CHAIN, address(vault), 1000e6);
        assertTrue(isValid);

        // Deactivate vault and verify validation fails
        registry.updateVaultStatus(DEST_CHAIN, address(vault), false);
        isValid = registry.validateVaultOperation(DEST_CHAIN, address(vault), 1000e6);
        assertFalse(isValid);

        vm.stopPrank();
    }
}
