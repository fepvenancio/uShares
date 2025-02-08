// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Pool} from "../libs/Pool.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title ITokenPool
 * @notice Interface for token pools in the uShares protocol
 * @dev Implements CCT standard requirements for token pools
 */
interface ITokenPool {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error CallerIsNotARampOnRouter(address caller);
    error ZeroAddressNotAllowed();
    error SenderNotAllowed(address sender);
    error AllowListNotEnabled();
    error NonExistentChain(uint64 remoteChainSelector);
    error ChainNotAllowed(uint64 chainSelector);
    error InvalidSourcePoolAddress(bytes sourcePoolAddress);
    error InvalidToken(address token);
    error ChainAlreadyExists(uint64 chainSelector);
    error PoolAlreadyAdded(uint64 remoteChainSelector, bytes remotePoolAddress);
    error InvalidRemotePoolForChain(uint64 remoteChainSelector, bytes remotePoolAddress);
    error RateLimitExceeded(uint256 requested, uint256 available);
    error DuplicateMessage(bytes32 messageId);
    error InvalidMessageVersion();
    error InvalidSourcePool(address pool);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokensLocked(address indexed sender, uint256 amount);
    event TokensBurned(address indexed sender, uint256 amount);
    event TokensReleased(address indexed sender, address indexed recipient, uint256 amount);
    event TokensMinted(address indexed sender, address indexed recipient, uint256 amount);
    event ChainAdded(uint64 remoteChainSelector, bytes remoteToken);
    event ChainRemoved(uint64 remoteChainSelector);
    event RemotePoolAdded(uint64 indexed remoteChainSelector, bytes remotePoolAddress);
    event RemotePoolRemoved(uint64 indexed remoteChainSelector, bytes remotePoolAddress);
    event RateLimitUpdated(uint64 indexed chainSelector, uint256 ratePerSecond, uint256 capacity);

    /*//////////////////////////////////////////////////////////////
                            CCT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Lock or burn tokens on source chain
     * @param params Lock/burn parameters
     * @return Pool.LockOrBurnOutV1 Output parameters
     */
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata params
    ) external returns (Pool.LockOrBurnOutV1 memory);

    /**
     * @notice Release or mint tokens on destination chain
     * @param params Release/mint parameters
     * @return Pool.ReleaseOrMintOutV1 Output parameters
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata params
    ) external returns (Pool.ReleaseOrMintOutV1 memory);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a chain is supported
     * @param chainSelector Chain selector to check
     * @return bool Whether chain is supported
     */
    function isSupportedChain(uint64 chainSelector) external view returns (bool);

    /**
     * @notice Check if a token is supported
     * @param token Token address to check
     * @return bool Whether token is supported
     */
    function isSupportedToken(address token) external view returns (bool);

    /**
     * @notice Get the token contract address
     * @return token The token contract address
     */
    function getToken() external view returns (address);

    /**
     * @notice Get the token decimals
     * @return decimals The token decimals
     */
    function getTokenDecimals() external view returns (uint8);

    /**
     * @notice Get the router contract address
     * @return router The router contract address
     */
    function getRouter() external view returns (address);

    /**
     * @notice Get the RMN proxy address
     * @return rmnProxy The RMN proxy address
     */
    function getRmnProxy() external view returns (address);

    /**
     * @notice Get remote token pool for a chain
     * @param chainSelector Chain selector to check
     * @return address Remote token pool address
     */
    function getRemoteTokenPool(uint64 chainSelector) external view returns (address);

    /**
     * @notice Get rate limit configuration for a chain
     * @param chainSelector Chain selector to check
     * @return Pool.RateLimitConfig Rate limit configuration
     */
    function getRateLimitConfig(uint64 chainSelector) external view returns (Pool.RateLimitConfig memory);

    /**
     * @notice Get the remote token address for a chain
     * @param remoteChainSelector The chain selector to query
     * @return remoteToken The remote token address
     */
    function getRemoteToken(uint64 remoteChainSelector) external view returns (bytes memory);

    /**
     * @notice Get the remote pool addresses for a chain
     * @param remoteChainSelector The chain selector to query
     * @return remotePools Array of remote pool addresses
     */
    function getRemotePools(uint64 remoteChainSelector) external view returns (bytes[] memory);

    /**
     * @notice Check if a pool address is configured for a chain
     * @param remoteChainSelector The chain selector to query
     * @param remotePoolAddress The pool address to check
     * @return bool True if the pool is configured
     */
    function isRemotePool(uint64 remoteChainSelector, bytes calldata remotePoolAddress) external view returns (bool);

    /**
     * @notice Get the current rate limit state for outbound transfers
     * @param remoteChainSelector The chain selector to query
     * @return tokens Current available tokens
     * @return lastUpdated Last update timestamp
     * @return isEnabled Whether rate limiting is enabled
     */
    function getCurrentOutboundRateLimiterState(uint64 remoteChainSelector)
        external
        view
        returns (uint256 tokens, uint256 lastUpdated, bool isEnabled);

    /**
     * @notice Get the current rate limit state for inbound transfers
     * @param remoteChainSelector The chain selector to query
     * @return tokens Current available tokens
     * @return lastUpdated Last update timestamp
     * @return isEnabled Whether rate limiting is enabled
     */
    function getCurrentInboundRateLimiterState(uint64 remoteChainSelector)
        external
        view
        returns (uint256 tokens, uint256 lastUpdated, bool isEnabled);
} 