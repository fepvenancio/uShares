// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IERC20 } from "interfaces/IERC20.sol";
import { IERC4626 } from "interfaces/IERC4626.sol";
import { BaseModule } from "libraries/base/BaseModule.sol";
import { Errors } from "libraries/core/Errors.sol";

import { IVaultRegistry } from "interfaces/IVaultRegistry.sol";

import { Constants } from "libraries/core/Constants.sol";
import { Events } from "libraries/core/Events.sol";
import { VaultLogic } from "libraries/logic/VaultLogic.sol";
import { USharesToken } from "protocol/tokenization/USharesToken.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title LocalVaultModule
 * @notice Handles deposits and withdrawals for vaults on the same chain (local only)
 */
contract LocalVault is BaseModule {
    using SafeTransferLib for address;

    event DepositInitiated(address indexed user, address indexed vault, uint256 amount, uint256 minSharesExpected);
    event WithdrawalInitiated(address indexed user, address indexed vault, uint256 shares, uint256 minUsdcExpected);

    constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseModule(moduleId_, moduleVersion_) { }

    /**
     * @notice Deposit USDC to get vault exposure (local vaults only)
     * @param amount Amount of USDC to deposit
     * @param vault Vault address to deposit into
     * @param minSharesExpected Minimum shares expected to receive
     * @param deadline Timestamp after which transaction reverts
     */
    function deposit(uint256 amount, address vault, uint256 minSharesExpected, uint256 deadline) external reentrantOK {
        Errors.verifyAddress(vault);
        IVaultRegistry vaultRegistry = IVaultRegistry(_moduleLookup[Constants.MODULEID__VAULT_REGISTRY]);
        // Only allow local vaults
        if (!VaultLogic.isVaultActive(address(vaultRegistry), vault)) {
            revert Errors.VaultNotActive();
        }
        // Calculate fees
        uint256 fee = VaultLogic.calculateFee(amount, protocolFee());
        uint256 depositAmount = amount - fee;
        // Transfer USDC from user
        _usdc.safeTransferFrom(msg.sender, address(this), amount);
        // Handle fees
        if (fee > 0 && feeCollector() != address(0)) {
            _usdc.safeTransfer(feeCollector(), fee);
        }
        // Approve vault to spend USDC
        _usdc.safeApprove(vault, depositAmount);
        // Deposit into vault
        uint256 shares = IERC4626(vault).deposit(depositAmount, address(this));
        if (shares < minSharesExpected) revert Errors.InsufficientShares();
        // Mint uSharesToken to user (local only)
        USharesToken uShares = USharesToken(uSharesTokens[vault]);
        uShares.mint(msg.sender, shares);
        emit Events.DepositInitiated(msg.sender, uint32(block.chainid), vault, depositAmount, minSharesExpected);
    }

    /**
     * @notice Withdraw USDC from vault position (local vaults only)
     * @param shares Amount of shares to withdraw
     * @param vault Vault address to withdraw from
     * @param minUsdcExpected Minimum USDC expected to receive
     * @param deadline Timestamp after which transaction reverts
     */
    function withdraw(uint256 shares, address vault, uint256 minUsdcExpected, uint256 deadline) external reentrantOK {
        Errors.verifyAddress(vault);
        IVaultRegistry vaultRegistry = IVaultRegistry(_moduleLookup[Constants.MODULEID__VAULT_REGISTRY]);
        // Only allow local vaults
        if (!VaultLogic.isVaultActive(address(vaultRegistry), vault)) {
            revert Errors.VaultNotActive();
        }
        // Withdraw from vault
        uint256 usdcAmount = IERC4626(vault).redeem(shares, msg.sender, address(this));
        if (usdcAmount < minUsdcExpected) revert Errors.InsufficientUSDC();
        // Burn uSharesToken from user (local only)
        USharesToken uShares = USharesToken(uSharesTokens[vault]);
        uShares.burnFrom(msg.sender, shares);
        emit Events.WithdrawalInitiated(msg.sender, uint32(block.chainid), vault, shares, minUsdcExpected);
    }
}
