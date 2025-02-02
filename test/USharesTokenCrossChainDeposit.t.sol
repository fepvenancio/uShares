// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./base/BaseTest.t.sol";
import {USharesToken} from "../src/USharesToken.sol";
import {Errors} from "../src/libs/Errors.sol";
import {ICCTToken} from "../src/interfaces/ICCTToken.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockCCTP} from "./mocks/MockCCTP.sol";

// Constants for chain IDs
uint32 constant CHAIN_ID = 1; // Ethereum mainnet
uint32 constant SOURCE_CHAIN = 1; // Ethereum mainnet
uint32 constant DEST_CHAIN = 43114; // Avalanche C-Chain

contract USharesTokenCrossChainDepositTest is BaseTest {
    // Contract instances
    USharesToken public token;
    MockRouter public mockRouter;
    PositionManager public positionManager;
    MockCCTP public mockCctp;
    
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
        mockRouter = new MockRouter();
        mockCctp = new MockCCTP();
        
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

        // Configure vault mappings - use tokenPool as local vault since it's the msg.sender in lockOrBurn
        token.setVaultMapping(8453, tokenPool, address(vault));
        vm.stopPrank();

        // Setup vault mapping for cross-chain tests
        vm.startPrank(deployer);
        registry.registerVault(8453, address(vault));
        vm.stopPrank();
    }

    function test_CCTMessageId_Uniqueness() public {
        uint256 amount = 1000e6;
        
        // First mint tokens to tokenPool
        vm.prank(address(positionManager));
        token.mint(tokenPool, amount * 2);

        // Ensure tokenPool has proper permissions
        vm.startPrank(ccipAdmin);
        token.configureTokenPool(tokenPool, true);
        vm.stopPrank();
        
        // Create position for tokenPool
        vm.startPrank(address(token));  // Use token instead of deployer since it's already a handler
        // Create position directly without storing the key
        positionManager.createPosition(
            tokenPool,          // owner
            SOURCE_CHAIN,       // sourceChain
            8453,              // destinationChain
            address(vault),    // destinationVault
            amount * 2         // shares
        );
        vm.stopPrank();
        
        vm.startPrank(tokenPool);
        
        bytes memory messageId1 = token.lockOrBurn(ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: amount,
            destinationChainSelector: uint64(8453),
            receiver: user2,
            depositId: keccak256("test1")
        }));
        
        // Advance block timestamp to ensure different message IDs
        skip(1000);
        
        bytes memory messageId2 = token.lockOrBurn(ICCTToken.LockOrBurnParams({
            sender: tokenPool,
            amount: amount,
            destinationChainSelector: uint64(8453),
            receiver: user2,
            depositId: keccak256("test2")  // Different depositId
        }));
        
        vm.stopPrank();
        
        assertNotEq(keccak256(messageId1), keccak256(messageId2));
    }
} 
