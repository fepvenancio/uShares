// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC4626 } from "../../interfaces/IERC4626.sol";
import { IVaultRegistry } from "../../interfaces/IVaultRegistry.sol";
import { Errors } from "../core/Errors.sol";

library VaultLogic {
    /// @notice Calculate a fee in basis points
    function calculateFee(uint256 amount, uint256 feeBps) internal pure returns (uint256) {
        return (amount * feeBps) / 10_000;
    }

    /// @notice Calculate total fee (protocol + chain) in basis points
    function calculateTotalFee(uint256 amount, uint256 protocolFee, uint256 chainFee) internal pure returns (uint256) {
        return (amount * (protocolFee + chainFee)) / 10_000;
    }

    /// @notice Check if a vault is active via the registry
    function isVaultActive(address vaultRegistry, address vault) internal view returns (bool) {
        return IVaultRegistry(vaultRegistry).isVaultActive(vault);
    }

    /// @notice Convert shares to assets for a vault
    function convertToAssets(address _vault, uint256 _shares) internal view returns (uint256) {
        return IERC4626(_vault).convertToAssets(_shares);
    }

    /// @notice Convert assets to shares for a vault
    function convertToShares(address _vault, uint256 _assets) internal view returns (uint256) {
        return IERC4626(_vault).convertToShares(_assets);
    }

    /// @notice Get decimals for a vault
    function getDecimals(address _vault) internal view returns (uint256) {
        return IERC4626(_vault).decimals();
    }

    /// @notice Get share price for a vault
    function getSharePrice(address _vault) internal view returns (uint256) {
        return IERC4626(_vault).convertToAssets(10 ** getDecimals(_vault));
    }

    /// @notice Check if a vault uses USDC as its asset
    function isUSDCVault(address _usdc, address _vault) internal view {
        if (IERC4626(_vault).asset() != _usdc) {
            revert Errors.NotUSDC();
        }
    }

    function getVaultTotals(address _vault) external view returns (uint256 totalAssets, uint256 totalShares) { }
}
