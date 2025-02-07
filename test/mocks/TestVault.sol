// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract TestVault is ERC4626, IVault {
    using SafeTransferLib for address;

    address private immutable _asset;
    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;

    constructor(
        address asset_,
        string memory name_,
        string memory symbol_
    ) {
        _asset = asset_;
        _name = name_;
        _symbol = symbol_;
        _decimals = ERC20(asset_).decimals();
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function asset() public view override(ERC4626, IVault) returns (address) {
        return _asset;
    }

    function totalAssets() public view override(ERC4626, IVault) returns (uint256) {
        return ERC20(_asset).balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view override(ERC4626, IVault) returns (uint256) {
        return assets; // 1:1 conversion for testing
    }

    function convertToAssets(uint256 shares) public view override(ERC4626, IVault) returns (uint256) {
        return shares; // 1:1 conversion for testing
    }

    function deposit(uint256 assets, address receiver) public override(ERC4626, IVault) returns (uint256 shares) {
        // Transfer tokens from sender
        _asset.safeTransferFrom(msg.sender, address(this), assets);
        
        // Mint shares 1:1 for testing
        shares = assets;
        _mint(receiver, shares);
        
        return shares;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override(ERC4626, IVault) returns (uint256 shares) {
        shares = assets; // 1:1 conversion for testing
        
        // Burn shares
        _burn(owner, shares);
        
        // Transfer tokens to receiver
        _asset.safeTransfer(receiver, assets);
        
        return shares;
    }
} 