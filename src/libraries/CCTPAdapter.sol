// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "../interfaces/IERC20.sol";
import {IMessageTransmitter} from "../interfaces/IMessageTransmitter.sol";
import {ITokenMessenger} from "../interfaces/ITokenMessenger.sol";
import {ITokenMinter} from "../interfaces/ITokenMinter.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {CircleDomainIds} from "./CircleDomainIds.sol";
import {IVaultRegistry} from "../interfaces/IVaultRegistry.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";

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

    /// @notice The message transmitter contract for cross-chain messaging
    IMessageTransmitter public immutable messageTransmitter;

    /// @notice The vault registry contract
    IVaultRegistry public immutable vaultRegistry;

    /**
     * @notice Event emitted when a cross-chain message is sent
     */
    event MessageSent(uint64 messageId, uint32 destinationDomain, bytes message);

    /**
     * @notice Event emitted when a cross-chain message is received
     */
    event MessageReceived(uint64 messageId, uint32 sourceDomain, bytes message);

    /**
     * @notice intiailizes the CircleCCTPAdapter contract.
     * @param _usdc USDC address on the current chain.
     * @param _cctpTokenMessenger TokenMessenger contract to bridge via CCTP. If the zero address is passed, CCTP bridging will be disabled.
     * @param _messageTransmitter The message transmitter contract for cross-chain messaging
     * @param _vaultRegistry The vault registry contract
     */
    constructor(
        address _usdc,
        ITokenMessenger _cctpTokenMessenger,
        IMessageTransmitter _messageTransmitter,
        IVaultRegistry _vaultRegistry
    ) {
        usdc = _usdc;
        cctpTokenMessenger = _cctpTokenMessenger;
        messageTransmitter = _messageTransmitter;
        vaultRegistry = _vaultRegistry;
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
     * @notice Transfers USDC and sends a message to the destination chain
     * @param destinationDomain The destination domain
     * @param recipient The recipient address on destination chain
     * @param amount The amount of USDC to transfer
     * @param depositParams Encoded deposit parameters (vault, minShares, deadline)
     */
    function _transferUsdcWithMessage(
        uint32 destinationDomain,
        address recipient,
        uint256 amount,
        bytes memory depositParams
    ) internal {
        _transferUsdcWithMessage(destinationDomain, _toBytes32(recipient), amount, depositParams);
    }

    /**
     * @notice Transfers USDC and sends a message to the destination chain
     * @param destinationDomain The destination domain
     * @param recipient The recipient address on destination chain as bytes32
     * @param amount The amount of USDC to transfer
     * @param depositParams Encoded deposit parameters (vault, minShares, deadline)
     */
    function _transferUsdcWithMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        uint256 amount,
        bytes memory depositParams
    ) internal {
        // Validate deposit parameters
        (
            address vault,
            uint256 minSharesExpected,
            uint256 deadline
        ) = abi.decode(depositParams, (address, uint256, uint256));

        require(deadline > block.timestamp, "Invalid deadline");
        require(vaultRegistry.isVaultActive(uint32(block.chainid), vault), "Invalid vault");

        ITokenMinter cctpMinter = cctpTokenMessenger.localMinter();
        uint256 burnLimit = cctpMinter.burnLimitsPerMessage(address(usdc));

        // Approve USDC for bridge
        usdc.safeApproveWithRetry(address(cctpTokenMessenger), amount);

        // Always send USDC to our contract on destination
        bytes32 destinationContract = _toBytes32(address(this));

        // If amount is less than burn limit, transfer in one go
        if (amount <= burnLimit) {
            uint64 nonce = cctpTokenMessenger.depositForBurnWithCaller(
                amount,
                destinationDomain,
                destinationContract,  // Send to our contract
                address(usdc),
                destinationContract   // Only our contract can process
            );
            
            // Encode full deposit data
            bytes memory depositData = abi.encode(
                recipient,           // Original recipient
                amount,
                vault,
                minSharesExpected,
                deadline
            );
            
            emit MessageSent(nonce, destinationDomain, depositData);
            return;
        }

        // Handle larger amounts in batches
        uint256 remaining = amount;
        uint256 batchCount = (amount + burnLimit - 1) / burnLimit;
        uint64 firstNonce;

        for (uint256 i = 0; i < batchCount && remaining > 0;) {
            uint256 batchAmount = remaining > burnLimit ? burnLimit : remaining;
            
            uint64 nonce = cctpTokenMessenger.depositForBurnWithCaller(
                batchAmount,
                destinationDomain,
                destinationContract,  // Send to our contract
                address(usdc),
                i == 0 ? destinationContract : bytes32(0)  // Only first batch restricted
            );

            if (i == 0) {
                firstNonce = nonce;
                // Encode full deposit data only in first batch
                bytes memory depositData = abi.encode(
                    recipient,
                    amount,  // Total amount
                    vault,
                    minSharesExpected,
                    deadline
                );
                emit MessageSent(nonce, destinationDomain, depositData);
            }
            
            remaining -= batchAmount;
            unchecked { ++i; }
        }
    }

    /**
     * @notice Handle received message from CCTP
     * @param sourceDomain Source domain of the message
     * @param message The message data
     * @param attestation The attestation from Circle for the message (unused but required by interface)
     */
    function _handleReceivedMessage(
        uint32 sourceDomain,
        bytes memory message,
        // solhint-disable-next-line no-unused-vars
        bytes memory attestation  // Required by interface but unused
    ) internal virtual {
        // Decode deposit data
        (
            bytes32 recipient,
            uint256 amount,
            address vault,
            uint256 minSharesExpected,
            uint256 deadline
        ) = abi.decode(message, (bytes32, uint256, address, uint256, uint256));

        // Validate
        require(block.timestamp <= deadline, "Deposit expired");
        require(vaultRegistry.isVaultActive(uint32(block.chainid), vault), "Vault not active");

        // Approve vault to spend USDC
        usdc.safeApprove(vault, amount);

        // Deposit into vault
        uint256 shares = IERC4626(vault).deposit(amount, address(uint160(uint256(recipient))));
        require(shares >= minSharesExpected, "Insufficient shares");

        emit DepositCompleted(
            recipient,
            sourceDomain,
            vault,
            amount,
            shares
        );
    }

    event DepositCompleted(
        bytes32 indexed recipient,
        uint32 indexed sourceDomain,
        address indexed vault,
        uint256 amount,
        uint256 shares
    );
}
