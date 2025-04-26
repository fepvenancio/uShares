// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title UShares ProxyAdmin
 * @author filipeVenancio
 * @notice Proxy
 */
contract USharesProxyAdmin is ProxyAdmin {
    constructor(address owner) ProxyAdmin(owner) { }
}
