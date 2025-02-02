// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IUSharesToken
 * @notice Interface for uShares cross-chain token standard
 * @dev Based on Chainlink's CCT (Cross-Chain Token) standard
 */
interface IUSharesToken {
    // Structs
    struct CrossChainDeposit {
        address user;
        uint256 usdcAmount;
        address sourceVault;
        address targetVault;
        uint32 destinationChain;
        uint256 expectedShares;
        bool cctpCompleted;
        bool sharesIssued;
        uint256 timestamp;
        uint256 minShares;
        uint256 deadline;
    }

    // CCT Standard structs
    struct LockOrBurnInV1 {
        address sender;
        uint256 amount;
        uint64 destinationChainSelector;
        address receiver;
        bytes32 depositId;
    }

    struct ReleaseOrMintInV1 {
        bytes32 depositId;
        address receiver;
        uint256 amount;
        uint64 sourceChainSelector;
    }

    // Events
    event DepositInitiated(
        bytes32 indexed depositId,
        address indexed user,
        uint256 usdcAmount,
        address targetVault,
        uint32 destinationChain,
        uint256 minShares,
        uint256 deadline
    );

    event CCTPCompleted(bytes32 indexed depositId, uint256 usdcAmount, uint32 destinationChain);

    event SharesIssued(bytes32 indexed depositId, address indexed user, uint256 shares);

    event VaultMapped(uint32 indexed chainId, address indexed localVault, address indexed remoteVault);

    event TokensMinted(address indexed to, uint256 amount, uint32 sourceChain, bytes32 messageId);

    event TokensBurned(address indexed from, uint256 amount, uint32 destinationChain, bytes32 messageId);

    // Role management events
    event MinterConfigured(address indexed minter, bool status);
    event BurnerConfigured(address indexed burner, bool status);
    event TokenPoolConfigured(address indexed pool, bool status);
    event RateLimitUpdated(uint32 chainId, bool isOutbound, uint256 rate, uint256 capacity);
    event RemotePoolUpdated(uint32 chainId, address pool, bool allowed);
    event CCIPAdminUpdated(address oldAdmin, address newAdmin);

    // Core functions
    function initiateDeposit(
        address targetVault,
        uint256 usdcAmount,
        uint64 destinationChainSelector,
        uint256 minShares,
        uint256 deadline
    ) external returns (bytes32 depositId);

    function processCCTPCompletion(bytes32 depositId, bytes memory attestation) external;

    function mintSharesFromDeposit(bytes32 depositId, uint256 vaultShares) external;

    // Admin functions
    function setVaultMapping(uint32 chainId, address localVault, address remoteVault) external;

    function setCCTPContract(address cctp) external;
    function setTokenPool(address pool) external;

    // Role management functions
    function configureMinter(address minter, bool status) external;
    function configureBurner(address burner, bool status) external;
    function configureTokenPool(address pool, bool status) external;

    // View functions
    function getDeposit(bytes32 depositId) external view returns (CrossChainDeposit memory);
    function getVaultMapping(uint32 chainId, address localVault) external view returns (address);
    function getCCTPContract() external view returns (address);
    function getChainId() external view returns (uint32);
    function getCCIPAdmin() external view returns (address);
    function getTokenPool() external view returns (address);
}
