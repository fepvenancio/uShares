// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/libs/KeyManager.sol";

contract KeyManagerTest is Test {
    address constant USER = address(0x123);
    uint32 constant CHAIN_ID = 1;
    address constant VAULT = address(0x456);
    uint32 constant DEST_CHAIN = 2;

    function test_GetPositionKey() public {
        bytes32 key = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, VAULT);
        assertTrue(key != bytes32(0));
    }

    function test_GetPositionKey_Deterministic() public {
        bytes32 key1 = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, VAULT);
        bytes32 key2 = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, VAULT);
        assertEq(key1, key2);
    }

    function test_GetVaultKey() public {
        bytes32 key = KeyManager.getVaultKey(CHAIN_ID, VAULT);
        assertTrue(key != bytes32(0));
    }

    function test_GetVaultKey_Deterministic() public {
        bytes32 key1 = KeyManager.getVaultKey(CHAIN_ID, VAULT);
        bytes32 key2 = KeyManager.getVaultKey(CHAIN_ID, VAULT);
        assertEq(key1, key2);
    }

    function test_RevertGetPositionKey_ZeroAddress() public {
        vm.expectRevert(KeyManager.InvalidAddress.selector);
        KeyManager.getPositionKey(address(0), CHAIN_ID, DEST_CHAIN, VAULT);
    }

    function test_RevertGetPositionKey_ZeroChainId() public {
        vm.expectRevert(KeyManager.InvalidChainId.selector);
        KeyManager.getPositionKey(USER, 0, DEST_CHAIN, VAULT);
    }

    function test_RevertGetVaultKey_ZeroChainId() public {
        vm.expectRevert(KeyManager.InvalidChainId.selector);
        KeyManager.getVaultKey(0, VAULT);
    }

    function test_ValidatePositionKey() public {
        bytes32 key = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, VAULT);
        assertTrue(KeyManager.isValidPositionKey(key));
        assertFalse(KeyManager.isValidPositionKey(bytes32(0)));
    }

    function test_ValidateVaultKey() public {
        bytes32 key = KeyManager.getVaultKey(CHAIN_ID, VAULT);
        assertTrue(KeyManager.isValidVaultKey(key));
        assertFalse(KeyManager.isValidVaultKey(bytes32(0)));
    }

    function testFuzz_GetPositionKey(
        address user,
        uint32 chainId,
        address vault
    ) public {
        vm.assume(user != address(0));
        vm.assume(chainId != 0);
        vm.assume(vault != address(0));
        
        bytes32 key = KeyManager.getPositionKey(user, chainId, DEST_CHAIN, vault);
        assertTrue(KeyManager.isValidPositionKey(key));
    }

    function testFuzz_GetVaultKey(
        uint32 chainId,
        address vault
    ) public {
        vm.assume(chainId != 0);
        vm.assume(vault != address(0));
        
        bytes32 key = KeyManager.getVaultKey(chainId, vault);
        assertTrue(KeyManager.isValidVaultKey(key));
    }

    function test_GetPositionKey_DifferentUsers() public {
        bytes32 key1 = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, VAULT);
        bytes32 key2 = KeyManager.getPositionKey(address(0x789), CHAIN_ID, DEST_CHAIN, VAULT);
        assertTrue(key1 != key2);
    }

    function test_GetPositionKey_DifferentChains() public {
        bytes32 key1 = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, VAULT);
        bytes32 key2 = KeyManager.getPositionKey(USER, CHAIN_ID + 1, DEST_CHAIN, VAULT);
        assertTrue(key1 != key2);
    }

    function test_GetPositionKey_DifferentVaults() public {
        bytes32 key1 = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, VAULT);
        bytes32 key2 = KeyManager.getPositionKey(USER, CHAIN_ID, DEST_CHAIN, address(0x789));
        assertTrue(key1 != key2);
    }
}
