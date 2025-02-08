// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ITokenPool} from "../interfaces/ITokenPool.sol";
import {Pool} from "../libs/Pool.sol";
import {Errors} from "../libs/Errors.sol";
import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IRMN} from "../interfaces/IRMN.sol";
import {IRouter} from "../interfaces/IRouter.sol";

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @title BaseTokenPool
 * @notice Base implementation for CCT token pools with shared functionality
 * @dev Implements rate limiting and message processing logic
 */
abstract contract BaseTokenPool is ITokenPool, OwnableRoles {
    using SafeTransferLib for address;
    using EnumerableSetLib for EnumerableSetLib.AddressSet;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using EnumerableSetLib for EnumerableSetLib.Uint256Set;

    // Custom errors that are not in ITokenPool
    error ChainIsCursed(uint64 chainSelector);
    error InvalidMessageFormat();
    error InvalidDestinationPool(bytes32 poolAddress);
    error InvalidMessageLength();
    error InvalidTokenAmount();
    error InvalidAllowance();
    error InvalidBalance();
    error InvalidPoolAddress();
    error InvalidPoolConfig();
    error InvalidRateLimit();
    error InvalidCapacity();
    error InvalidRefillRate();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for admin operations
    uint256 public constant ADMIN_ROLE = _ROLE_0;

    /// @notice Role identifier for operator operations
    uint256 public constant OPERATOR_ROLE = _ROLE_1;

    /// @notice Maximum rate limit (1M tokens per second)
    uint256 public constant MAX_RATE_LIMIT = 1_000_000e6;

    /// @notice Maximum capacity (10M tokens)
    uint256 public constant MAX_CAPACITY = 10_000_000e6;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Token contract address
    ERC20 public immutable i_token;

    /// @notice Token decimals
    uint8 public immutable i_tokenDecimals;

    /// @notice RMN proxy address for curse checks
    address public immutable i_rmnProxy;

    /// @notice Whether allowlist is enabled
    bool public immutable i_allowlistEnabled;

    /// @notice Router contract for cross-chain messaging
    IRouter public s_router;

    /// @notice Allowlist of addresses that can initiate transfers
    EnumerableSetLib.AddressSet internal s_allowlist;

    /// @notice Set of supported chain selectors
    EnumerableSetLib.Uint256Set internal s_supportedChains;

    /// @notice Remote chain configuration
    struct RemoteChainConfig {
        bytes remoteToken;
        EnumerableSetLib.Bytes32Set remotePools;
        TokenBucket outboundRateLimiter;
        TokenBucket inboundRateLimiter;
    }

    /// @notice Rate limiting bucket
    struct TokenBucket {
        uint256 tokens;
        uint256 capacity;
        uint256 rate;
        uint256 lastUpdated;
        bool isEnabled;
    }

    /// @notice Mapping of chain selector to configuration
    mapping(uint64 => RemoteChainConfig) internal s_remoteChainConfigs;

    /// @notice Mapping of pool address hash to actual address
    mapping(bytes32 => bytes) internal s_remotePoolAddresses;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the token pool
     * @param token Address of the token contract
     * @param tokenDecimals Token decimals
     * @param allowlist Allowlist of addresses that can initiate transfers
     * @param rmnProxy RMN proxy address for curse checks
     * @param router Router contract for cross-chain messaging
     */
    constructor(
        ERC20 token,
        uint8 tokenDecimals,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) {
        if (address(token) == address(0)) revert ZeroAddressNotAllowed();
        if (rmnProxy == address(0)) revert ZeroAddressNotAllowed();
        if (router == address(0)) revert ZeroAddressNotAllowed();

        i_token = token;
        i_tokenDecimals = tokenDecimals;
        i_rmnProxy = rmnProxy;
        s_router = IRouter(router);
        i_allowlistEnabled = allowlist.length > 0;

        if (i_allowlistEnabled) {
            for (uint256 i = 0; i < allowlist.length; i++) {
                if (allowlist[i] != address(0)) {
                    s_allowlist.add(allowlist[i]);
                }
            }
        }

        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ADMIN_ROLE | OPERATOR_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                            CCT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ITokenPool
     */
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata params
    ) external virtual returns (Pool.LockOrBurnOutV1 memory);

    /**
     * @inheritdoc ITokenPool
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata params
    ) external virtual returns (Pool.ReleaseOrMintOutV1 memory);

    /*//////////////////////////////////////////////////////////////
                            CHAIN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new supported chain with rate limits
     * @param chainSelector Chain selector to add
     * @param remoteToken Remote token address
     * @param remotePools Array of remote pool addresses
     * @param outboundConfig Outbound rate limit config
     * @param inboundConfig Inbound rate limit config
     */
    function addChain(
        uint64 chainSelector,
        bytes calldata remoteToken,
        bytes[] calldata remotePools,
        TokenBucket calldata outboundConfig,
        TokenBucket calldata inboundConfig
    ) external onlyRoles(ADMIN_ROLE) {
        if (s_supportedChains.contains(chainSelector)) revert ChainAlreadyExists(chainSelector);
        if (remoteToken.length == 0) revert ZeroAddressNotAllowed();

        s_supportedChains.add(chainSelector);
        s_remoteChainConfigs[chainSelector].remoteToken = remoteToken;
        s_remoteChainConfigs[chainSelector].outboundRateLimiter = outboundConfig;
        s_remoteChainConfigs[chainSelector].inboundRateLimiter = inboundConfig;

        for (uint256 i = 0; i < remotePools.length; i++) {
            _addRemotePool(chainSelector, remotePools[i]);
        }
    }

    /**
     * @notice Remove a supported chain
     * @param chainSelector Chain selector to remove
     */
    function removeChain(uint64 chainSelector) external onlyRoles(ADMIN_ROLE) {
        if (!s_supportedChains.contains(chainSelector)) revert NonExistentChain(chainSelector);

        // Remove all remote pools
        bytes32[] memory poolHashes = s_remoteChainConfigs[chainSelector].remotePools.values();
        for (uint256 i = 0; i < poolHashes.length; i++) {
            bytes memory poolAddress = s_remotePoolAddresses[poolHashes[i]];
            _removeRemotePool(chainSelector, poolAddress);
        }

        s_supportedChains.remove(chainSelector);
        delete s_remoteChainConfigs[chainSelector];
    }

    /*//////////////////////////////////////////////////////////////
                            POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a remote pool for a chain
     * @param chainSelector Chain selector
     * @param remotePool Remote pool address
     */
    function addRemotePool(
        uint64 chainSelector,
        bytes calldata remotePool
    ) external onlyRoles(ADMIN_ROLE) {
        if (!s_supportedChains.contains(chainSelector)) revert NonExistentChain(chainSelector);
        _addRemotePool(chainSelector, remotePool);
    }

    /**
     * @notice Remove a remote pool for a chain
     * @param chainSelector Chain selector
     * @param remotePool Remote pool address
     */
    function removeRemotePool(
        uint64 chainSelector,
        bytes calldata remotePool
    ) external onlyRoles(ADMIN_ROLE) {
        if (!s_supportedChains.contains(chainSelector)) revert NonExistentChain(chainSelector);
        _removeRemotePool(chainSelector, remotePool);
    }

    /*//////////////////////////////////////////////////////////////
                            RATE LIMITING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update rate limit configuration for a chain
     * @param chainSelector Chain selector to update
     * @param outboundConfig New outbound rate limit config
     * @param inboundConfig New inbound rate limit config
     */
    function updateRateLimits(
        uint64 chainSelector,
        TokenBucket calldata outboundConfig,
        TokenBucket calldata inboundConfig
    ) external onlyRoles(ADMIN_ROLE) {
        if (!s_supportedChains.contains(chainSelector)) revert NonExistentChain(chainSelector);

        s_remoteChainConfigs[chainSelector].outboundRateLimiter = outboundConfig;
        s_remoteChainConfigs[chainSelector].inboundRateLimiter = inboundConfig;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if contract supports an interface
     * @param interfaceId Interface ID to check
     * @return bool True if interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return interfaceId == type(ITokenPool).interfaceId;
    }

    /**
     * @inheritdoc ITokenPool
     */
    function isSupportedChain(uint64 remoteChainSelector) public view returns (bool) {
        return s_supportedChains.contains(remoteChainSelector);
    }

    /**
     * @inheritdoc ITokenPool
     */
    function isSupportedToken(address token) public view returns (bool) {
        return token == address(i_token);
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getToken() external view returns (address) {
        return address(i_token);
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getTokenDecimals() external view returns (uint8) {
        return i_tokenDecimals;
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getRouter() external view returns (address) {
        return address(s_router);
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getRmnProxy() external view returns (address) {
        return i_rmnProxy;
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getRemoteToken(uint64 remoteChainSelector) external view returns (bytes memory) {
        return s_remoteChainConfigs[remoteChainSelector].remoteToken;
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getRemotePools(uint64 remoteChainSelector) external view returns (bytes[] memory) {
        bytes32[] memory poolHashes = s_remoteChainConfigs[remoteChainSelector].remotePools.values();
        bytes[] memory pools = new bytes[](poolHashes.length);
        
        for (uint256 i = 0; i < poolHashes.length; i++) {
            pools[i] = s_remotePoolAddresses[poolHashes[i]];
        }
        
        return pools;
    }

    /**
     * @notice Internal function to check if a pool address is configured for a chain
     */
    function _isRemotePool(
        uint64 remoteChainSelector,
        bytes memory remotePoolAddress
    ) internal view returns (bool) {
        return s_remoteChainConfigs[remoteChainSelector].remotePools.contains(
            keccak256(remotePoolAddress)
        );
    }

    /**
     * @notice Validate message from source chain
     */
    function _validateMessage(
        uint64 remoteChainSelector,
        bytes memory sourcePoolAddress
    ) internal view {
        if (!isSupportedChain(remoteChainSelector)) {
            revert ChainNotAllowed(remoteChainSelector);
        }

        if (!_isRemotePool(remoteChainSelector, sourcePoolAddress)) {
            revert InvalidSourcePoolAddress(sourcePoolAddress);
        }

        if (IRMN(i_rmnProxy).isCursed(address(uint160(remoteChainSelector)))) {
            revert ChainIsCursed(remoteChainSelector);
        }
    }

    /**
     * @inheritdoc ITokenPool
     */
    function isRemotePool(
        uint64 remoteChainSelector,
        bytes calldata remotePoolAddress
    ) external view returns (bool) {
        return _isRemotePool(remoteChainSelector, remotePoolAddress);
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getCurrentOutboundRateLimiterState(uint64 remoteChainSelector)
        external
        view
        returns (uint256 tokens, uint256 lastUpdated, bool isEnabled)
    {
        TokenBucket storage bucket = s_remoteChainConfigs[remoteChainSelector].outboundRateLimiter;
        return (bucket.tokens, bucket.lastUpdated, bucket.isEnabled);
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getCurrentInboundRateLimiterState(uint64 remoteChainSelector)
        external
        view
        returns (uint256 tokens, uint256 lastUpdated, bool isEnabled)
    {
        TokenBucket storage bucket = s_remoteChainConfigs[remoteChainSelector].inboundRateLimiter;
        return (bucket.tokens, bucket.lastUpdated, bucket.isEnabled);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a remote pool to a chain's configuration
     */
    function _addRemotePool(uint64 chainSelector, bytes memory remotePool) internal {
        if (remotePool.length == 0) revert ZeroAddressNotAllowed();
        
        bytes32 poolHash = keccak256(remotePool);
        if (!s_remoteChainConfigs[chainSelector].remotePools.add(poolHash)) {
            revert PoolAlreadyAdded(chainSelector, remotePool);
        }
        
        s_remotePoolAddresses[poolHash] = remotePool;
    }

    /**
     * @notice Remove a remote pool from a chain's configuration
     */
    function _removeRemotePool(uint64 chainSelector, bytes memory remotePool) internal {
        bytes32 poolHash = keccak256(remotePool);
        if (!s_remoteChainConfigs[chainSelector].remotePools.remove(poolHash)) {
            revert InvalidRemotePoolForChain(chainSelector, remotePool);
        }
        
        delete s_remotePoolAddresses[poolHash];
    }

    /**
     * @notice Enforce rate limit for a transfer
     */
    function _enforceRateLimit(
        TokenBucket storage bucket,
        uint256 amount,
        uint64 chainSelector
    ) internal {
        if (!bucket.isEnabled) return;

        uint256 elapsed = block.timestamp - bucket.lastUpdated;
        uint256 newTokens = elapsed * bucket.rate;
        
        bucket.tokens = uint256(
            bucket.tokens + newTokens > bucket.capacity
                ? bucket.capacity
                : bucket.tokens + newTokens
        );
        
        if (amount > bucket.tokens) revert RateLimitExceeded(chainSelector, amount, bucket.capacity);
        
        bucket.tokens -= amount;
        bucket.lastUpdated = block.timestamp;
    }
} 