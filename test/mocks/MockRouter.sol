// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IRouter} from "../../src/interfaces/IRouter.sol";

contract MockRouter is IRouter {
    mapping(bytes32 => bool) public sentMessages;

    error InvalidAddress();

    function ccipSend(uint64 destinationChainSelector, bytes memory message) external returns (bytes32) {
        // Validate inputs
        if (msg.sender == address(0)) revert InvalidAddress();

        bytes32 messageId = keccak256(abi.encode(destinationChainSelector, message));
        sentMessages[messageId] = true;
        return messageId;
    }

    function getSentMessage(bytes32 messageId) external view returns (bool) {
        return sentMessages[messageId];
    }
}
