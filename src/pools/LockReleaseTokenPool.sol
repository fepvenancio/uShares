// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BaseTokenPool} from "./BaseTokenPool.sol";
import {Pool} from "../libs/Pool.sol";
import {IUSharesToken} from "../interfaces/IUSharesToken.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ITypeAndVersion} from "../interfaces/ITypeAndVersion.sol";
import {ITokenPool} from "../interfaces/ITokenPool.sol";

/**
 * @title LockReleaseTokenPool
 * @notice Token pool that locks tokens on the source chain and releases them on the destination chain
 * @dev Implements rate limiting and message validation for secure cross-chain transfers
 */
contract LockReleaseTokenPool is BaseTokenPool, ITypeAndVersion {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a chain is supported
    modifier onlySupportedChain(uint64 chainSelector) {
        if (!isSupportedChain(chainSelector)) revert ChainNotAllowed(chainSelector);
        _;
    }

    /// @notice Checks if a token is supported
    modifier onlySupportedToken(address token) {
        if (!isSupportedToken(token)) revert InvalidToken(token);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Total amount of tokens locked in the pool
    uint256 public totalLocked;

    /// @notice Mapping of chain ID to locked amount
    mapping(uint64 => uint256) public lockedPerChain;

    /// @notice Mapping of processed message IDs
    mapping(bytes32 => bool) public processedMessages;

    /// @notice Version string
    string public constant override typeAndVersion = "LockReleaseTokenPool 1.5.1";

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param token Address of the token this pool manages
     * @param tokenDecimals Token decimals
     * @param allowlist Initial allowlist of addresses
     * @param rmnProxy RMN proxy address for curse checks
     * @param router Router contract for cross-chain messaging
     */
    constructor(
        ERC20 token,
        uint8 tokenDecimals,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) BaseTokenPool(token, tokenDecimals, allowlist, rmnProxy, router) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ITokenPool
     */
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata params
    ) external override onlySupportedChain(params.remoteChainSelector) onlySupportedToken(params.localToken) returns (Pool.LockOrBurnOutV1 memory) {
        // Validate chain and enforce rate limit
        _validateMessage(params.remoteChainSelector, "");
        _enforceRateLimit(
            s_remoteChainConfigs[params.remoteChainSelector].outboundRateLimiter,
            params.amount,
            params.remoteChainSelector
        );

        // Transfer tokens from sender to pool
        params.localToken.safeTransferFrom(params.originalSender, address(this), params.amount);

        // Update state
        totalLocked += params.amount;
        lockedPerChain[params.remoteChainSelector] += params.amount;

        emit TokensLocked(params.originalSender, params.amount);

        // Return message for destination chain
        return Pool.LockOrBurnOutV1({
            destTokenAddress: s_remoteChainConfigs[params.remoteChainSelector].remoteToken,
            destPoolData: _encodeLocalDecimals()
        });
    }

    /**
     * @inheritdoc ITokenPool
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata params
    ) external override onlySupportedChain(params.remoteChainSelector) onlySupportedToken(params.localToken) returns (Pool.ReleaseOrMintOutV1 memory) {
        // Validate chain, source pool, and enforce rate limit
        _validateMessage(params.remoteChainSelector, params.sourcePoolAddress);
        _enforceRateLimit(
            s_remoteChainConfigs[params.remoteChainSelector].inboundRateLimiter,
            params.amount,
            params.remoteChainSelector
        );

        // Generate and check message ID
        bytes32 messageId = keccak256(abi.encode(
            params.remoteChainSelector,
            params.sourcePoolAddress,
            params.amount,
            params.receiver
        ));
        if (processedMessages[messageId]) revert DuplicateMessage(messageId);
        processedMessages[messageId] = true;

        // Calculate local amount based on decimals
        uint256 localAmount = _calculateLocalAmount(
            params.amount,
            _parseRemoteDecimals(params.sourcePoolData)
        );

        // Update state
        totalLocked -= localAmount;
        lockedPerChain[params.remoteChainSelector] -= localAmount;

        // Transfer tokens to receiver
        params.localToken.safeTransfer(params.receiver, localAmount);

        emit TokensReleased(address(bytes20(params.originalSender)), params.receiver, localAmount);

        return Pool.ReleaseOrMintOutV1({
            amount: localAmount
        });
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get total amount of locked tokens
     */
    function getTotalLocked() external view returns (uint256) {
        return totalLocked;
    }

    /**
     * @notice Get amount of tokens locked for a specific chain
     * @param chainSelector The chain selector to check
     */
    function getLockedForChain(uint64 chainSelector) external view returns (uint256) {
        return lockedPerChain[chainSelector];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Encode local token decimals for cross-chain transfer
     */
    function _encodeLocalDecimals() internal view returns (bytes memory) {
        return abi.encode(i_tokenDecimals);
    }

    /**
     * @notice Parse remote token decimals from source pool data
     */
    function _parseRemoteDecimals(bytes memory sourcePoolData) internal pure returns (uint8) {
        return abi.decode(sourcePoolData, (uint8));
    }

    /**
     * @notice Calculate local amount based on decimals difference
     */
    function _calculateLocalAmount(uint256 amount, uint8 remoteDecimals) internal view returns (uint256) {
        if (remoteDecimals == i_tokenDecimals) {
            return amount;
        }
        if (remoteDecimals > i_tokenDecimals) {
            return amount / (10 ** (remoteDecimals - i_tokenDecimals));
        }
        return amount * (10 ** (i_tokenDecimals - remoteDecimals));
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getRateLimitConfig(uint64 chainSelector) external view returns (Pool.RateLimitConfig memory) {
        return s_remoteChainConfigs[chainSelector].outboundRateLimiter;
    }

    /**
     * @inheritdoc ITokenPool
     */
    function getRemoteTokenPool(uint64 chainSelector) external view returns (address) {
        return address(bytes20(s_remoteChainConfigs[chainSelector].remoteToken));
    }
} 