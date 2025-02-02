// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IRouter {
    function ccipSend(uint64 destinationChainSelector, bytes memory message) external returns (bytes32);
}
