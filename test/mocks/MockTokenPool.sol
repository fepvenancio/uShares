// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Pool} from "../../src/libs/Pool.sol";
import {ITokenPool} from "../../src/interfaces/ITokenPool.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title MockTokenPool
 * @notice Simple mock implementation of CCT token pool for testing
 */
contract MockTokenPool is ITokenPool {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Token address
    address public immutable token;
    uint8 public immutable decimals;
    address public immutable router;
    mapping(bytes32 => bool) public processedMessages;

    constructor(
        IERC20 _token,
        uint8 _decimals,
        address _router
    ) {
        token = address(_token);
        decimals = _decimals;
        router = _router;
    }

    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata params
    ) external override returns (Pool.LockOrBurnOutV1 memory) {
        // Transfer tokens from sender
        token.safeTransferFrom(params.originalSender, address(this), params.amount);

        // Track message
        bytes32 messageId = keccak256(abi.encode(params));
        processedMessages[messageId] = true;

        return Pool.LockOrBurnOutV1({
            destTokenAddress: abi.encode(address(token)),
            destPoolData: abi.encode(params.amount)
        });
    }

    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata params
    ) external override returns (Pool.ReleaseOrMintOutV1 memory) {
        // Track message
        bytes32 messageId = keccak256(abi.encode(params));
        require(!processedMessages[messageId], "Message already processed");
        processedMessages[messageId] = true;

        // Transfer or mint tokens to recipient
        token.safeTransfer(params.receiver, params.amount);

        return Pool.ReleaseOrMintOutV1({
            destinationAmount: params.amount
        });
    }

    // Required view functions with minimal implementations
    function isSupportedChain(uint64) external pure override returns (bool) {
        return true;
    }

    function isSupportedToken(address _token) external view override returns (bool) {
        return _token == address(token);
    }

    function getToken() external view override returns (address) {
        return address(token);
    }

    function getTokenDecimals() external view override returns (uint8) {
        return decimals;
    }

    function getRouter() external view override returns (address) {
        return router;
    }

    function getRmnProxy() external pure override returns (address) {
        return address(0);
    }

    function getRemoteTokenPool(uint64) external pure override returns (address) {
        return address(1); // Return dummy address for testing
    }

    function getRateLimitConfig(uint64) external pure override returns (Pool.RateLimitConfig memory) {
        return Pool.RateLimitConfig({
            rate: type(uint256).max,
            capacity: type(uint256).max,
            currentTokens: type(uint256).max,
            lastUpdated: block.timestamp
        });
    }

    function getRemoteToken(uint64) external view override returns (bytes memory) {
        return abi.encode(address(token));
    }

    function getRemotePools(uint64) external pure override returns (bytes[] memory) {
        bytes[] memory pools = new bytes[](1);
        pools[0] = abi.encode(address(1));
        return pools;
    }

    function isRemotePool(uint64, bytes calldata) external pure override returns (bool) {
        return true;
    }

    function getCurrentOutboundRateLimiterState(uint64)
        external
        pure
        override
        returns (uint256, uint256, bool)
    {
        return (type(uint256).max, block.timestamp, true);
    }

    function getCurrentInboundRateLimiterState(uint64)
        external
        pure
        override
        returns (uint256, uint256, bool)
    {
        return (type(uint256).max, block.timestamp, true);
    }
} 