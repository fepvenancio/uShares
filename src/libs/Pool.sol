// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Pool
 * @notice Library containing structs for Chainlink's Cross-Chain Token (CCT) standard
 */
library Pool {
    // The tag used to signal support for the pool v1 standard.
    // bytes4(keccak256("CCIP_POOL_V1"))
    bytes4 public constant CCIP_POOL_V1 = 0xaff2afbf;

    // The number of bytes in the return data for a pool v1 releaseOrMint call.
    // This should match the size of the ReleaseOrMintOutV1 struct.
    uint16 public constant CCIP_POOL_V1_RET_BYTES = 32;

    // The default max number of bytes in the return data for a pool v1 lockOrBurn call.
    // This data can be used to send information to the destination chain token pool. Can be overwritten
    // in the TokenTransferFeeConfig.destBytesOverhead if more data is required.
    uint32 public constant CCIP_LOCK_OR_BURN_V1_RET_BYTES = 32;

    /**
     * @notice Rate limit configuration for a chain
     * @param rate Tokens per second refill rate
     * @param capacity Maximum capacity
     * @param currentTokens Current available tokens
     * @param lastUpdated Last update timestamp
     */
    struct RateLimitConfig {
        uint256 rate;
        uint256 capacity;
        uint256 currentTokens;
        uint256 lastUpdated;
    }

    struct Message {
        uint64 sourceChainSelector;  // Chain selector of the source chain
        address sender;              // Address of the sender on the source chain
        address receiver;            // Address of the receiver on the destination chain
        bytes data;                  // Arbitrary message data
        address feeToken;            // Token used to pay fees (if any)
        uint256 feeAmount;          // Amount of fees paid
    }

    /**
     * @notice Input parameters for lockOrBurn operation
     * @param localToken Local token address
     * @param remoteChainSelector Remote chain selector
     * @param amount Amount to lock/burn
     * @param originalSender Original sender address
     */
    struct LockOrBurnInV1 {
        bytes receiver;            // The recipient of the tokens on the destination chain, abi encoded
        uint64 remoteChainSelector; // The chain ID of the destination chain
        address originalSender;    // The original sender of the tx on the source chain
        uint256 amount;           // The amount of tokens to lock or burn, denominated in the source token's decimals
        address localToken;       // The address on this chain of the token to lock or burn
    }

    /**
     * @notice Output parameters from lockOrBurn operation
     * @param destTokenAddress Destination token address
     * @param destPoolData Encoded data for destination pool
     */
    struct LockOrBurnOutV1 {
        bytes destTokenAddress;   // The address of the destination token, abi encoded in the case of EVM chains.
                                // This value is UNTRUSTED as any pool owner can return whatever value they want.
        bytes destPoolData;      // Optional pool data to be transferred to the destination chain. Be default this is capped at
                                // CCIP_LOCK_OR_BURN_V1_RET_BYTES bytes. If more data is required, the TokenTransferFeeConfig.destBytesOverhead
                                // has to be set for the specific token.
    }

    /**
     * @notice Input parameters for releaseOrMint operation
     * @param localToken Local token address
     * @param remoteChainSelector Remote chain selector
     * @param amount Amount to release/mint
     * @param receiver Receiver address
     * @param sourcePoolAddress Source pool address
     * @param originalSender Original sender address
     */
    struct ReleaseOrMintInV1 {
        bytes originalSender;         // The original sender of the tx on the source chain
        uint64 remoteChainSelector;   // The chain ID of the source chain
        address receiver;             // The recipient of the tokens on the destination chain
        uint256 amount;              // The amount of tokens to release or mint, denominated in the source token's decimals
        address localToken;          // The address on this chain of the token to release or mint
        bytes sourcePoolAddress;     // The address of the source pool, abi encoded in the case of EVM chains.
                                    // WARNING: sourcePoolAddress should be checked prior to any processing of funds.
                                    // Make sure it matches the expected pool address for the given remoteChainSelector.
        bytes sourcePoolData;        // The data received from the source pool to process the release or mint
        bytes offchainTokenData;     // The offchain data to process the release or mint.
                                    // WARNING: offchainTokenData is untrusted data.
    }

    /**
     * @notice Output parameters from releaseOrMint operation
     * @param amount Amount released/minted
     */
    struct ReleaseOrMintOutV1 {
        uint256 destinationAmount;    // The number of tokens released or minted on the destination chain, denominated in the local token's decimals.
                                     // This value is expected to be equal to the ReleaseOrMintInV1.amount in the case where the source and destination
                                     // chain have the same number of decimals.
    }
} 