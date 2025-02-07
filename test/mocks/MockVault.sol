// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IVault} from "../../src/interfaces/IVault.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MockVault is IVault {
    using SafeTransferLib for address;

    address public immutable assetToken;

    constructor(address _assetToken) {
        assetToken = _assetToken;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        // 1:1 conversion for testing
        assetToken.safeTransferFrom(msg.sender, address(this), assets);
        return assets;
    }

    function withdraw(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        // 1:1 conversion for testing
        assetToken.safeTransfer(receiver, shares);
        return shares;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return shares;
    }

    function totalAssets() external view returns (uint256) {
        return 0;
    }

    function asset() external view returns (address) {
        return assetToken;
    }
}
