// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Errors} from "./Errors.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";

library VaultLib {
    function convertToAssets(
        address _vault,
        uint256 _shares
    ) internal view returns (uint256) {
        return IERC4626(_vault).convertToAssets(_shares);
    }

    function convertToShares(
        address _vault,
        uint256 _assets
    ) internal view returns (uint256) {
        return IERC4626(_vault).convertToShares(_assets);
    }

    function getDecimals(address _vault) internal view returns (uint256) {
        return IERC4626(_vault).decimals();
    }

    function getSharePrice(address _vault) internal view returns (uint256) {
        return IERC4626(_vault).convertToAssets(1 ** getDecimals(_vault));
    }

    function isUSDCVault(address _usdc, address _vault) internal view {
        if (IERC4626(_vault).asset() != _usdc) {
            revert Errors.NotUSDC();
        }
    }

    function getVaultTotals(
        address _vault
    ) external view returns (uint256 totalAssets, uint256 totalShares) {
        
    }
}
