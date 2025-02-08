// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title MockVault
 * @notice Mock ERC4626 vault for testing
 */
contract MockVault is ERC4626 {
    using SafeTransferLib for address;

    // The underlying token (USDC)
    address public immutable asset_;

    // Mock exchange rate (1:1)
    uint256 constant EXCHANGE_RATE = 1e6;

    constructor(address _asset) {
        asset_ = _asset;
    }

    function name() public pure override returns (string memory) {
        return "Mock Vault";
    }

    function symbol() public pure override returns (string memory) {
        return "mVault";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function asset() public view override returns (address) {
        return asset_;
    }

    function totalAssets() public view override returns (uint256) {
        return ERC20(asset_).balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public pure override returns (uint256) {
        return assets;  // 1:1 conversion for simplicity
    }

    function convertToAssets(uint256 shares) public pure override returns (uint256) {
        return shares;  // 1:1 conversion for simplicity
    }

    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        return balanceOf(owner);
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) public pure override returns (uint256) {
        return assets;  // 1:1 conversion
    }

    function previewMint(uint256 shares) public pure override returns (uint256) {
        return shares;  // 1:1 conversion
    }

    function previewWithdraw(uint256 assets) public pure override returns (uint256) {
        return assets;  // 1:1 conversion
    }

    function previewRedeem(uint256 shares) public pure override returns (uint256) {
        return shares;  // 1:1 conversion
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        // Transfer assets from sender
        asset_.safeTransferFrom(msg.sender, address(this), assets);

        // Mint shares to receiver
        _mint(receiver, assets);

        return assets;
    }

    function mint(uint256 shares, address receiver) public override returns (uint256) {
        // Transfer assets from sender
        asset_.safeTransferFrom(msg.sender, address(this), shares);

        // Mint shares to receiver
        _mint(receiver, shares);

        return shares;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256) {
        // Burn shares from owner
        _burn(owner, assets);

        // Transfer assets to receiver
        asset_.safeTransfer(receiver, assets);

        return assets;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256) {
        // Burn shares from owner
        _burn(owner, shares);

        // Transfer assets to receiver
        asset_.safeTransfer(receiver, shares);

        return shares;
    }
}
