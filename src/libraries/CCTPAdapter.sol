// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "../interfaces/IERC20.sol";
import {IMessageTransmitter} from "../interfaces/IMessageTransmitter.sol";
import {ITokenMessenger} from "../interfaces/ITokenMessenger.sol";
import {ITokenMinter} from "../interfaces/ITokenMinter.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {CircleDomainIds} from "./CircleDomainIds.sol";

abstract contract CCTPAdapter {
    using SafeTransferLib for address;

    /**
     * @notice The official USDC contract address on this chain.
     * @dev Posted officially here: https://developers.circle.com/stablecoins/docs/usdc-on-main-networks
     */
    address public immutable usdc;

    /**
     * @notice The official Circle CCTP token bridge contract endpoint.
     * @dev Posted officially here: https://developers.circle.com/stablecoins/docs/evm-smart-contracts
     */
    ITokenMessenger public immutable cctpTokenMessenger;

    /**
     * @notice intiailizes the CircleCCTPAdapter contract.
     * @param _usdc USDC address on the current chain.
     * @param _cctpTokenMessenger TokenMessenger contract to bridge via CCTP. If the zero address is passed, CCTP bridging will be disabled.
     */
    constructor(address _usdc, ITokenMessenger _cctpTokenMessenger) {
        usdc = _usdc;
        cctpTokenMessenger = _cctpTokenMessenger;
    }

    /**
     * @notice Converts an address into a bytes32 representation.
     * @param _address Address to convert.
     * @return bytes32 representation of the address.
     */
    function _toBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    /**
     * @notice Returns whether or not the CCTP bridge is enabled.
     * @dev If the CCTPTokenMessenger is the zero address, CCTP bridging is disabled.
     */
    function _isCCTPEnabled() internal view returns (bool) {
        return address(cctpTokenMessenger) != address(0);
    }

    /**
     * @notice Transfers USDC from the current domain to the given address on the new domain.
     * @dev This function will revert if the CCTP bridge is disabled. I.e. if the zero address is passed to the constructor for the cctpTokenMessenger.
     * @param to Address to receive USDC on the new domain.
     * @param amount Amount of USDC to transfer.
     */
    function _transferUsdc(
        uint32 domainId,
        address to,
        uint256 amount
    ) internal {
        _transferUsdc(domainId, _toBytes32(to), amount);
    }

    /**
     * @notice Transfers USDC from the current domain to the given address on the new domain.
     * @dev This function will revert if the CCTP bridge is disabled. I.e. if the zero address is passed to the constructor for the cctpTokenMessenger.
     * @param to Address to receive USDC on the new domain represented as bytes32.
     * @param amount Amount of USDC to transfer.
     */
    function _transferUsdc(
        uint32 domainId,
        bytes32 to,
        uint256 amount
    ) internal {
        ITokenMinter cctpMinter = cctpTokenMessenger.localMinter();
        uint256 burnLimit = cctpMinter.burnLimitsPerMessage(address(usdc));

        uint256 batchCount = (amount + burnLimit - 1) / burnLimit;
        uint256 actualBatchCount = batchCount > 0 ? batchCount : 1;

        usdc.safeApproveWithRetry(address(cctpTokenMessenger), amount);
       
        // If amount is less than or equal to burn limit, transfer in one go
        if (amount <= burnLimit) {
            cctpTokenMessenger.depositForBurn(amount, domainId, to, address(usdc));
            return;
        }
        
        // Else or the rest of it, transfer in batches
        uint256 remaining = amount;
        unchecked {
            for (uint256 i = 0; i < actualBatchCount && remaining > 0; i++) {
                uint256 batchAmount = remaining > burnLimit ? burnLimit : remaining;
                cctpTokenMessenger.depositForBurn(batchAmount, domainId, to, address(usdc));
                remaining -= batchAmount;
            }
        }
    }
}
