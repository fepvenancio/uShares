// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BaseTokenPool} from "./BaseTokenPool.sol";
import {Pool} from "../libs/Pool.sol";
import {IUSharesToken} from "../interfaces/IUSharesToken.sol";
import {ITokenPool} from "../interfaces/ITokenPool.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title BurnMintTokenPool
 * @notice Token pool that burns tokens on the source chain and mints them on the destination chain
 * @dev Implements rate limiting and message validation for secure cross-chain transfers
 */
contract BurnMintTokenPool is BaseTokenPool {
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

    /// @notice Total amount of tokens minted on this chain
    uint256 public totalMinted;

    /// @notice Total amount of tokens burned on this chain
    uint256 public totalBurned;

    /// @notice Mapping of chain ID to minted amount
    mapping(uint64 => uint256) public mintedPerChain;

    /// @notice Mapping of chain ID to burned amount
    mapping(uint64 => uint256) public burnedPerChain;

    /// @notice Mapping of processed message IDs
    mapping(bytes32 => bool) public processedMessages;

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
        address token,
        uint8 tokenDecimals,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) BaseTokenPool(ERC20(token), tokenDecimals, allowlist, rmnProxy, router) {}

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

        // Burn tokens from sender
        IUSharesToken(params.localToken).burn(params.originalSender, params.amount);

        // Update state
        totalBurned += params.amount;
        burnedPerChain[params.remoteChainSelector] += params.amount;

        emit TokensBurned(params.originalSender, params.amount);

        // Return message for destination chain
        return Pool.LockOrBurnOutV1({
            destTokenAddress: s_remoteChainConfigs[params.remoteChainSelector].remoteToken,
            destPoolData: abi.encode(params.originalSender, params.amount)
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

        // Mint tokens to receiver
        IUSharesToken(params.localToken).mint(params.receiver, params.amount);

        // Update state
        totalMinted += params.amount;
        mintedPerChain[params.remoteChainSelector] += params.amount;

        emit TokensMinted(address(bytes20(params.originalSender)), params.receiver, params.amount);

        return Pool.ReleaseOrMintOutV1({
            amount: params.amount
        });
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get total amount of minted tokens
     */
    function getTotalMinted() external view returns (uint256) {
        return totalMinted;
    }

    /**
     * @notice Get total amount of burned tokens
     */
    function getTotalBurned() external view returns (uint256) {
        return totalBurned;
    }

    /**
     * @notice Get amount of tokens minted for a specific chain
     * @param chainSelector The chain selector to check
     */
    function getMintedForChain(uint64 chainSelector) external view returns (uint256) {
        return mintedPerChain[chainSelector];
    }

    /**
     * @notice Get amount of tokens burned for a specific chain
     * @param chainSelector The chain selector to check
     */
    function getBurnedForChain(uint64 chainSelector) external view returns (uint256) {
        return burnedPerChain[chainSelector];
    }

    /**
     * @notice Get net minted amount (minted - burned) for a specific chain
     * @param chainSelector The chain selector to check
     */
    function getNetMintedForChain(uint64 chainSelector) external view returns (uint256) {
        return mintedPerChain[chainSelector] - burnedPerChain[chainSelector];
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