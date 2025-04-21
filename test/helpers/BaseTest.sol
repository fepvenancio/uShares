// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test, Vm } from "forge-std/Test.sol";
import { Utils } from "./Utils.sol";
import { getTokensList } from "./Tokens.sol";

contract BaseTest is Test {
    struct Users {
        address admin;
        address handler;
        address user;
        address vault;
        address alice;
        address bob;
        address charlie;
        address keeper;
    }

    Users public users;
    Utils public utils;
    uint32 public sourceChain;
    uint32 public destinationChain;
    address public relayer;
    uint256 public initialShares;
    uint256 public chainFork;
    uint256 public relayerKey;

    function _setUp(string memory chain, uint256 forkBlock) internal virtual {
         if (vm.envOr("FORK", false)) {
            string memory rpc = vm.envString(string.concat("RPC_", chain));
            chainFork = vm.createSelectFork(rpc);
            vm.rollFork(forkBlock);
        }
        // Setup utils
        utils = new Utils();

        address[] memory tokens = getTokensList(chain);

        (relayer, relayerKey) = makeAddrAndKey("Relayer");
        // Create users for testing
        users = Users({
            admin: makeAddr("admin"),
            handler: makeAddr("handler"),
            user: makeAddr("user"),
            vault: makeAddr("vault"),
            alice: makeAddr("alice"),
            bob: makeAddr("bob"),
            charlie: makeAddr("charlie"),
            keeper: makeAddr("keeper")
        });

        sourceChain = 8453;
        destinationChain = 10;
        initialShares = 1000;
    }

    // Helper to assert relative approximate equality
    function assertRelApproxEq(
        uint256 a,
        uint256 b,
        uint256 maxPercentDelta // An 18 decimal fixed point number, where 1e18 == 100%
    ) internal virtual {
        if (b == 0) return assertEq(a, b); // If the expected is 0, actual must be too.

        uint256 percentDelta = ((a > b ? a - b : b - a) * 1e18) / b;

        if (percentDelta > maxPercentDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("    Expected", b);
            emit log_named_uint("      Actual", a);
            emit log_named_decimal_uint(" Max % Delta", maxPercentDelta, 18);
            emit log_named_decimal_uint("     % Delta", percentDelta, 18);
            fail();
        }
    }

    // Helper to assert approximate equality with absolute delta
    function assertApproxEq(uint256 a, uint256 b, uint256 maxDelta) internal virtual {
        uint256 delta = a > b ? a - b : b - a;

        if (delta > maxDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("  Expected", b);
            emit log_named_uint("    Actual", a);
            emit log_named_uint(" Max Delta", maxDelta);
            emit log_named_uint("     Delta", delta);
            fail();
        }
    }

    // Helper to subtract with underflow protection
    function _sub0(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return a - b > a ? 0 : a - b;
        }
    }
} 