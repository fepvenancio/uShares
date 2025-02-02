// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./base/BaseTest.t.sol";
import {USharesToken} from "../src/USharesToken.sol";
import {Errors} from "../src/libs/Errors.sol";
import {ICCTToken} from "../src/interfaces/ICCTToken.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockCCTP} from "./mocks/MockCCTP.sol";
import {MockVault} from "./mocks/MockVault.sol";

// Constants for chain IDs
uint32 constant CHAIN_ID = 1; // Ethereum mainnet
uint32 constant SOURCE_CHAIN = 1; // Ethereum mainnet
uint32 constant DEST_CHAIN = 43114; // Avalanche C-Chain

// Test amounts
uint256 constant VALID_AMOUNT = 500_000e6; // 500k USDC (half of max)
uint256 constant EXCEEDS_MAX = 1_500_000e6; // 1.5M USDC (exceeds max)
uint256 constant POSITION_SIZE = 1_000_000e6; // 1M USDC for positions

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

        // Deploy mock vaults for each chain
        MockVault sourceVault = new MockVault(usdc);
        MockVault destVault = new MockVault(usdc);
        MockVault baseVault = new MockVault(usdc);

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

        // Configure token permissions for PositionManager
        token.configureMinter(address(positionManager), true);
        token.configureBurner(address(positionManager), true);

        // Configure token permissions for tokenPool
        token.configureMinter(tokenPool, true);
        token.configureBurner(tokenPool, true);

        vm.stopPrank();

        // Configure token pool using CCIP admin
        vm.startPrank(ccipAdmin);
        token.configureTokenPool(tokenPool, true);

        // Configure vault mappings
        token.setVaultMapping(uint32(DEST_CHAIN), tokenPool, address(vault));
        token.setVaultMapping(uint32(SOURCE_CHAIN), tokenPool, address(vault));
        token.setVaultMapping(8453, tokenPool, address(vault));
        vm.stopPrank();

        // Setup approvals for tests
        vm.startPrank(user1);
        token.approve(tokenPool, type(uint256).max);
        token.approve(address(token), type(uint256).max);
        token.approve(address(positionManager), type(uint256).max);
        vm.stopPrank();

        // Register vaults in registry
        vm.startPrank(deployer);
        try registry.registerVault(DEST_CHAIN, address(vault)) {} catch {}
        try registry.registerVault(8453, address(vault)) {} catch {}
        try registry.registerVault(SOURCE_CHAIN, address(vault)) {} catch {}
        vm.stopPrank();

        // Create positions for tokenPool for all chains
        vm.startPrank(address(token));

        // Create position for DEST_CHAIN if it doesn't exist
        bytes32 destPositionKey = positionManager.getPositionKey(tokenPool, SOURCE_CHAIN, DEST_CHAIN, address(vault));
        if (!positionManager.isPositionActive(destPositionKey)) {
            positionManager.createPosition(
                tokenPool, // owner
                SOURCE_CHAIN, // sourceChain
                DEST_CHAIN, // destinationChain
                address(vault), // destinationVault
                POSITION_SIZE // shares
            );
        }

        // Create position for SOURCE_CHAIN if it doesn't exist
        bytes32 sourcePositionKey =
            positionManager.getPositionKey(tokenPool, SOURCE_CHAIN, SOURCE_CHAIN, address(vault));
        if (!positionManager.isPositionActive(sourcePositionKey)) {
            positionManager.createPosition(
                tokenPool, // owner
                SOURCE_CHAIN, // sourceChain
                SOURCE_CHAIN, // destinationChain
                address(vault), // destinationVault
                POSITION_SIZE // shares
            );
        }

        // Create position for chain 8453 if it doesn't exist
        bytes32 basePositionKey = positionManager.getPositionKey(tokenPool, SOURCE_CHAIN, 8453, address(vault));
        if (!positionManager.isPositionActive(basePositionKey)) {
            positionManager.createPosition(
                tokenPool, // owner
                SOURCE_CHAIN, // sourceChain
                8453, // destinationChain
                address(vault), // destinationVault
                POSITION_SIZE // shares
            );
        }
        vm.stopPrank();
    }

    // View Function Tests
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

    // Replace rate limit tests with max transaction size tests
    function test_MaxTransactionSize() public {
        // Test mint with PositionManager
        vm.startPrank(address(positionManager));
        token.mint(user1, VALID_AMOUNT); // Should succeed

        vm.expectRevert(Errors.ExceedsMaxSize.selector);
        token.mint(user1, EXCEEDS_MAX);
        vm.stopPrank();

        // Setup vault mapping if not already set
        vm.startPrank(deployer);
        try registry.registerVault(uint32(DEST_CHAIN), address(vault)) {} catch {}
        vm.stopPrank();

        vm.startPrank(ccipAdmin);
        token.setVaultMapping(uint32(DEST_CHAIN), tokenPool, address(vault));
        vm.stopPrank();

        // Test lockOrBurn with tokenPool
        // First mint some tokens to tokenPool
        vm.prank(address(positionManager));
        token.mint(tokenPool, VALID_AMOUNT * 2); // Mint enough for both tests

        vm.startPrank(tokenPool);

        // Test valid amount
        ICCTToken.LockOrBurnParams memory validParams = ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: VALID_AMOUNT,
            destinationChainSelector: uint64(DEST_CHAIN),
            receiver: user2,
            depositId: keccak256("test1")
        });
        token.lockOrBurn(validParams);

        // Test exceeding amount
        ICCTToken.LockOrBurnParams memory invalidParams = ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: EXCEEDS_MAX,
            destinationChainSelector: uint64(DEST_CHAIN),
            receiver: user2,
            depositId: keccak256("test2")
        });
        vm.expectRevert(Errors.ExceedsMaxSize.selector);
        token.lockOrBurn(invalidParams);

        vm.stopPrank();
    }

    // CCT Message Tests
    function test_CCTMessageId_Uniqueness() public {
        uint256 amount = 100e6; // Use smaller amount to stay within rate limit

        // First mint tokens to tokenPool
        vm.prank(address(positionManager));
        token.mint(tokenPool, amount * 2);

        // Setup vault for DEST_CHAIN if not already set
        vm.startPrank(deployer);
        try registry.registerVault(uint32(DEST_CHAIN), address(vault)) {} catch {}
        vm.stopPrank();

        vm.startPrank(tokenPool);

        bytes memory messageId1 = token.lockOrBurn(
            ICCTToken.LockOrBurnParams({
                sender: tokenPool,
                amount: amount,
                destinationChainSelector: uint64(DEST_CHAIN),
                receiver: user2,
                depositId: keccak256("test1")
            })
        );

        // Wait for rate limit to recover
        skip(2); // Skip 2 seconds to allow rate limit recovery

        bytes memory messageId2 = token.lockOrBurn(
            ICCTToken.LockOrBurnParams({
                sender: tokenPool,
                amount: amount,
                destinationChainSelector: uint64(DEST_CHAIN),
                receiver: user2,
                depositId: keccak256("test2")
            })
        );

        vm.stopPrank();

        assertNotEq(keccak256(messageId1), keccak256(messageId2));
    }

    function testFuzz_CCTMessageId_Uniqueness(uint96 amount1, uint96 amount2, uint32 destChain1, uint32 destChain2)
        public
    {
        // Bound the fuzz inputs to reasonable values
        amount1 = uint96(bound(uint256(amount1), 1e6, VALID_AMOUNT));
        amount2 = uint96(bound(uint256(amount2), 1e6, VALID_AMOUNT));
        destChain1 = uint32(bound(uint256(destChain1), 1, 100000));
        destChain2 = uint32(bound(uint256(destChain2), 1, 100000));

        vm.assume(amount1 > 0 && amount2 > 0);
        vm.assume(destChain1 > 0 && destChain2 > 0);

        // First mint tokens to tokenPool for the burns
        vm.prank(address(positionManager));
        token.mint(tokenPool, uint256(amount1) + uint256(amount2));

        // Register vaults for the fuzzed chain IDs
        vm.startPrank(deployer);
        try registry.registerVault(destChain1, address(vault)) {} catch {}
        try registry.registerVault(destChain2, address(vault)) {} catch {}
        vm.stopPrank();

        // Configure vault mappings for the fuzzed chains
        vm.startPrank(ccipAdmin);
        token.setVaultMapping(destChain1, tokenPool, address(vault));
        token.setVaultMapping(destChain2, tokenPool, address(vault));
        vm.stopPrank();

        // Create positions for both chains
        vm.startPrank(address(token)); // token is a handler

        // Create position for destChain1
        bytes32 positionKey1 = positionManager.getPositionKey(tokenPool, SOURCE_CHAIN, destChain1, address(vault));
        if (!positionManager.isPositionActive(positionKey1)) {
            positionManager.createPosition(
                tokenPool, // owner
                SOURCE_CHAIN, // sourceChain
                destChain1, // destinationChain
                address(vault), // destinationVault
                VALID_AMOUNT // shares
            );
        }

        // Create position for destChain2
        bytes32 positionKey2 = positionManager.getPositionKey(tokenPool, SOURCE_CHAIN, destChain2, address(vault));
        if (!positionManager.isPositionActive(positionKey2)) {
            positionManager.createPosition(
                tokenPool, // owner
                SOURCE_CHAIN, // sourceChain
                destChain2, // destinationChain
                address(vault), // destinationVault
                VALID_AMOUNT // shares
            );
        }
        vm.stopPrank();

        vm.startPrank(tokenPool);

        bytes memory messageId1 = token.lockOrBurn(
            ICCTToken.LockOrBurnParams({
                sender: tokenPool,
                amount: amount1,
                destinationChainSelector: uint64(destChain1),
                receiver: user1,
                depositId: keccak256("test1")
            })
        );

        // Advance block timestamp to ensure different message IDs
        skip(1);

        bytes memory messageId2 = token.lockOrBurn(
            ICCTToken.LockOrBurnParams({
                sender: tokenPool,
                amount: amount2,
                destinationChainSelector: uint64(destChain2),
                receiver: user1,
                depositId: keccak256("test2")
            })
        );

        vm.stopPrank();

        assertNotEq(keccak256(messageId1), keccak256(messageId2));
    }

    // Edge Cases and Error Tests
    function test_RevertCCTMint_ZeroAmount() public {
        vm.startPrank(tokenPool);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroNumber.selector, 0));
        token.releaseOrMint(
            ICCTToken.ReleaseOrMintParams({
                sourceChainSelector: uint64(SOURCE_CHAIN),
                receiver: user2,
                amount: 0, // Zero amount
                depositId: keccak256("test")
            })
        );
        vm.stopPrank();
    }

    function test_RevertCCTBurn_ZeroAmount() public {
        vm.startPrank(tokenPool);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroNumber.selector, 0));
        token.lockOrBurn(
            ICCTToken.LockOrBurnParams({
                sender: tokenPool,
                amount: 0, // Zero amount
                destinationChainSelector: uint64(DEST_CHAIN),
                receiver: user2,
                depositId: keccak256("test")
            })
        );
        vm.stopPrank();
    }

    function test_RevertCCTMint_ZeroAddress() public {
        vm.startPrank(tokenPool);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        token.releaseOrMint(
            ICCTToken.ReleaseOrMintParams({
                sourceChainSelector: uint64(SOURCE_CHAIN),
                receiver: address(0), // Zero address
                amount: POSITION_SIZE,
                depositId: keccak256("test")
            })
        );
        vm.stopPrank();
    }

    function test_RevertCCTBurn_ZeroAddress() public {
        uint256 amount = POSITION_SIZE;

        vm.startPrank(tokenPool);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, address(0)));
        token.lockOrBurn(
            ICCTToken.LockOrBurnParams({
                sender: tokenPool,
                amount: amount,
                destinationChainSelector: uint64(DEST_CHAIN),
                receiver: address(0), // Zero address
                depositId: keccak256("test")
            })
        );
        vm.stopPrank();
    }

    function test_RevertCCTBurn_InsufficientBalance() public {
        vm.startPrank(ccipAdmin);
        token.configureTokenPool(tokenPool, true);
        vm.stopPrank();

        // Ensure user1 has zero balance
        vm.startPrank(user1);
        uint256 currentBalance = token.balanceOf(user1);
        if (currentBalance > 0) {
            token.burn(currentBalance);
        }
        token.approve(tokenPool, type(uint256).max);
        vm.stopPrank();

        // Try to burn without having any balance
        vm.startPrank(tokenPool);
        vm.expectRevert(bytes4(0xf4d678b8)); // InsufficientBalance error selector from Solady ERC20
        token.burnFrom(user1, POSITION_SIZE);
        vm.stopPrank();
    }

    // Role Management Tests
    function test_ConfigureMinter() public {
        address newMinter = makeAddr("newMinter");

        vm.startPrank(deployer);
        token.configureMinter(newMinter, true);
        assertTrue(token.minters(newMinter));

        token.configureMinter(newMinter, false);
        assertFalse(token.minters(newMinter));
        vm.stopPrank();
    }

    function test_ConfigureBurner() public {
        address newBurner = makeAddr("newBurner");

        vm.startPrank(deployer);
        token.configureBurner(newBurner, true);
        assertTrue(token.burners(newBurner));

        token.configureBurner(newBurner, false);
        assertFalse(token.burners(newBurner));
        vm.stopPrank();
    }

    function test_ConfigureTokenPool() public {
        address newPool = makeAddr("newPool");

        vm.startPrank(ccipAdmin);
        token.configureTokenPool(newPool, true);
        assertTrue(token.tokenPools(newPool));
        assertTrue(token.minters(newPool));
        assertTrue(token.burners(newPool));

        token.configureTokenPool(newPool, false);
        assertFalse(token.tokenPools(newPool));
        assertFalse(token.minters(newPool));
        assertFalse(token.burners(newPool));
        vm.stopPrank();
    }

    function test_SetCCIPAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.startPrank(deployer);
        token.setCCIPAdmin(newAdmin);
        assertEq(token.getCCIPAdmin(), newAdmin);
        vm.stopPrank();
    }

    function test_RevertUnauthorizedRoleManagement() public {
        address newAddr = makeAddr("newAddr");

        vm.startPrank(user1);
        vm.expectRevert(Errors.NotCCIPAdmin.selector);
        token.configureTokenPool(newAddr, true);
        vm.stopPrank();
    }

    // Remote Pool Tests
    function test_SetRemotePool() public {
        vm.startPrank(ccipAdmin);
        token.configureTokenPool(tokenPool, true);
        assertTrue(token.tokenPools(tokenPool));
        assertTrue(token.minters(tokenPool));
        assertTrue(token.burners(tokenPool));

        token.configureTokenPool(tokenPool, false);
        assertFalse(token.tokenPools(tokenPool));
        assertFalse(token.minters(tokenPool));
        assertFalse(token.burners(tokenPool));
        vm.stopPrank();
    }

    function test_RevertUnauthorizedRemotePool() public {
        vm.startPrank(address(0xbad)); // Unauthorized address
        vm.expectRevert(Errors.NotTokenPool.selector);
        token.releaseOrMint(
            ICCTToken.ReleaseOrMintParams({
                sourceChainSelector: uint64(SOURCE_CHAIN),
                receiver: user2,
                amount: POSITION_SIZE,
                depositId: keccak256("test")
            })
        );
        vm.stopPrank();
    }

    // Basic Token Operation Tests
    function test_BasicMint() public {
        uint256 amount = POSITION_SIZE;
        uint256 initialBalance = token.balanceOf(user1);

        vm.prank(address(positionManager));
        token.mint(user1, amount);

        assertEq(token.balanceOf(user1), initialBalance + amount);
    }

    function test_BasicBurn() public {
        uint256 amount = POSITION_SIZE;

        // First mint tokens to user1
        vm.prank(address(positionManager));
        token.mint(user1, amount);

        uint256 initialBalance = token.balanceOf(user1);

        vm.prank(user1);
        token.burn(amount);

        assertEq(token.balanceOf(user1), initialBalance - amount);
    }

    function test_Burn() public {
        uint256 amount = POSITION_SIZE;

        // First mint some tokens to positionManager
        vm.prank(address(positionManager));
        token.mint(address(positionManager), amount);

        // Then burn them
        vm.prank(address(positionManager));
        token.burn(amount);
    }

    function test_BurnWithRateLimit() public {
        uint256 amount = POSITION_SIZE;

        // First mint some tokens
        vm.prank(address(positionManager));
        token.mint(address(positionManager), amount);

        // Then burn them
        vm.prank(address(positionManager));
        token.burn(amount);
    }

    // CCT Tests
    function test_CCT_LockOrBurn_MaxSize() public {
        // Setup vault mapping if not already set
        vm.startPrank(deployer);
        try registry.registerVault(uint32(DEST_CHAIN), address(vault)) {} catch {}
        vm.stopPrank();

        vm.startPrank(ccipAdmin);
        token.setVaultMapping(uint32(DEST_CHAIN), tokenPool, address(vault));
        vm.stopPrank();

        // First mint tokens to tokenPool
        vm.prank(address(positionManager));
        token.mint(tokenPool, VALID_AMOUNT * 2); // Mint enough for both tests

        vm.startPrank(tokenPool);

        // First try with valid amount
        ICCTToken.LockOrBurnParams memory validParams = ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: VALID_AMOUNT,
            destinationChainSelector: uint64(DEST_CHAIN),
            receiver: user2,
            depositId: keccak256("test1")
        });
        token.lockOrBurn(validParams);

        // Then try with amount exceeding max size
        ICCTToken.LockOrBurnParams memory invalidParams = ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: EXCEEDS_MAX,
            destinationChainSelector: uint64(DEST_CHAIN),
            receiver: user2,
            depositId: keccak256("test2")
        });
        vm.expectRevert(Errors.ExceedsMaxSize.selector);
        token.lockOrBurn(invalidParams);

        vm.stopPrank();
    }

    function test_CCT_ReleaseOrMint_MaxSize() public {
        vm.startPrank(tokenPool);

        // First try with valid amount
        ICCTToken.ReleaseOrMintParams memory validParams = ICCTToken.ReleaseOrMintParams({
            depositId: keccak256("test1"),
            receiver: tokenPool,
            amount: VALID_AMOUNT,
            sourceChainSelector: uint64(SOURCE_CHAIN)
        });
        token.releaseOrMint(validParams);

        // Then try with amount exceeding max size
        ICCTToken.ReleaseOrMintParams memory invalidParams = ICCTToken.ReleaseOrMintParams({
            depositId: keccak256("test2"),
            receiver: tokenPool,
            amount: EXCEEDS_MAX,
            sourceChainSelector: uint64(SOURCE_CHAIN)
        });
        vm.expectRevert(Errors.ExceedsMaxSize.selector);
        token.releaseOrMint(invalidParams);

        vm.stopPrank();
    }

    function test_CCT_PositionUpdate() public {
        // First mint tokens to tokenPool
        vm.prank(address(positionManager));
        token.mint(tokenPool, VALID_AMOUNT * 2);

        vm.startPrank(tokenPool);

        // Test lockOrBurn position update
        ICCTToken.LockOrBurnParams memory burnParams = ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: VALID_AMOUNT,
            destinationChainSelector: uint64(DEST_CHAIN),
            receiver: user2,
            depositId: keccak256("test1")
        });
        token.lockOrBurn(burnParams);

        // Test releaseOrMint position update
        ICCTToken.ReleaseOrMintParams memory mintParams = ICCTToken.ReleaseOrMintParams({
            depositId: keccak256("test2"),
            receiver: tokenPool,
            amount: VALID_AMOUNT,
            sourceChainSelector: uint64(SOURCE_CHAIN)
        });
        token.releaseOrMint(mintParams);

        vm.stopPrank();
    }

    // Test mint
    function test_Mint_MaxSize() public {
        vm.startPrank(address(positionManager));

        // Test valid amount
        token.mint(user1, VALID_AMOUNT);

        // Test amount exceeding max size
        vm.expectRevert(Errors.ExceedsMaxSize.selector);
        token.mint(user1, EXCEEDS_MAX);

        vm.stopPrank();
    }

    function test_CrossChainMint() public {
        vm.startPrank(deployer);
        try registry.registerVault(uint32(SOURCE_CHAIN), address(vault)) {} catch {}
        vm.stopPrank();

        vm.startPrank(tokenPool);

        ICCTToken.ReleaseOrMintParams memory params = ICCTToken.ReleaseOrMintParams({
            depositId: keccak256("test"),
            receiver: tokenPool,
            amount: VALID_AMOUNT,
            sourceChainSelector: uint64(SOURCE_CHAIN)
        });

        token.releaseOrMint(params);

        vm.stopPrank();
    }

    function test_CrossChainBurn() public {
        // First mint tokens to tokenPool
        vm.prank(address(positionManager));
        token.mint(tokenPool, VALID_AMOUNT);

        vm.startPrank(deployer);
        try registry.registerVault(uint32(DEST_CHAIN), address(vault)) {} catch {}
        vm.stopPrank();

        vm.startPrank(tokenPool);

        ICCTToken.LockOrBurnParams memory params = ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: VALID_AMOUNT,
            destinationChainSelector: uint64(DEST_CHAIN),
            receiver: user1,
            depositId: keccak256("test")
        });

        bytes memory messageId = token.lockOrBurn(params);

        vm.stopPrank();
    }

    // Add test for duplicate message prevention
    function test_DuplicateMessagePrevention() public {
        bytes32 messageId = keccak256("test");

        vm.startPrank(tokenPool);

        // First mint should succeed
        token.releaseOrMint(
            ICCTToken.ReleaseOrMintParams({
                depositId: messageId,
                receiver: user1,
                amount: VALID_AMOUNT,
                sourceChainSelector: uint64(SOURCE_CHAIN)
            })
        );

        // Second mint with same message ID should fail with DuplicateMessage
        vm.expectRevert(Errors.DuplicateMessage.selector);
        token.releaseOrMint(
            ICCTToken.ReleaseOrMintParams({
                depositId: messageId, // Same message ID
                receiver: user1,
                amount: VALID_AMOUNT,
                sourceChainSelector: uint64(SOURCE_CHAIN)
            })
        );

        vm.stopPrank();
    }
}
