// SPDX-License-Identifier: MIT
pragma solidity 0.8.29; // Network configuration helper

import { AddressBook } from "./utils/AddressBook.sol";
import { Config } from "./utils/Config.s.sol";
import { RateLimiter } from "chainlink/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import { TokenPool } from "chainlink/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { Script, console } from "forge-std/Script.sol";

contract ApplyChainUpdates is Script {
    address tokenAddress;
    address tokenAdmin;
    address poolAddress;
    address remotePoolAddress;
    address remoteTokenAddress;
    uint64 remoteChainSelector;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        if (block.chainid == AddressBook.OPTIMISM) {
            tokenAddress = AddressBook.OP_USharesToken;
            poolAddress = AddressBook.OP_POOL;
            remotePoolAddress = AddressBook.BASE_POOL;
            remoteTokenAddress = AddressBook.BASE_USharesToken;
            remoteChainSelector = AddressBook.BASE_CHAIN_SELECTOR;
        } else if (block.chainid == AddressBook.BASE) {
            tokenAddress = AddressBook.BASE_USharesToken;
            poolAddress = AddressBook.BASE_POOL;
            remotePoolAddress = AddressBook.OP_POOL;
            remoteTokenAddress = AddressBook.OP_USharesToken;
            remoteChainSelector = AddressBook.OP_CHAIN_SELECTOR;
        } else {
            revert("Unsupported chain ID");
        }

        address[] memory remotePoolAddresses = new address[](1);
        remotePoolAddresses[0] = remotePoolAddress;

        require(poolAddress != address(0), "Invalid pool address");
        require(remotePoolAddress != address(0), "Invalid remote pool address");
        require(remoteTokenAddress != address(0), "Invalid remote token address");
        require(remoteChainSelector != 0, "chainSelector is not defined for the remote chain");

        vm.startBroadcast(deployerPrivateKey);

        // Instantiate the local TokenPool contract
        TokenPool poolContract = TokenPool(poolAddress);

        // Prepare chain update data for configuring cross-chain transfers
        TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);

        // Encode remote pool addresses
        bytes[] memory remotePoolAddressesEncoded = new bytes[](remotePoolAddresses.length);
        for (uint256 i = 0; i < remotePoolAddresses.length; i++) {
            remotePoolAddressesEncoded[i] = abi.encode(remotePoolAddresses[i]);
        }

        chainUpdates[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector, // Chain selector of the remote chain
            remotePoolAddresses: remotePoolAddressesEncoded, // Array of encoded addresses of the remote pools
            remoteTokenAddress: abi.encode(remoteTokenAddress), // Encoded address of the remote token
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // Set to true to enable outbound rate limiting
                capacity: 0, // Max tokens allowed in the outbound rate limiter
                rate: 0 // Refill rate per second for the outbound rate limiter
             }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, // Set to true to enable inbound rate limiting
                capacity: 0, // Max tokens allowed in the inbound rate limiter
                rate: 0 // Refill rate per second for the inbound rate limiter
             })
        });

        // Create an empty array for chainSelectorRemovals
        uint64[] memory chainSelectorRemovals = new uint64[](0);

        // Apply the chain updates to configure the pool
        poolContract.applyChainUpdates(chainSelectorRemovals, chainUpdates);

        console.log("Chain update applied to pool at address:", poolAddress);

        vm.stopBroadcast();
    }
}
