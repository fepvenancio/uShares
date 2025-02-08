// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Errors} from "./Errors.sol";

/**
 * @title RateLimiter
 * @notice Library for implementing token bucket rate limiting
 */
library RateLimiter {
    struct TokenBucket {
        uint256 rate;        // Tokens per second
        uint256 capacity;    // Maximum burst capacity
        uint256 tokens;      // Current token balance
        uint32 lastUpdated;  // Last update timestamp
        bool isEnabled;      // Whether rate limiting is enabled
    }

    struct Config {
        uint256 rate;        // Tokens per second
        uint256 capacity;    // Maximum burst capacity
        bool isEnabled;      // Whether rate limiting is enabled
    }

    /**
     * @notice Validates a token bucket configuration
     * @param config The configuration to validate
     * @param allowDisabled Whether to allow disabled rate limiting
     */
    function _validateTokenBucketConfig(Config memory config, bool allowDisabled) internal pure {
        if (!allowDisabled && !config.isEnabled) revert Errors.InvalidConfig();
        if (config.rate == 0) revert Errors.InvalidConfig();
        if (config.capacity == 0) revert Errors.InvalidConfig();
        if (config.capacity < config.rate) revert Errors.InvalidConfig();
    }

    /**
     * @notice Gets the current state of a token bucket
     * @param bucket The token bucket to check
     * @return The current token bucket state
     */
    function _currentTokenBucketState(TokenBucket storage bucket) internal view returns (TokenBucket memory) {
        if (!bucket.isEnabled) {
            return bucket;
        }

        uint256 timePassed = block.timestamp - bucket.lastUpdated;
        uint256 newTokens = timePassed * bucket.rate;
        uint256 currentTokens = Math.min(
            bucket.capacity,
            bucket.tokens + newTokens
        );

        return TokenBucket({
            rate: bucket.rate,
            capacity: bucket.capacity,
            tokens: currentTokens,
            lastUpdated: uint32(block.timestamp),
            isEnabled: bucket.isEnabled
        });
    }

    /**
     * @notice Consumes tokens from a bucket
     * @param bucket The token bucket to consume from
     * @param amount The amount of tokens to consume
     * @param tokenAddress The address of the token for error messages
     */
    function _consume(TokenBucket storage bucket, uint256 amount, address tokenAddress) internal {
        if (!bucket.isEnabled) {
            return;
        }

        TokenBucket memory current = _currentTokenBucketState(bucket);
        if (amount > current.tokens) {
            revert Errors.RateLimitExceeded(tokenAddress, amount, current.tokens);
        }

        bucket.tokens = current.tokens - amount;
        bucket.lastUpdated = uint32(block.timestamp);
    }
}

library Math {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
} 