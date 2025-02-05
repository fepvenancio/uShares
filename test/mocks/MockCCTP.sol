// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICCTP} from "../../src/interfaces/ICCTP.sol";

contract MockCCTP is ICCTP {
    // Events to match TokenMessenger events
    event DepositForBurn(
        uint64 indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller
    );

    event MintAndWithdraw(address indexed mintRecipient, uint256 amount, address indexed mintToken);

    // State variables
    mapping(bytes32 => bool) public messages;
    mapping(bytes32 => bool) public verifiedMessages;
    uint64 private nonce;

    // Track burned amounts
    mapping(address => uint256) public burnedAmounts;
    mapping(bytes32 => bool) public messageProcessed;

    function depositForBurn(
        uint256 amount,
        uint32 destinationChainId,
        bytes32 mintRecipient,
        address burnToken
    ) external override {
        require(amount > 0, "Amount must be nonzero");
        require(mintRecipient != bytes32(0), "Mint recipient must be nonzero");
        require(burnToken != address(0), "Invalid token");

        // Increment nonce for unique message ID
        nonce++;

        bytes32 messageHash = keccak256(abi.encode(amount, destinationChainId, mintRecipient, nonce));
        messages[messageHash] = true;

        // Track burned amount
        burnedAmounts[msg.sender] += amount;

        // Emit event matching Circle's TokenMessenger
        emit DepositForBurn(
            nonce,
            burnToken,
            amount,
            msg.sender,
            mintRecipient,
            destinationChainId,
            bytes32(0), // Mock destination messenger
            bytes32(0) // No specific caller required
        );
    }

    function receiveMessage(bytes memory message, bytes memory) external override returns (bool) {
        // Always return true for testing
        return true;
    }

    function verifyMessageHash(bytes memory message, bytes memory) external view override returns (bool) {
        // Always return true for testing
        return true;
    }

    // Helper function to get burned amount
    function getBurnedAmount(address account) external view returns (uint256) {
        return burnedAmounts[account];
    }
}
