// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {USharesToken} from "../../src/USharesToken.sol";
import {VaultRegistry} from "../../src/VaultRegistry.sol";
import {PositionManager} from "../../src/PositionManager.sol";
import {Pool} from "../../src/libs/Pool.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockVault} from "../mocks/MockVault.sol";
import {MockRouter} from "../mocks/MockRouter.sol";
import {MockTokenPool} from "../mocks/MockTokenPool.sol";

contract BaseTest is Test {
    // Chain IDs
    uint256 constant BASE_CHAIN = 8453;
    uint256 constant OPTIMISM_CHAIN = 10;

    // Test accounts
    address admin = makeAddr("admin");
    address user = makeAddr("user");

    // Base chain contracts
    USharesToken baseToken;
    MockUSDC baseUSDC;
    MockVault baseVault;
    MockRouter baseRouter;
    MockTokenPool baseTokenPool;
    VaultRegistry baseRegistry;

    // Optimism chain contracts
    USharesToken optimismToken;
    MockUSDC optimismUSDC;
    MockVault optimismVault;
    MockRouter optimismRouter;
    MockTokenPool optimismTokenPool;
    VaultRegistry optimismRegistry;

    function setUp() public virtual {
        vm.startPrank(admin);

        // Deploy Base chain contracts
        baseUSDC = new MockUSDC();
        baseVault = new MockVault(address(baseUSDC));
        baseRouter = new MockRouter();
        baseTokenPool = new MockTokenPool(address(baseUSDC));
        baseRegistry = new VaultRegistry();
        baseToken = new USharesToken(
            "uShares Base",
            "uSHR",
            BASE_CHAIN,
            address(baseRegistry),
            admin,
            address(baseTokenPool),
            address(baseUSDC),
            address(baseRouter)
        );

        // Deploy Optimism chain contracts
        optimismUSDC = new MockUSDC();
        optimismVault = new MockVault(address(optimismUSDC));
        optimismRouter = new MockRouter();
        optimismTokenPool = new MockTokenPool(address(optimismUSDC));
        optimismRegistry = new VaultRegistry();
        optimismToken = new USharesToken(
            "uShares Optimism",
            "uSHR",
            OPTIMISM_CHAIN,
            address(optimismRegistry),
            admin,
            address(optimismTokenPool),
            address(optimismUSDC),
            address(optimismRouter)
        );

        // Configure Base chain
        baseRegistry.addVault(address(baseVault));
        baseRouter.setTokenPool(address(baseToken), address(baseTokenPool));
        baseTokenPool.setRouter(address(baseRouter));

        // Configure Optimism chain
        optimismRegistry.addVault(address(optimismVault));
        optimismRouter.setTokenPool(address(optimismToken), address(optimismTokenPool));
        optimismTokenPool.setRouter(address(optimismRouter));

        vm.stopPrank();
    }

    function _sendMessageBaseToOptimism(bytes memory message) internal {
        bytes32 messageId = baseRouter.ccipSend(OPTIMISM_CHAIN, address(optimismToken), message);
        optimismRouter.mockReceiveMessage(messageId, BASE_CHAIN, address(baseToken), message);
    }

    function _sendMessageOptimismToBase(bytes memory message) internal {
        bytes32 messageId = optimismRouter.ccipSend(BASE_CHAIN, address(baseToken), message);
        baseRouter.mockReceiveMessage(messageId, OPTIMISM_CHAIN, address(optimismToken), message);
    }
}
