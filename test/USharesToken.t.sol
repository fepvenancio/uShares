// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {USharesToken} from "../src/USharesToken.sol";
import {IUSharesToken} from "../src/interfaces/IUSharesToken.sol";
import {ICCTToken} from "../src/interfaces/ICCTToken.sol";
import {ICCTP} from "../src/interfaces/ICCTP.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {IRouter} from "../src/interfaces/IRouter.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockCCTP} from "./mocks/MockCCTP.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockVaultRegistry} from "./mocks/MockVaultRegistry.sol";
import {MockPositionManager} from "./mocks/MockPositionManager.sol";
import {DataTypes} from "../src/types/DataTypes.sol";
import {Errors} from "../src/libs/Errors.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {VaultRegistry} from "../src/VaultRegistry.sol";
import {TestVault} from "./mocks/TestVault.sol";

contract USharesTokenTest is Test {
    // Chain IDs
    uint32 constant BASE_CHAIN_ID = 8453;
    uint32 constant OPTIMISM_CHAIN_ID = 10;
    uint32 constant BASE_DOMAIN = 6;      // CCTP domain for Base
    uint32 constant OPTIMISM_DOMAIN = 2;  // CCTP domain for Optimism

    // Real USDC addresses
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Test amounts
    uint256 constant VALID_AMOUNT = 500_000e6; // 500k USDC (half of max)
    uint256 constant EXCEEDS_MAX = 1_500_000e6; // 1.5M USDC (exceeds max)
    uint256 constant MIN_SHARES = 450_000e6; // 90% of deposit (assuming some slippage)
    uint256 constant MIN_USDC = 450_000e6; // 90% of withdrawal (assuming some slippage)

    // Contracts
    USharesToken baseToken;
    VaultRegistry baseRegistry;
    PositionManager basePositions;
    MockCCTP baseCCTP;
    MockRouter baseRouter;
    ERC20 baseUSDC;
    IVault baseVault;

    // Test accounts
    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address admin = makeAddr("admin");

    function setUp() public {
        // Create Base fork
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 5_000_000);

        // Set block timestamp
        vm.warp(block.timestamp + 1 days);

        // Deploy Base contracts
        vm.startPrank(deployer);
        baseUSDC = ERC20(BASE_USDC);
        baseCCTP = new MockCCTP(BASE_USDC, BASE_DOMAIN);
        baseRouter = new MockRouter();
        baseRegistry = new VaultRegistry(BASE_USDC);
        basePositions = new PositionManager(address(baseRegistry));
        
        // Configure position manager with handler role in registry
        baseRegistry.grantRoles(address(basePositions), baseRegistry.HANDLER_ROLE());
        
        // Deploy Base vault
        baseVault = IVault(address(new TestVault(
            BASE_USDC,
            "Base USDC Vault",
            "bvUSDC"
        )));
        baseRegistry.registerVault(BASE_CHAIN_ID, address(baseVault));

        // Deploy mock Optimism vault
        IVault optimismVault = IVault(address(new TestVault(
            BASE_USDC,
            "Optimism USDC Vault",
            "opvUSDC"
        )));
        baseRegistry.registerVault(OPTIMISM_CHAIN_ID, address(optimismVault));
        
        baseToken = new USharesToken(
            "uShares",
            "uSHR",
            BASE_CHAIN_ID,
            address(basePositions),
            admin,
            address(baseCCTP),
            BASE_USDC,
            address(baseRouter)
        );

        // Grant admin role and transfer ownership to admin
        baseToken.grantRoles(admin, baseToken.ADMIN_ROLE());
        baseToken.transferOwnership(admin);
        baseToken.renounceRoles(baseToken.ADMIN_ROLE());
        
        // Grant admin role to admin in position manager
        basePositions.grantRoles(admin, basePositions.ADMIN_ROLE());
        vm.stopPrank();

        // Configure cross-chain mappings and permissions
        vm.startPrank(admin);
        baseToken.setVaultRegistry(address(baseRegistry));
        vm.stopPrank();

        // Configure CCIP admin operations
        vm.startPrank(admin);
        baseToken.setVaultMapping(OPTIMISM_CHAIN_ID, address(baseVault), address(optimismVault));
        baseRouter.setTokenPool(address(baseVault), address(baseCCTP));
        baseToken.configureTokenPool(address(baseVault), true);
        vm.stopPrank();

        // Configure minter/burner roles
        vm.startPrank(admin);
        baseToken.configureMinter(address(basePositions), true);
        baseToken.configureBurner(address(basePositions), true);
        vm.stopPrank();

        // Configure vault as handler in position manager
        vm.startPrank(admin);
        basePositions.configureHandler(address(baseVault), true);
        basePositions.configureHandler(address(baseToken), true);
        vm.stopPrank();

        // Fund test user with USDC
        deal(BASE_USDC, user, VALID_AMOUNT * 2);
        vm.startPrank(user);
        baseUSDC.approve(address(baseToken), type(uint256).max);
        vm.stopPrank();
    }

    function test_CrossChainDepositBaseToOptimism() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 1 hours;

        // Start deposit on Base
        bytes32 depositId = baseToken.initiateDeposit(
            address(baseVault),
            VALID_AMOUNT,
            uint64(OPTIMISM_CHAIN_ID),
            MIN_SHARES,
            deadline
        );

        // Mock CCTP completion
        bytes memory attestation = abi.encode(
            BASE_DOMAIN,
            bytes32(uint256(uint160(address(baseToken)))),
            abi.encode(VALID_AMOUNT)  // Include USDC amount in message
        );

        // Process CCTP completion
        baseToken.processCCTPCompletion(depositId, attestation);

        // Verify deposit completed
        DataTypes.CrossChainDeposit memory deposit = baseToken.getDeposit(depositId);
        assertTrue(deposit.cctpCompleted);
        assertTrue(deposit.sharesIssued);
        assertEq(deposit.vaultShares, VALID_AMOUNT);
        assertEq(deposit.uSharesMinted, VALID_AMOUNT);

        vm.stopPrank();
    }

    function test_RevertDepositExpired() public {
        vm.startPrank(user);

        // Set deadline in the past
        uint256 deadline = block.timestamp - 1 hours;

        vm.expectRevert(Errors.DepositExpired.selector);
        baseToken.initiateDeposit(
            address(baseVault),
            VALID_AMOUNT,
            uint64(OPTIMISM_CHAIN_ID),
            MIN_SHARES,
            deadline
        );

        vm.stopPrank();
    }

    function test_RevertExceedsMaxSize() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(Errors.ExceedsMaxSize.selector);
        baseToken.initiateDeposit(
            address(baseVault),
            EXCEEDS_MAX,
            uint64(OPTIMISM_CHAIN_ID),
            MIN_SHARES,
            deadline
        );

        vm.stopPrank();
    }

    function test_RevertInvalidVault() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(Errors.InvalidVault.selector);
        baseToken.initiateDeposit(
            address(0x9876),  // Random invalid vault address
            VALID_AMOUNT,
            uint64(OPTIMISM_CHAIN_ID),
            MIN_SHARES,
            deadline
        );

        vm.stopPrank();
    }

    function test_RevertDuplicateCCTPMessage() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 1 hours;

        // Start deposit
        bytes32 depositId = baseToken.initiateDeposit(
            address(baseVault),
            VALID_AMOUNT,
            uint64(OPTIMISM_CHAIN_ID),
            MIN_SHARES,
            deadline
        );

        // Create attestation
        bytes memory attestation = abi.encode(
            BASE_DOMAIN,
            bytes32(uint256(uint160(address(baseToken)))),
            abi.encode(VALID_AMOUNT)
        );

        // First completion should succeed
        baseToken.processCCTPCompletion(depositId, attestation);

        // Second completion should fail
        vm.expectRevert(Errors.CCTPAlreadyCompleted.selector);
        baseToken.processCCTPCompletion(depositId, attestation);

        vm.stopPrank();
    }

    function test_RecoverStaleDeposit() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + 1 hours;

        // Start deposit
        bytes32 depositId = baseToken.initiateDeposit(
            address(baseVault),
            VALID_AMOUNT,
            uint64(OPTIMISM_CHAIN_ID),
            MIN_SHARES,
            deadline
        );

        // Advance time past process timeout
        vm.warp(block.timestamp + 2 hours);

        // Recovery should succeed
        baseToken.recoverStaleDeposit(depositId);

        // Verify deposit was deleted
        DataTypes.CrossChainDeposit memory deposit = baseToken.getDeposit(depositId);
        assertEq(deposit.user, address(0));
        assertEq(deposit.usdcAmount, 0);

        vm.stopPrank();
    }

    // Helper functions
    function _initiateDeposit() internal returns (bytes32) {
        uint256 deadline = block.timestamp + 1 hours;
        return baseToken.initiateDeposit(
            address(baseVault),
            VALID_AMOUNT,
            uint64(OPTIMISM_CHAIN_ID),
            MIN_SHARES,
            deadline
        );
    }

    function _initiateWithdrawal() internal returns (bytes32) {
        uint256 deadline = block.timestamp + 1 hours;
        return baseToken.initiateWithdrawal(
            VALID_AMOUNT,
            address(baseVault),
            MIN_USDC,
            deadline
        );
    }

    function test_GetDeposit() public {
        vm.startPrank(user);
        bytes32 depositId = _initiateDeposit();
        DataTypes.CrossChainDeposit memory deposit = baseToken.getDeposit(depositId);
        
        assertEq(deposit.user, user);
        assertEq(deposit.usdcAmount, VALID_AMOUNT);
        assertEq(deposit.sourceVault, address(baseVault));
        assertEq(deposit.destinationChain, OPTIMISM_CHAIN_ID);
        assertEq(deposit.vaultShares, 0);
        assertEq(deposit.uSharesMinted, 0);
        assertFalse(deposit.cctpCompleted);
        assertFalse(deposit.sharesIssued);
        vm.stopPrank();
    }

    function test_GetWithdrawal() public {
        vm.startPrank(user);

        // First complete a deposit to get some tokens
        bytes32 depositId = _initiateDeposit();
        
        // Mock CCTP completion
        bytes memory attestation = abi.encode(
            BASE_DOMAIN,
            bytes32(uint256(uint160(address(baseToken)))),
            abi.encode(VALID_AMOUNT)  // Include USDC amount in message
        );

        // Process CCTP completion
        baseToken.processCCTPCompletion(depositId, attestation);

        // Now initiate withdrawal
        bytes32 withdrawalId = _initiateWithdrawal();
        DataTypes.CrossChainWithdrawal memory withdrawal = baseToken.getWithdrawal(withdrawalId);
        
        assertEq(withdrawal.user, user);
        assertEq(withdrawal.uSharesAmount, VALID_AMOUNT);
        assertEq(withdrawal.sourceVault, address(baseVault));
        assertEq(withdrawal.destinationChain, OPTIMISM_CHAIN_ID);
        assertEq(withdrawal.usdcAmount, 0);
        assertFalse(withdrawal.cctpCompleted);
        assertFalse(withdrawal.sharesWithdrawn);
        vm.stopPrank();
    }
}
