// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title UShares UpgradeableProxy
 * @author filipeVenancio
 * @notice Transparent upgradeable proxy
 */
contract USharesUpgradeableProxy is TransparentUpgradeableProxy {
    constructor(
        address _implementation,
        address _admin,
        bytes memory _data
    )
        TransparentUpgradeableProxy(_implementation, _admin, _data)
    { }
}
