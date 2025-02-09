// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/USharesToken.sol";
import {Client} from "chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

interface IRouterClient {
    function ccipSend(uint64 destinationChainSelector, Client.EVM2AnyMessage calldata message) 
        external 
        payable 
        returns (bytes32);

    function getFee(uint64 destinationChainSelector, Client.EVM2AnyMessage calldata message) 
        external 
        view 
        returns (uint256 fee);
}

contract PolygonToBaseTransfer is Script {
    // Contract addresses
    address constant USHARES_POLYGON = 0x063540DAf095A99FeAb73F3B24241Ac362a1FC58;
    address constant ROUTER = 0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe;
    
    // Chain Selector for Base
    uint64 constant BASE_CHAIN_SELECTOR = 15971525489660198786;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(privateKey);
        
        console.log("Starting cross-chain transfer from Polygon to Base");
        console.log("Sender address:", sender);

        vm.startBroadcast(privateKey);

        // 1. Approve Router
        uint256 amount = 100 * 1e6; // 100 tokens with 6 decimals
        USharesToken polygonToken = USharesToken(USHARES_POLYGON);
        polygonToken.approve(ROUTER, amount);
        console.log("Approved Router to spend:", amount);

        // 2. Create token amount array
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: USHARES_POLYGON,
            amount: amount
        });

        // 3. Prepare EVMExtraArgsV2
        Client.EVMExtraArgsV2 memory extraArgs = Client.EVMExtraArgsV2({
            gasLimit: 200000,
            allowOutOfOrderExecution: false
        });

        // 4. Create CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sender),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(extraArgs),
            feeToken: address(0) // Use native token (MATIC) for fees
        });

        // 5. Get the fee
        IRouterClient router = IRouterClient(ROUTER);
        uint256 fee = router.getFee(BASE_CHAIN_SELECTOR, message);
        console.log("CCIP Fee:", fee);

        // 6. Send CCIP Message
        bytes32 messageId = router.ccipSend{value: fee}(BASE_CHAIN_SELECTOR, message);
        console.log("Transfer initiated, messageId:", vm.toString(messageId));

        vm.stopBroadcast();
    }
}
