// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IRouter} from "../../src/interfaces/IRouter.sol";

contract MockRouter is IRouter {
    mapping(address => address) public tokenPools;

    function setTokenPool(address token, address pool) external {
        tokenPools[token] = pool;
    }

    function getTokenPool(address token) external view returns (address) {
        return tokenPools[token];
    }

    function isTokenPoolEnabled(address token) external view returns (bool) {
        return tokenPools[token] != address(0);
    }

    function ccipSend(uint64 destinationChainSelector, bytes memory message) external override returns (bytes32) {
        return bytes32(uint256(1)); // Return a dummy message ID
    }

    function ccipReceive(
        bytes32 messageId,
        bytes memory message
    ) external {
        // Do nothing for testing
    }
}
