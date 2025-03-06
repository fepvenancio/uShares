// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract UShares {

    // Needs to: be in any EVM. 
    // chainId 
    // deposit:
    // -> first: choose, chainId, vaultAddress, amount
    // -> fourth: burn/deposit(if same chain) to the desired vault. 
    // -> fifth: on destination chain, get the info, deposit, mint the uShares on the destination chain equivalent to the amount deposited/shares received.

    // Next step: burn/mint USDC validate if we can bridge information from one chain to another.
}
