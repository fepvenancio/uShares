// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";

contract MockVault is ERC4626 {
    ERC20 private immutable _asset;

    constructor(ERC20 asset_) {
        _asset = asset_;
    }

    function name() public pure override returns (string memory) {
        return "Mock Vault";
    }

    function symbol() public pure override returns (string memory) {
        return "vUSDC";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function asset() public view override returns (address) {
        return address(_asset);
    }

    function totalAssets() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    // Override previewDeposit to return a predictable amount
    function previewDeposit(uint256 assets) public pure override returns (uint256) {
        return assets; // 1:1 ratio for testing
    }
}
