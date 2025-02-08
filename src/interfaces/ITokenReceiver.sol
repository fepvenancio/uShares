// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ITokenReceiver {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensReceived(
        address indexed token,
        address indexed from,
        uint256 amount,
        bytes data
    );

    event NFTReceived(
        address indexed token,
        address indexed from,
        uint256 tokenId,
        bytes data
    );

    event ERC1155Received(
        address indexed token,
        address indexed from,
        uint256 id,
        uint256 amount,
        bytes data
    );

    event ERC1155BatchReceived(
        address indexed token,
        address indexed from,
        uint256[] ids,
        uint256[] amounts,
        bytes data
    );

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositToVault(
        address vault,
        address asset,
        uint256 amount
    ) external returns (uint256 shares);

    function withdrawFromVault(
        address vault,
        address asset,
        uint256 shares,
        address receiver
    ) external returns (uint256 amount);

    function configureHandler(address handler, bool enabled) external;
    function pause() external;
    function unpause() external;
    function recoverTokens(address token, address to, uint256 amount) external;
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
} 