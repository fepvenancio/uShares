// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import { IERC20Metadata } from "../../src/interfaces/IERC20Metadata.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Vm } from "forge-std/Vm.sol";

contract Utils is StdCheats {
    address constant HEVM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    /// @dev Generates an address by hashing the name, labels the address and funds it with test assets.
    function createUser(string memory name, address[] calldata tokens) external returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.deal({ account: addr, newBalance: 1000 ether });
        for (uint256 i; i < tokens.length;) {
            deal({ token: tokens[i], to: addr, give: 2000 * 10 ** IERC20Metadata(tokens[i]).decimals() });
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Moves block.number forward by a given number of blocks
    function mineBlocks(uint256 numBlocks) external {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }
}