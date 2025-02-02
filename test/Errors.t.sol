// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/libs/Errors.sol";

contract ErrorsTest is Test {
    // Helper function to explicitly call the address version
    function verifyAddress(address addr) internal pure {
        Errors.verifyNotZero(addr);
    }

    // Helper function to explicitly call the bytes32 version
    function verifyBytes32(bytes32 key) internal pure {
        Errors.verifyNotZero(key);
    }

    // Helper function to explicitly call the uint256 version
    function verifyUint256(uint256 num) internal pure {
        Errors.verifyNotZero(num);
    }

    function test_VerifyNotZeroAddress() public {
        // Should not revert
        verifyAddress(address(0x123));

        // Should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        verifyAddress(address(0));
    }

    function test_VerifyNotZeroBytes() public {
        bytes32 validKey = bytes32(uint256(1));

        // Should not revert
        verifyBytes32(validKey);

        // Should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroBytes.selector, bytes32(0)));
        verifyBytes32(bytes32(0));
    }

    function test_VerifyNotZeroNumber() public {
        // Should not revert
        verifyUint256(1);

        // Should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroNumber.selector, 0));
        verifyUint256(0);
    }

    function testFuzz_VerifyNotZeroAddress(address addr) public {
        if (addr == address(0)) {
            vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
            verifyAddress(addr);
        } else {
            verifyAddress(addr);
        }
    }

    function testFuzz_VerifyNotZeroNumber(uint256 num) public {
        if (num == 0) {
            vm.expectRevert(abi.encodeWithSelector(Errors.ZeroNumber.selector, 0));
            verifyUint256(num);
        } else {
            verifyUint256(num);
        }
    }
}
