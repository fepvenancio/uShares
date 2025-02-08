// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "./base/BaseTest.t.sol";
import {DataTypes} from "../src/types/DataTypes.sol";
import {Pool} from "../src/libs/Pool.sol";

contract CrossChainOperationsTest is BaseTest {
    uint256 constant DEPOSIT_AMOUNT = 100_000e6;
    uint256 constant INITIAL_MINT = 1_000_000e6;

    function test_CrossChainDeposit_Base_To_Optimism() public {
        vm.startPrank(user);
        baseUSDC.approve(address(baseToken), DEPOSIT_AMOUNT);

        // Initiate deposit on Base
        bytes32 depositId = baseToken.initiateDeposit(
            OPTIMISM_CHAIN,
            address(optimismVault),
            DEPOSIT_AMOUNT,
            0 // minShares
        );

        // Verify Base state
        DataTypes.CrossChainDeposit memory deposit = baseToken.getDeposit(depositId);
        assertEq(deposit.amount, DEPOSIT_AMOUNT);
        assertEq(deposit.vault, address(optimismVault));
        assertEq(deposit.chainId, OPTIMISM_CHAIN);
        assertEq(deposit.owner, user);
        assertTrue(deposit.active);

        // Verify token transfers on Base
        assertEq(baseUSDC.balanceOf(user), INITIAL_MINT - DEPOSIT_AMOUNT);
        assertEq(baseUSDC.balanceOf(address(baseTokenPool)), DEPOSIT_AMOUNT);

        // Simulate cross-chain message
        bytes memory message = abi.encode(
            Pool.LockOrBurnOutV1({
                destTokenAddress: abi.encode(address(optimismUSDC)),
                destPoolData: abi.encode(DEPOSIT_AMOUNT)
            })
        );
        _sendMessageBaseToOptimism(message);

        // Verify Optimism state
        assertEq(optimismUSDC.balanceOf(address(optimismVault)), INITIAL_MINT + DEPOSIT_AMOUNT);
        assertEq(optimismToken.balanceOf(user), DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function test_CrossChainWithdraw_Optimism_To_Base() public {
        // First deposit from Base to Optimism
        test_CrossChainDeposit_Base_To_Optimism();

        vm.startPrank(user);
        optimismToken.approve(address(optimismToken), DEPOSIT_AMOUNT);

        // Initiate withdrawal on Optimism
        bytes32 withdrawalId = optimismToken.initiateWithdrawal(
            BASE_CHAIN,
            address(baseVault),
            DEPOSIT_AMOUNT,
            0 // minAmount
        );

        // Verify Optimism state
        DataTypes.CrossChainWithdrawal memory withdrawal = optimismToken.getWithdrawal(withdrawalId);
        assertEq(withdrawal.amount, DEPOSIT_AMOUNT);
        assertEq(withdrawal.vault, address(baseVault));
        assertEq(withdrawal.chainId, BASE_CHAIN);
        assertEq(withdrawal.owner, user);
        assertTrue(withdrawal.active);

        // Verify token transfers on Optimism
        assertEq(optimismToken.balanceOf(user), 0);
        assertEq(optimismUSDC.balanceOf(address(optimismVault)), INITIAL_MINT);

        // Simulate cross-chain message
        bytes memory message = abi.encode(
            Pool.LockOrBurnOutV1({
                destTokenAddress: abi.encode(address(baseUSDC)),
                destPoolData: abi.encode(DEPOSIT_AMOUNT)
            })
        );
        _sendMessageOptimismToBase(message);

        // Verify Base state
        assertEq(baseUSDC.balanceOf(user), INITIAL_MINT);
        assertEq(baseUSDC.balanceOf(address(baseTokenPool)), 0);

        vm.stopPrank();
    }

    function test_RevertWhen_InvalidVault() public {
        address invalidVault = makeAddr("invalidVault");

        vm.startPrank(user);
        baseUSDC.approve(address(baseToken), DEPOSIT_AMOUNT);

        vm.expectRevert("Invalid vault");
        baseToken.initiateDeposit(
            OPTIMISM_CHAIN,
            invalidVault,
            DEPOSIT_AMOUNT,
            0
        );

        vm.stopPrank();
    }

    function test_RevertWhen_ZeroAmount() public {
        vm.startPrank(user);
        baseUSDC.approve(address(baseToken), 0);

        vm.expectRevert("Amount must be greater than 0");
        baseToken.initiateDeposit(
            OPTIMISM_CHAIN,
            address(optimismVault),
            0,
            0
        );

        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientBalance() public {
        uint256 tooMuch = INITIAL_MINT + 1;

        vm.startPrank(user);
        baseUSDC.approve(address(baseToken), tooMuch);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        baseToken.initiateDeposit(
            OPTIMISM_CHAIN,
            address(optimismVault),
            tooMuch,
            0
        );

        vm.stopPrank();
    }

    function test_RevertWhen_DuplicateMessage() public {
        // First do a valid cross-chain deposit
        test_CrossChainDeposit_Base_To_Optimism();

        // Try to replay the same message
        bytes memory message = abi.encode(
            Pool.LockOrBurnOutV1({
                destTokenAddress: abi.encode(address(optimismUSDC)),
                destPoolData: abi.encode(DEPOSIT_AMOUNT)
            })
        );

        vm.expectRevert("Duplicate message");
        _sendMessageBaseToOptimism(message);
    }
} 