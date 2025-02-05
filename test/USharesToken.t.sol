// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./base/BaseTest.t.sol";
import {USharesToken} from "../src/USharesToken.sol";
import {IUSharesToken} from "../src/interfaces/IUSharesToken.sol";
import {Errors} from "../src/libs/Errors.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockCCTP} from "./mocks/MockCCTP.sol";
import {ICCTToken} from "../src/interfaces/ICCTToken.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";

// Constants for chain IDs
uint32 constant CHAIN_ID = 1; // Ethereum mainnet
uint32 constant SOURCE_CHAIN = 1; // Ethereum mainnet
uint32 constant DEST_CHAIN = 43114; // Avalanche C-Chain

// Test amounts
uint256 constant VALID_AMOUNT = 500_000e6; // 500k USDC (half of max)
uint256 constant EXCEEDS_MAX = 1_500_000e6; // 1.5M USDC (exceeds max)
uint256 constant MIN_SHARES = 450_000e6; // 90% of deposit (assuming some slippage)

contract USharesTokenTest is BaseTest {
    // Contract instances
    USharesToken public token;
    MockCCTP public mockCctp;
    MockRouter public mockRouter;
    PositionManager public positionManager;

    // Additional test accounts
    address public ccipAdmin;
    address public tokenPool;

    // Constants
    string public constant NAME = "uShares";
    string public constant SYMBOL = "uSHR";
    uint256 public constant TEST_DEADLINE = 1 hours;  // Changed from DEADLINE to TEST_DEADLINE

    // Test state
    bytes32 public testDepositId;
    bytes public testAttestation;

    function setUp() public override {
        super.setUp();

        ccipAdmin = makeAddr("ccipAdmin");
        tokenPool = makeAddr("tokenPool");

        vm.startPrank(deployer);

        // Deploy mock contracts
        mockCctp = new MockCCTP();
        mockRouter = new MockRouter();

        // Deploy and configure PositionManager
        positionManager = new PositionManager(address(registry));

        // Deploy token with deployer as owner
        token = new USharesToken(
            NAME,
            SYMBOL,
            SOURCE_CHAIN,
            address(positionManager),
            ccipAdmin,
            address(mockCctp),
            address(usdc),
            address(mockRouter)
        );

        // Set vault registry in token contract
        token.setVaultRegistry(address(registry));

        // Configure PositionManager permissions
        positionManager.configureHandler(address(token), true);
        positionManager.configureHandler(tokenPool, true);

        // Configure token permissions
        token.configureMinter(address(positionManager), true);
        token.configureBurner(address(positionManager), true);
        token.configureMinter(tokenPool, true);
        token.configureBurner(tokenPool, true);

        vm.stopPrank();

        // Configure token pool using CCIP admin
        vm.startPrank(ccipAdmin);
        token.configureTokenPool(tokenPool, true);
        token.setVaultMapping(DEST_CHAIN, address(vault), address(vault));
        vm.stopPrank();

        // Setup approvals
        vm.startPrank(user1);
        usdc.approve(address(token), type(uint256).max);
        token.approve(address(token), type(uint256).max);
        vm.stopPrank();

        // Setup test attestation
        testAttestation = abi.encode("test_attestation");
    }

    // Test complete cross-chain deposit flow
    function test_CrossChainDepositFlow() public {
        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        vm.stopPrank();

        // Step 1: User initiates deposit
        vm.startPrank(user1);
        
        // Mint test USDC to user
        usdc.mint(user1, VALID_AMOUNT);
        
        // Initiate deposit
        testDepositId = token.initiateDeposit(
            address(vault),
            VALID_AMOUNT,
            uint64(DEST_CHAIN),
            MIN_SHARES,
            block.timestamp + TEST_DEADLINE
        );

        // Verify deposit state
        USharesToken.CrossChainDeposit memory deposit = token.getDeposit(testDepositId);
        assertEq(deposit.user, user1);
        assertEq(deposit.usdcAmount, VALID_AMOUNT);
        assertEq(deposit.sourceVault, address(vault));
        assertEq(deposit.targetVault, address(vault));
        assertEq(deposit.destinationChain, DEST_CHAIN);
        assertEq(deposit.vaultShares, 0);
        assertEq(deposit.uSharesMinted, 0);
        assertFalse(deposit.cctpCompleted);
        assertFalse(deposit.sharesIssued);
        assertEq(deposit.minShares, MIN_SHARES);
        
        vm.stopPrank();

        // Step 2: Process CCTP completion
        // Mock vault to return shares 1:1 with USDC
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.deposit.selector, VALID_AMOUNT, address(token)),
            abi.encode(VALID_AMOUNT)
        );

        token.processCCTPCompletion(testDepositId, testAttestation);

        // Verify final state
        deposit = token.getDeposit(testDepositId);
        assertTrue(deposit.cctpCompleted);
        assertTrue(deposit.sharesIssued);
        assertEq(deposit.vaultShares, VALID_AMOUNT);
        assertEq(deposit.uSharesMinted, VALID_AMOUNT);
        assertEq(token.balanceOf(user1), VALID_AMOUNT);
    }

    // Test max transaction size limits
    function test_MaxTransactionSize() public {
        vm.startPrank(user1);
        
        // Mint test USDC to user
        usdc.mint(user1, EXCEEDS_MAX);
        
        // Try to deposit more than max
        vm.expectRevert(Errors.ExceedsMaxSize.selector);
        token.initiateDeposit(
            address(vault),
            EXCEEDS_MAX,
            uint64(DEST_CHAIN),
            MIN_SHARES,
            block.timestamp + TEST_DEADLINE  // Use block.timestamp + TEST_DEADLINE
        );
        
        vm.stopPrank();
    }

    // Test withdrawal flow
    function test_Withdrawal() public {
        // First setup a balance for user1
        vm.startPrank(address(positionManager));
        token.mint(user1, VALID_AMOUNT);
        vm.stopPrank();

        // Store initial balance
        uint256 initialBalance = usdc.balanceOf(user1);

        // Mock vault withdrawal
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.withdraw.selector, VALID_AMOUNT, user1, address(token)),
            abi.encode(VALID_AMOUNT)
        );

        // Mock USDC balance for contract
        deal(address(usdc), address(token), VALID_AMOUNT);

        // Perform withdrawal
        vm.startPrank(user1);
        token.withdraw(VALID_AMOUNT, address(vault));
        vm.stopPrank();

        // Verify state
        assertEq(token.balanceOf(user1), 0);
        assertEq(usdc.balanceOf(user1), initialBalance + VALID_AMOUNT);
    }

    // Test deposit expiration
    function test_DepositExpiration() public {
        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        vm.stopPrank();

        vm.startPrank(user1);
        usdc.mint(user1, VALID_AMOUNT);
        
        // Create deposit with short deadline
        testDepositId = token.initiateDeposit(
            address(vault),
            VALID_AMOUNT,
            uint64(DEST_CHAIN),
            MIN_SHARES,
            block.timestamp + 1 // 1 second deadline
        );
        
        // Move time forward
        vm.warp(block.timestamp + 2);
        
        // Try to process expired deposit
        vm.expectRevert(abi.encodeWithSelector(Errors.DepositExpired.selector));
        token.processCCTPCompletion(testDepositId, testAttestation);
        
        vm.stopPrank();
    }

    // Test insufficient shares from vault
    function test_InsufficientShares() public {
        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        vm.stopPrank();

        vm.startPrank(user1);
        usdc.mint(user1, VALID_AMOUNT);
        
        testDepositId = token.initiateDeposit(
            address(vault),
            VALID_AMOUNT,
            uint64(DEST_CHAIN),
            MIN_SHARES,
            block.timestamp + TEST_DEADLINE
        );
        vm.stopPrank();

        // Mock USDC balance for contract
        deal(address(usdc), address(token), VALID_AMOUNT);
        
        // Mock vault approval
        vm.prank(address(token));
        usdc.approve(address(vault), VALID_AMOUNT);

        // Mock vault to return less shares than minimum
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.deposit.selector, VALID_AMOUNT, address(token)),
            abi.encode(MIN_SHARES - 1)
        );

        // Process CCTP and expect revert on insufficient shares
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientShares.selector));
        token.processCCTPCompletion(testDepositId, testAttestation);
    }

    // Test recovery of stale deposit
    function test_RecoverStaleDeposit() public {
        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        vm.stopPrank();

        vm.startPrank(user1);
        
        // Mint initial USDC balance
        usdc.mint(user1, VALID_AMOUNT);
        
        testDepositId = token.initiateDeposit(
            address(vault),
            VALID_AMOUNT,
            uint64(DEST_CHAIN),
            MIN_SHARES,
            block.timestamp + TEST_DEADLINE
        );
        
        // Move time forward past timeout
        vm.warp(block.timestamp + token.PROCESS_TIMEOUT() + 1);
        
        // Mock USDC balance for contract
        deal(address(usdc), address(token), VALID_AMOUNT);
        
        // Store initial balance
        uint256 initialBalance = usdc.balanceOf(user1);
        
        // Recover stale deposit
        token.recoverStaleDeposit(testDepositId);
        
        // Verify USDC was returned
        assertEq(usdc.balanceOf(user1), initialBalance + VALID_AMOUNT);
        
        vm.stopPrank();
    }

    // Basic view function tests
    function test_GetChainId() public {
        assertEq(token.getChainId(), SOURCE_CHAIN);
    }

    function test_GetCCIPAdmin() public {
        assertEq(token.getCCIPAdmin(), ccipAdmin);
    }

    function test_Decimals() public {
        assertEq(token.decimals(), 6);
    }

    function test_Name() public {
        assertEq(token.name(), NAME);
    }

    function test_Symbol() public {
        assertEq(token.symbol(), SYMBOL);
    }

    // Test CCT lockOrBurn flow
    function test_LockOrBurn() public {
        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        registry.registerVault(SOURCE_CHAIN, address(vault));
        vm.stopPrank();

        // Setup vault mapping for token pool
        vm.startPrank(ccipAdmin);
        token.setVaultMapping(DEST_CHAIN, tokenPool, address(vault));
        token.setVaultMapping(SOURCE_CHAIN, tokenPool, address(vault));
        vm.stopPrank();

        // Setup initial balance
        vm.startPrank(address(positionManager));
        token.mint(tokenPool, VALID_AMOUNT);
        vm.stopPrank();

        // Create initial position
        vm.startPrank(address(token));
        positionManager.createPosition(
            tokenPool,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault),
            VALID_AMOUNT
        );
        vm.stopPrank();

        // Mock USDC balance and approval
        deal(address(usdc), address(token), VALID_AMOUNT);
        vm.prank(address(token));
        usdc.approve(address(mockCctp), VALID_AMOUNT);

        // Perform lockOrBurn
        vm.startPrank(tokenPool);
        bytes memory message = token.lockOrBurn(
            ICCTToken.LockOrBurnParams({
                sender: tokenPool,
                amount: VALID_AMOUNT,
                destinationChainSelector: uint64(DEST_CHAIN),
                receiver: tokenPool,
                depositId: bytes32(0)
            })
        );

        // Verify state
        assertEq(token.balanceOf(tokenPool), 0);
        assertEq(mockCctp.getBurnedAmount(address(token)), VALID_AMOUNT);
        
        // Verify position updated
        bytes32 positionKey = positionManager.getPositionKey(
            tokenPool,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault)
        );
        IPositionManager.Position memory position = positionManager.getPosition(positionKey);
        assertEq(position.shares, 0);
        
        vm.stopPrank();
    }

    // Test CCT releaseOrMint flow
    function test_ReleaseOrMint() public {
        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        registry.registerVault(SOURCE_CHAIN, address(vault));
        registry.updateVaultStatus(DEST_CHAIN, address(vault), true);
        registry.updateVaultStatus(SOURCE_CHAIN, address(vault), true);
        vm.stopPrank();

        // Setup vault mapping for token pool
        vm.startPrank(ccipAdmin);
        token.setVaultMapping(DEST_CHAIN, tokenPool, address(vault));
        token.setVaultMapping(SOURCE_CHAIN, tokenPool, address(vault));
        vm.stopPrank();

        // Create initial position with zero shares
        vm.startPrank(address(token));
        positionManager.createPosition(
            tokenPool,
            DEST_CHAIN,
            SOURCE_CHAIN,
            address(vault),
            0
        );
        vm.stopPrank();

        // Perform releaseOrMint
        vm.startPrank(tokenPool);
        uint256 mintedAmount = token.releaseOrMint(
            ICCTToken.ReleaseOrMintParams({
                receiver: user1,
                amount: VALID_AMOUNT,
                sourceChainSelector: uint64(DEST_CHAIN),
                depositId: bytes32(0)
            })
        );

        // Verify state
        assertEq(mintedAmount, VALID_AMOUNT);
        assertEq(token.balanceOf(user1), VALID_AMOUNT);
        
        // Verify position updated
        bytes32 positionKey = positionManager.getPositionKey(
            tokenPool,
            DEST_CHAIN,
            SOURCE_CHAIN,
            address(vault)
        );
        IPositionManager.Position memory position = positionManager.getPosition(positionKey);
        assertEq(position.shares, VALID_AMOUNT);
        
        vm.stopPrank();
    }

    // Test vault share calculation
    function test_VaultShareCalculation() public {
        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        vm.stopPrank();

        vm.startPrank(user1);
        usdc.mint(user1, VALID_AMOUNT);
        
        // Mock different share prices
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.deposit.selector, VALID_AMOUNT, address(token)),
            abi.encode(VALID_AMOUNT * 2) // 2x share price
        );
        
        // Initiate deposit
        testDepositId = token.initiateDeposit(
            address(vault),
            VALID_AMOUNT,
            uint64(DEST_CHAIN),
            MIN_SHARES,
            block.timestamp + TEST_DEADLINE
        );
        vm.stopPrank();

        // Mock USDC balance and approval
        deal(address(usdc), address(token), VALID_AMOUNT);
        vm.prank(address(token));
        usdc.approve(address(vault), VALID_AMOUNT);

        // Process CCTP
        token.processCCTPCompletion(testDepositId, testAttestation);

        // Verify share calculation
        USharesToken.CrossChainDeposit memory deposit = token.getDeposit(testDepositId);
        assertEq(deposit.vaultShares, VALID_AMOUNT * 2);
        assertEq(deposit.uSharesMinted, VALID_AMOUNT * 2);
        assertEq(token.balanceOf(user1), VALID_AMOUNT * 2);
    }

    // Test cross-chain position updates
    function test_CrossChainPositionUpdates() public {
        // Setup vault mapping
        vm.startPrank(ccipAdmin);
        token.setVaultMapping(DEST_CHAIN, address(vault), address(vault));
        vm.stopPrank();

        // Register vault in registry
        vm.startPrank(deployer);
        registry.registerVault(DEST_CHAIN, address(vault));
        vm.stopPrank();

        // Create deposit
        vm.startPrank(user1);
        usdc.mint(user1, VALID_AMOUNT);
        
        testDepositId = token.initiateDeposit(
            address(vault),
            VALID_AMOUNT,
            uint64(DEST_CHAIN),
            MIN_SHARES,
            block.timestamp + TEST_DEADLINE
        );
        vm.stopPrank();

        // Mock USDC balance and approval
        deal(address(usdc), address(token), VALID_AMOUNT);
        vm.prank(address(token));
        usdc.approve(address(vault), VALID_AMOUNT);

        // Mock vault deposit behavior
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.deposit.selector, VALID_AMOUNT, address(token)),
            abi.encode(VALID_AMOUNT)
        );

        // Process CCTP
        token.processCCTPCompletion(testDepositId, testAttestation);

        // Get position key
        bytes32 positionKey = positionManager.getPositionKey(
            user1,
            SOURCE_CHAIN,
            DEST_CHAIN,
            address(vault)
        );

        // Verify position state
        IPositionManager.Position memory position = positionManager.getPosition(positionKey);
        assertEq(position.shares, VALID_AMOUNT);
    }
}
