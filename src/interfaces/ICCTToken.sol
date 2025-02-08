// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Pool} from "../libs/Pool.sol";

/**
 * @title ICCTToken
 * @notice Interface for Chainlink's Cross-Chain Token (CCT) standard
 */
interface ICCTToken {
    /**
     * @notice Lock or burn tokens for cross-chain transfer
     * @param params Parameters for the lock/burn operation
     * @return Pool.LockOrBurnOutV1 Data for the destination chain
     */
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata params
    ) external returns (Pool.LockOrBurnOutV1 memory);

    /**
     * @notice Release or mint tokens from cross-chain transfer
     * @param params Parameters for the release/mint operation
     * @return Pool.ReleaseOrMintOutV1 Data about the released/minted tokens
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata params
    ) external returns (Pool.ReleaseOrMintOutV1 memory);
}
