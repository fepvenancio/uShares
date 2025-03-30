// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Pool {
    struct LockOrBurnInV1 {
        address localToken;    // The token being burned/locked
        uint256 amount;       // Amount of tokens
        uint64 remoteChainSelector;  // Destination chain ID
        address originalSender;     // Original sender of tokens
    }

    struct LockOrBurnOutV1 {
        bytes destTokenAddress;  // Token address on destination chain
        bytes destPoolData;     // Additional data for destination pool
    }
}

interface ITokenPool {
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) 
        external 
        returns (Pool.LockOrBurnOutV1 memory);
}
