// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Errors
 * @notice Library containing all custom errors used in the protocol
 * @dev Centralizes error definitions and provides validation utilities
 * @custom:security-contact security@ushares.com
 */
library Errors {
    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when caller is not the owner
    error NotOwner();
    /// @notice Thrown when caller is not a minter
    error NotMinter();
    /// @notice Thrown when caller is not a burner
    error NotBurner();
    /// @notice Thrown when caller is not a token pool
    error NotTokenPool();
    /// @notice Thrown when caller is not the position manager
    error NotPositionManager();
    /// @notice Thrown when caller is not a CCIP admin
    error NotCCIPAdmin();
    /// @notice Thrown when caller is not a handler
    error NotHandler();
    /// @notice Thrown when caller is not authorized
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                            INPUT VALIDATION ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an address parameter is zero
    error ZeroAddress(address addr);
    /// @notice Thrown when a bytes32 parameter is zero
    error ZeroBytes(bytes32 key);
    /// @notice Thrown when a number parameter is zero
    error ZeroNumber(uint256 num);
    /// @notice Thrown when a chain ID is zero
    error ZeroChainId();
    /// @notice Thrown when an amount is invalid
    error InvalidAmount();
    /// @notice Thrown when a chain ID is invalid
    error InvalidChain();
    /// @notice Thrown when a vault address is invalid
    error InvalidVault();
    /// @notice Thrown when a deposit ID is invalid
    error InvalidDeposit();
    /// @notice Thrown when a withdrawal ID is invalid
    error InvalidWithdrawal();
    /// @notice Thrown when a destination is invalid
    error InvalidDestination();
    /// @notice Thrown when an asset address is invalid
    error InvalidAsset();

    /*//////////////////////////////////////////////////////////////
                            STATE ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when vault is not active
    error VaultNotActive();
    /// @notice Thrown when vault is active but should not be
    error VaultActive();
    /// @notice Thrown when vault already exists
    error VaultExists();
    /// @notice Thrown when contract is paused
    error Paused();
    /// @notice Thrown when CCTP transfer is already completed
    error CCTPAlreadyCompleted();
    /// @notice Thrown when deposit has expired
    error DepositExpired();
    /// @notice Thrown when position already exists
    error PositionExists();
    /// @notice Thrown when position is not found
    error PositionNotFound();
    /// @notice Thrown when shares are already active
    error ActiveShares();
    /// @notice Thrown when shares are insufficient
    error InsufficientShares();
    /// @notice Thrown when allowance is insufficient
    error InsufficientAllowance();
    /// @notice Thrown when message is duplicate
    error DuplicateMessage();
    /// @notice Thrown when transaction size exceeds maximum
    error ExceedsMaxSize();
    /// @notice Thrown when share price change is suspicious
    error SuspiciousSharePriceChange();
    /// @notice Thrown when message is invalid
    error InvalidMessage();
    /// @notice Thrown when withdrawal has expired
    error WithdrawalExpired();
    /// @notice Thrown when USDC amount is insufficient
    error InsufficientUSDC();
    /// @notice Thrown when withdrawal is already processed
    error WithdrawalProcessed();

    /*//////////////////////////////////////////////////////////////
                            VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that an address is not zero
     * @dev Reverts with ZeroAddress if address is zero
     * @param addr Address to verify
     */
    function verifyAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert ZeroAddress(addr);
        }
    }

    /**
     * @notice Verifies that a bytes32 value is not zero
     * @dev Reverts with ZeroBytes if value is zero
     * @param key Bytes32 value to verify
     */
    function verifyBytes32(bytes32 key) internal pure {
        if (key == bytes32(0)) {
            revert ZeroBytes(key);
        }
    }

    /**
     * @notice Verifies that a number is not zero
     * @dev Reverts with ZeroNumber if number is zero
     * @param num Number to verify
     */
    function verifyNumber(uint256 num) internal pure {
        if (num == 0) {
            revert ZeroNumber(num);
        }
    }

    /**
     * @notice Verifies that a chain ID is not zero
     * @dev Reverts with ZeroChainId if chain ID is zero
     * @param chainId Chain ID to verify
     */
    function verifyChainId(uint32 chainId) internal pure {
        if (chainId == 0) revert ZeroChainId();
    }
}
