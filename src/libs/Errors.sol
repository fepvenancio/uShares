// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Errors {
    // Access control errors
    error NotOwner();
    error NotMinter();
    error NotBurner();
    error NotTokenPool();
    error NotPositionManager();
    error NotCCIPAdmin();
    error NotHandler();
    error Unauthorized();

    // Input validation errors
    error ZeroAddress(address addr);
    error ZeroBytes(bytes32 key);
    error ZeroNumber(uint256 num);
    error ZeroChainId();
    error InvalidAmount();
    error InvalidChain();
    error InvalidVault();
    error InvalidDeposit();
    error InvalidDestination();
    error InvalidAsset();

    // State errors
    error VaultNotActive();
    error VaultActive();
    error VaultExists();
    error Paused();
    error CCTPAlreadyCompleted();
    error DepositExpired();
    error PositionExists();
    error PositionNotFound();
    error ActiveShares();
    error InsufficientShares();
    error InsufficientAllowance();
    error DuplicateMessage();
    error ExceedsMaxSize();
    error SuspiciousSharePriceChange();

    // Validation functions
    function verifyAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert ZeroAddress(addr);
        }
    }

    function verifyBytes32(bytes32 key) internal pure {
        if (key == bytes32(0)) {
            revert ZeroBytes(key);
        }
    }

    function verifyNumber(uint256 num) internal pure {
        if (num == 0) {
            revert ZeroNumber(num);
        }
    }

    function verifyChainId(uint32 chainId) internal pure {
        if (chainId == 0) revert ZeroChainId();
    }
}
