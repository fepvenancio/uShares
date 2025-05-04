// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IERC20 } from "interfaces/IERC20.sol";
import { IERC4626 } from "interfaces/IERC4626.sol";
import { IMessageTransmitter } from "interfaces/IMessageTransmitter.sol";

import { ITokenMessenger } from "interfaces/ITokenMessenger.sol";
import { BaseModule } from "libraries/base/BaseModule.sol";

import { IRouterClient } from "chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Client } from "chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import { Constants } from "libraries/core/Constants.sol";
import { Errors } from "libraries/core/Errors.sol";
import { Events } from "libraries/core/Events.sol";
import { VaultLogic } from "libraries/logic/VaultLogic.sol";
import { USharesToken } from "protocol/tokenization/USharesToken.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title CrossChain
 * @notice Handles deposits, withdrawals, and cross-chain operations
 */
contract CrossVault is BaseModule {
    using SafeTransferLib for address;

    // CCTP state variables
    // Use _usdc from storage (inherited)
    ITokenMessenger public cctpTokenMessenger;
    IMessageTransmitter public messageTransmitter;
    IRouterClient public router;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 moduleId_,
        bytes32 moduleVersion_,
        address _cctpTokenMessenger,
        address _messageTransmitter,
        address _router
    )
        BaseModule(moduleId_, moduleVersion_)
    {
        cctpTokenMessenger = ITokenMessenger(_cctpTokenMessenger);
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
        router = IRouterClient(_router);
    }

    /*//////////////////////////////////////////////////////////////
                    Fallback and Receive Functions
    //////////////////////////////////////////////////////////////*/
    // Explicitly reject any Ether sent to the contract
    fallback() external payable {
        revert Errors.Fallback();
    }

    // Explicitly reject any Ether transfered to the contract
    receive() external payable {
        revert Errors.CantReceiveETH();
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit USDC to get vault exposure
     * @param amount Amount of USDC to deposit
     * @param destinationChain Chain ID where vault exists
     * @param vault Vault address to deposit into
     * @param minSharesExpected Minimum shares expected to receive
     * @param deadline Timestamp after which transaction reverts
     */
    function deposit(
        uint256 amount,
        uint32 destinationChain,
        address vault,
        uint256 minSharesExpected,
        uint256 deadline
    )
        external
        reentrantOK
    {
        require(destinationChain != block.chainid, "Use LocalVault for same-chain");
        if (block.timestamp > deadline) revert Errors.DeadlineExpired();

        // Calculate fees
        uint256 fee = VaultLogic.calculateTotalFee(amount, protocolFee(), chainFees(destinationChain));
        uint256 depositAmount = amount - fee;

        // Transfer USDC from user
        _usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Handle fees
        if (fee > 0 && feeCollector() != address(0)) {
            _usdc.safeTransfer(feeCollector(), fee);
        }

        // Burn USDC and send message with destinationVault and owner (CCTP)
        _transferUsdcWithMessage(
            destinationChain,
            vault,
            msg.sender,
            depositAmount,
            0x0 // Optionally, a depositId or message body for off-chain tracking
        );

        // Do NOT mint USharesToken here! Minting will occur on the destination chain and be sent back via CCT/CCIP.

        emit Events.DepositInitiated(msg.sender, destinationChain, vault, depositAmount, minSharesExpected);
    }

    /**
     * @notice Withdraw USDC from vault position
     * @param shares Amount of shares to withdraw
     * @param destinationChain Chain ID where vault exists
     * @param vault Vault address to withdraw from
     * @param minUsdcExpected Minimum USDC expected to receive
     * @param deadline Timestamp after which transaction reverts
     */
    function withdraw(
        uint256 shares,
        uint32 destinationChain,
        address vault,
        uint256 minUsdcExpected,
        uint256 deadline
    )
        external
        reentrantOK
    {
        Errors.verifyAddress(vault);
        if (block.timestamp > deadline) revert Errors.DeadlineExpired();

        // Only handle cross-chain withdrawal
        bytes32 withdrawalId = bytes32(uint256(uint160(msg.sender))); // TODO: Use a unique ID for each withdrawal
        _transferUSharesWithMessage(
            uint32(block.chainid), destinationChain, vault, msg.sender, shares, minUsdcExpected, withdrawalId
        );
        // For cross-chain, burn immediately as position is tracked
        USharesToken uShares = USharesToken(crossChainUSharesTokens[destinationChain][vault]);
        uShares.burnFrom(msg.sender, shares);

        emit Events.WithdrawalInitiated(msg.sender, destinationChain, vault, shares, minUsdcExpected);
    }

    function _transferUSharesWithMessage(
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault,
        address user,
        uint256 shares,
        uint256 minUsdcExpected,
        bytes32 withdrawalId
    )
        internal
    {
        IRouterClient routerContract = IRouterClient(router);
        uint64 destinationChainSelector = _chainSelectors[destinationChain];
        // Check if the destination chain is supported by the router
        if (!routerContract.isChainSupported(destinationChainSelector)) {
            revert Errors.InvalidChainSelector(destinationChainSelector);
        }

        bytes memory messageBody =
            abi.encode(withdrawalId, user, destinationVault, sourceChain, shares, minUsdcExpected, false);
        address feeTokenAddress = address(0);
        address tokenAddress = crossChainUSharesTokens[destinationChain][destinationVault];

        // Prepare the CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(crossChainUSharesTokens[destinationChain][destinationVault]), // Receiver address on the destination chain
            data: messageBody,
            tokenAmounts: new Client.EVMTokenAmount[](1), // Array of tokens to transfer
            feeToken: feeTokenAddress, // Fee token (native or LINK)
            extraArgs: abi.encodePacked(
                bytes4(keccak256("CCIP EVMExtraArgsV1")), // Extra arguments for CCIP (versioned)
                abi.encode(uint256(0)) // Placeholder for future use
            )
        });

        // Set the token and amount to transfer
        message.tokenAmounts[0] = Client.EVMTokenAmount({ token: tokenAddress, amount: shares });

        // Approve the router to transfer tokens on behalf of the sender
        tokenAddress.safeApprove(address(router), shares);

        // Estimate the fees required for the transfer
        uint256 fees = routerContract.getFee(destinationChainSelector, message);

        // Send the CCIP message and handle fee payment
        bytes32 messageId;
        messageId = routerContract.ccipSend{ value: fees }(destinationChainSelector, message);
    }

    /**
     * @dev Internal function to bridge USDC using CCTP v1.
     *      Since v1 does not support arbitrary message bodies, we use withdrawalId for off-chain reconciliation.
     *      The destination contract (vault) will receive the USDC, and off-chain logic must match withdrawalId to user.
     */
    function _transferUsdcWithMessage(
        uint32 destinationChain,
        address destinationVault,
        address destinationCrossVault,
        uint256 amount,
        bytes32 depositId
    )
        internal
    {
        // Approve TokenMessenger to spend USDC
        _usdc.safeApprove(address(cctpTokenMessenger), amount);

        // Encode the recipient as the destination vault contract
        bytes32 mintRecipient = bytes32(uint256(uint160(destinationCrossVault)));
        bytes32 destinationCaller = bytes32(uint256(uint160(destinationCrossVault))); // Only vault can handle

        // Call CCTP bridge (burn USDC and send message)
        cctpTokenMessenger.depositForBurnWithCaller(
            amount, destinationChain, mintRecipient, address(IERC20(_usdc)), destinationCaller
        );
        // Off-chain: use withdrawalId to match the transfer to the user and shares for uShares minting
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // IMessageHandler interface for CCTP message reception (destination chain)
    function handleReceiveMessage(
        uint32 remoteDomain,
        bytes32 sender,
        bytes calldata messageBody
    )
        external
        returns (bool)
    {
        require(msg.sender == address(messageTransmitter), "Not allowed");
        // Decode messageBody to determine if this is a deposit or withdrawal
        (
            bytes32 opId,
            address user,
            address vault,
            uint32 sourceChain,
            uint256 amountOrShares,
            uint256 minExpected,
            bool isDeposit
        ) = abi.decode(messageBody, (bytes32, address, address, uint32, uint256, uint256, bool));
        if (isDeposit) {
            // Deposit USDC into vault
            _usdc.safeApprove(vault, amountOrShares);
            uint256 shares = IERC4626(vault).deposit(amountOrShares, address(this));
            if (shares < minExpected) revert Errors.InsufficientShares();
            // Mint USharesToken for this vault to this contract
            USharesToken uShares = USharesToken(uSharesTokens[vault]);
            uShares.mint(address(this), shares);
            // Use CCT/CCIP to send USharesToken to user on source chain
            _transferUSharesWithMessage(
                sourceChain, uint32(block.chainid), vault, user, amountOrShares, minExpected, opId
            );
            emit Events.CrossChainDepositCompleted(opId, user, vault, shares);
        } else {
            // Withdrawal: redeem shares from vault
            uint256 usdcAmount = IERC4626(vault).redeem(amountOrShares, address(this), address(this));
            if (usdcAmount < minExpected) revert Errors.InsufficientUSDC();

            // Burn USDC and send message with destinationVault and owner (CCTP)
            _transferUsdcWithMessage(
                sourceChain,
                vault,
                user,
                usdcAmount,
                0x0 // Optionally, a depositId or message body for off-chain tracking
            );

            emit Events.CrossChainWithdrawalCompleted(opId, user, vault, usdcAmount);
        }
        return true;
    }
}
