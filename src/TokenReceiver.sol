// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {ITokenReceiver} from "./interfaces/ITokenReceiver.sol";
import {Errors} from "./libs/Errors.sol";

/**
 * @title TokenReceiver
 * @notice Contract for receiving and handling ERC20, ERC721, and ERC1155 tokens from vaults
 */
contract TokenReceiver is
    ITokenReceiver,
    IERC721Receiver,
    IERC1155Receiver,
    Ownable2Step,
    Pausable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of approved handlers
    mapping(address => bool) public approvedHandlers;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyApprovedHandler() {
        if (!approvedHandlers[msg.sender]) revert Errors.NotApprovedHandler();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _initializeOwner(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit assets into a vault and receive shares
     * @param vault The vault to deposit into
     * @param asset The asset to deposit
     * @param amount The amount of assets to deposit
     * @return shares The amount of shares received
     */
    function depositToVault(
        address vault,
        address asset,
        uint256 amount
    ) external onlyApprovedHandler whenNotPaused returns (uint256 shares) {
        Errors.verifyAddress(vault);
        Errors.verifyAddress(asset);

        // Transfer assets from sender to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Approve vault to spend assets
        IERC20(asset).safeApprove(vault, amount);

        // Deposit assets into vault
        shares = IERC4626(vault).deposit(amount, address(this));

        emit TokensReceived(asset, msg.sender, amount, "");
    }

    /**
     * @notice Withdraw assets from a vault by burning shares
     * @param vault The vault to withdraw from
     * @param asset The asset to withdraw
     * @param shares The amount of shares to burn
     * @param receiver The address to receive the assets
     * @return amount The amount of assets received
     */
    function withdrawFromVault(
        address vault,
        address asset,
        uint256 shares,
        address receiver
    ) external onlyApprovedHandler whenNotPaused returns (uint256 amount) {
        Errors.verifyAddress(vault);
        Errors.verifyAddress(asset);
        Errors.verifyAddress(receiver);

        // Withdraw assets from vault
        amount = IERC4626(vault).redeem(shares, receiver, address(this));

        emit TokensReceived(asset, vault, amount, "");
    }

    /**
     * @notice Configure a handler
     * @param handler The handler to configure
     * @param enabled Whether the handler is enabled
     */
    function configureHandler(address handler, bool enabled) external onlyOwner {
        Errors.verifyAddress(handler);
        approvedHandlers[handler] = enabled;
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Recover stuck tokens
     * @param token The token to recover
     * @param to The address to send the tokens to
     * @param amount The amount of tokens to recover
     */
    function recoverTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        Errors.verifyAddress(token);
        Errors.verifyAddress(to);
        IERC20(token).safeTransfer(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           RECEIVER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handle the receipt of a single ERC721 token
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        emit NFTReceived(msg.sender, from, tokenId, data);
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @notice Handle the receipt of a single ERC1155 token
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external override returns (bytes4) {
        emit ERC1155Received(msg.sender, from, id, amount, data);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /**
     * @notice Handle the receipt of multiple ERC1155 tokens
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override returns (bytes4) {
        emit ERC1155BatchReceived(msg.sender, from, ids, amounts, data);
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /**
     * @notice Query if a contract implements an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return supported True if the contract implements `interfaceId`
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool supported) {
        return
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }
} 