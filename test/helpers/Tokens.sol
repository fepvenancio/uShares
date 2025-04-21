// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

uint256 constant _1_USDC = 1e6;
uint256 constant _1_WETH = 1e18;

address constant WETH_OPTIMISM = 0x4200000000000000000000000000000000000006;
address constant USDC_OPTIMISM = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
address constant WETH_BASE = 0x4200000000000000000000000000000000000006;
address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

function getTokensList(string memory chain) pure returns (address[] memory) {
    if (keccak256(abi.encodePacked(chain)) == keccak256(abi.encodePacked("OPTIMISM"))) {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH_OPTIMISM;
        tokens[1] = USDC_OPTIMISM;
        return tokens;
    } else if (keccak256(abi.encodePacked(chain)) == keccak256(abi.encodePacked("BASE"))) {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH_BASE;
        tokens[1] = USDC_BASE;
        return tokens;
    } else {
        revert("InvalidChain");
    }
}
