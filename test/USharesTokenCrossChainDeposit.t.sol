// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {USharesToken} from "../src/USharesToken.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {MockCCTP} from "./mocks/MockCCTP.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockVaultRegistry} from "./mocks/MockVaultRegistry.sol";
import {MockPositionManager} from "./mocks/MockPositionManager.sol";

contract USharesTokenCrossChainDepositTest is Test {
    // Constants for chain IDs
    uint32 constant SOURCE_CHAIN = 1; // Ethereum
    uint32 constant DEST_CHAIN = 8453; // Base

    // Test accounts
    address deployer = makeAddr("deployer");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address ccipAdmin = makeAddr("ccipAdmin");

    // Contracts
    USharesToken public token;
    PositionManager public positionManager;
    MockCCTP public mockCctp;
    MockRouter public mockRouter;
    MockUSDC public usdc;
    MockVaultRegistry public mockRegistry;
    MockPositionManager public mockPositions;

    // Constants
    uint256 constant INITIAL_BALANCE = 1_000_000e6; // 1M USDC

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy mock contracts
        usdc = new MockUSDC();
        mockCctp = new MockCCTP(address(usdc), SOURCE_CHAIN);
        mockRouter = new MockRouter();
        mockRegistry = new MockVaultRegistry();
        mockPositions = new MockPositionManager();

        // Deploy USharesToken
        token = new USharesToken(
            "uShares",
            "uSHR",
            SOURCE_CHAIN,
            address(mockPositions),
            ccipAdmin,
            address(mockCctp),
            address(usdc),
            address(mockRouter)
        );

        // Configure mocks
        mockCctp.setMinterAllowance(address(token), INITIAL_BALANCE);
        mockRouter.setTokenPool(address(token), address(mockCctp));

        // Fund test accounts
        usdc.mint(user1, INITIAL_BALANCE);
        usdc.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();
    }

    // Add your test functions here
}
