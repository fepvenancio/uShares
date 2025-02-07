// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DataTypes} from "../types/DataTypes.sol";

interface ICCTToken {
    function lockOrBurn(DataTypes.LockOrBurnParams calldata params) external returns (bytes memory message);
    function releaseOrMint(DataTypes.ReleaseOrMintParams calldata params) external returns (uint256);
}
