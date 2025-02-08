// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IRouter} from "../../src/interfaces/IRouter.sol";

/**
 * @title MockRouter
 * @notice Simple mock implementation of CCT router for testing
 */
contract MockRouter is IRouter {
    // Track processed messages
    mapping(bytes32 => bool) public processedMessages;

    // Events
    event MessageSent(
        uint64 indexed destinationChainSelector,
        address indexed receiver,
        bytes data
    );

    /**
     * @notice Send a cross-chain message
     * @param destinationChainSelector Target chain selector
     * @param message Message data
     * @return messageId Generated message ID
     */
    function ccipSend(
        uint64 destinationChainSelector,
        bytes memory message
    ) external returns (bytes32) {
        bytes32 messageId = keccak256(abi.encode(
            destinationChainSelector,
            message,
            block.timestamp
        ));

        require(!processedMessages[messageId], "Duplicate message");
        processedMessages[messageId] = true;

        emit MessageSent(destinationChainSelector, msg.sender, message);
        return messageId;
    }

    /**
     * @notice Test helper to simulate receiving a message
     * @param messageId Message identifier
     * @param data Message data
     */
    function mockReceiveMessage(bytes32 messageId, bytes calldata data) external {
        require(!processedMessages[messageId], "Duplicate message");
        processedMessages[messageId] = true;
    }
}
