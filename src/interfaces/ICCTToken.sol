// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICCTToken {
    struct LockOrBurnParams {
        address sender;
        uint256 amount;
        uint64 destinationChainSelector;
        address receiver;
        bytes32 depositId;
    }

    struct ReleaseOrMintParams {
        address receiver;
        uint256 amount;
        uint64 sourceChainSelector;
        bytes32 depositId;
    }

    function lockOrBurn(LockOrBurnParams calldata params) external returns (bytes memory message);
    function releaseOrMint(ReleaseOrMintParams calldata params) external returns (uint256);
}
