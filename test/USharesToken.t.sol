// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {USharesToken} from "../src/USharesToken.sol";
import {VaultRegistry} from "../src/VaultRegistry.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {Pool} from "../src/libs/Pool.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockVault} from "./mocks/MockVault.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockTokenPool} from "./mocks/MockTokenPool.sol";
import {DataTypes} from "../src/types/DataTypes.sol";

contract USharesTokenTest is Test {
    // Constants
    uint64 constant BASE_CHAIN = 8453;
    uint64 constant OPTIMISM_CHAIN = 10;
    uint256 constant INITIAL_MINT = 1_000_000e6;
    uint256 constant DEPOSIT_AMOUNT = 100_000e6;

    // Test accounts
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");

    // Contracts
    MockUSDC public usdc;
    MockVault public vault;
    VaultRegistry public registry;
    PositionManager public positions;
    USharesToken public token;
    MockRouter public router;
    MockTokenPool public tokenPool;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        usdc = new MockUSDC();
        vault = new MockVault(address(usdc));
        registry = new VaultRegistry(address(usdc));
        positions = new PositionManager(address(registry));
        router = new MockRouter();
        tokenPool = new MockTokenPool(
            usdc,
            6,
            address(router)
        );
        token = new USharesToken(
            "uShares",
            "USH",
            BASE_CHAIN,
            true,
            address(positions),
            address(usdc),
            address(tokenPool)
        );

        // Configure contracts
        registry.grantRoles(address(positions), registry.HANDLER_ROLE());
        registry.grantRoles(address(tokenPool), registry.TOKEN_POOL_ROLE());
        registry.registerVault(BASE_CHAIN, address(vault));
        positions.configureTokenPool(BASE_CHAIN, address(tokenPool));

        // Configure token pool
        bytes memory poolBytes = abi.encode(address(tokenPool));
        tokenPool.setRemoteTokenPool(OPTIMISM_CHAIN, poolBytes);

        // Setup initial balances
        usdc.mint(user, INITIAL_MINT);

        vm.stopPrank();
    }

    function test_Deposit() public {
        vm.startPrank(user);
        usdc.approve(address(token), DEPOSIT_AMOUNT);

        bytes32 depositId = token.initiateDeposit(
            OPTIMISM_CHAIN,
            address(vault),
            DEPOSIT_AMOUNT,
            0 // minShares
        );

        // Verify deposit state
        DataTypes.CrossChainDeposit memory deposit = token.getDeposit(depositId);
        assertEq(deposit.amount, DEPOSIT_AMOUNT);
        assertEq(deposit.vault, address(vault));
        assertEq(deposit.chainId, OPTIMISM_CHAIN);
        assertEq(deposit.owner, user);
        assertTrue(deposit.active);

        // Verify token transfers
        assertEq(usdc.balanceOf(user), INITIAL_MINT - DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(address(tokenPool)), DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function test_Withdrawal() public {
        // First deposit
        test_Deposit();

        vm.startPrank(user);
        bytes32 withdrawalId = token.initiateWithdrawal(
            OPTIMISM_CHAIN,
            address(vault),
            DEPOSIT_AMOUNT,
            0 // minAmount
        );

        // Verify withdrawal state
        DataTypes.CrossChainWithdrawal memory withdrawal = token.getWithdrawal(withdrawalId);
        assertEq(withdrawal.amount, DEPOSIT_AMOUNT);
        assertEq(withdrawal.vault, address(vault));
        assertEq(withdrawal.chainId, OPTIMISM_CHAIN);
        assertEq(withdrawal.owner, user);
        assertTrue(withdrawal.active);

        vm.stopPrank();
    }

    function test_RevertWhen_DepositToInvalidVault() public {
        address invalidVault = makeAddr("invalidVault");

        vm.startPrank(user);
        usdc.approve(address(token), DEPOSIT_AMOUNT);

        vm.expectRevert("Invalid vault");
        token.initiateDeposit(
            OPTIMISM_CHAIN,
            invalidVault,
            DEPOSIT_AMOUNT,
            0
        );

        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawFromInvalidVault() public {
        address invalidVault = makeAddr("invalidVault");

        vm.startPrank(user);
        vm.expectRevert("Invalid vault");
        token.initiateWithdrawal(
            OPTIMISM_CHAIN,
            invalidVault,
            DEPOSIT_AMOUNT,
            0
        );

        vm.stopPrank();
    }

    function test_RevertWhen_DepositZeroAmount() public {
        vm.startPrank(user);
        usdc.approve(address(token), 0);

        vm.expectRevert("Invalid amount");
        token.initiateDeposit(
            OPTIMISM_CHAIN,
            address(vault),
            0,
            0
        );

        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawZeroAmount() public {
        vm.startPrank(user);

        vm.expectRevert("Invalid amount");
        token.initiateWithdrawal(
            OPTIMISM_CHAIN,
            address(vault),
            0,
            0
        );

        vm.stopPrank();
    }
}
