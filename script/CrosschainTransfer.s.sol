// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { USharesToken } from "../src/protocol/tokenization/USharesToken.sol";
import { Client } from "chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IRouterClient {
    function ccipSend(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    )
        external
        payable
        returns (bytes32);

    function getFee(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    )
        external
        view
        returns (uint256 fee);
}

contract CrossChainTransfer is Script {
    // Contract addresses
    address constant USHARES_BASE = 0x5a44dCE25ab945b625e6A92f9E95Beac953033df;
    address constant ROUTER = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    address constant TOKEN_POOL = 0x6b4e324d91bc3ffE7b398B674B3A8f32bF43cB1A;

    // Chain Selector for Polygon from CCIP docs
    uint64 constant POLYGON_CHAIN_SELECTOR = 3_734_403_246_176_062_136;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(privateKey);

        console.log("Starting cross-chain transfer from Base to Polygon");
        console.log("Sender address:", sender);

        vm.startBroadcast(privateKey);

        USharesToken baseToken = USharesToken(USHARES_BASE);

        // Grant burner role to token pool if not already granted
        if (!baseToken.isBurner(TOKEN_POOL)) {
            console.log("Granting burner role to token pool");
            baseToken.grantBurnRole(TOKEN_POOL);
        }

        // 1. Mint tokens on Base (100 tokens)
        uint256 amount = 100 * 1e6; // 100 tokens with 6 decimals
        baseToken.mint(sender, amount);
        console.log("Minted on Base:", amount);

        // 2. Approve Router
        baseToken.approve(ROUTER, amount);
        console.log("Approved Router to spend:", amount);

        // 3. Create token amount array
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({ token: USHARES_BASE, amount: amount });

        // 4. Prepare EVMExtraArgsV2
        Client.EVMExtraArgsV2 memory extraArgs =
            Client.EVMExtraArgsV2({ gasLimit: 200_000, allowOutOfOrderExecution: false });

        // 5. Create CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sender),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(extraArgs),
            feeToken: address(0) // Use native token for fees
         });

        // 6. Get the fee
        IRouterClient router = IRouterClient(ROUTER);
        uint256 fee = router.getFee(POLYGON_CHAIN_SELECTOR, message);
        console.log("CCIP Fee:", fee);

        // 7. Send CCIP Message
        bytes32 messageId = router.ccipSend{ value: fee }(POLYGON_CHAIN_SELECTOR, message);
        console.log("Transfer initiated, messageId:", vm.toString(messageId));

        vm.stopBroadcast();
    }
}
