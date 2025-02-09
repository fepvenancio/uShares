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

contract CrossChainTransfer is Script {
    // Contract addresses
    address constant USHARES = 0xC151a8a6A14a746b64C7A5Dd7AD1022de3EcF458;
    address constant ROUTER = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;
    address constant TOKEN_POOL = 0x00BB7d031fbbe133f2D12Eb7F12df55EC58Dbc9D;
    
    // Chain Selector for Polygon from CCIP docs
    uint64 constant POLYGON_CHAIN_SELECTOR = 15971525489660198786;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(privateKey);
        
        console.log("Starting cross-chain transfer from Base to Polygon");
        console.log("Sender address:", sender);

        vm.startBroadcast(privateKey);

        USharesToken baseToken = USharesToken(USHARES);

        // Grant burner role to token pool if not already granted
        if (!baseToken.isBurner(TOKEN_POOL)) {
            console.log("Granting burner role to token pool");
            baseToken.grantBurnRole(TOKEN_POOL);
        }

        // 1. Mint tokens on Base (100 tokens)
        uint256 amount = 100 * 1e18; 
        baseToken.mint(sender, amount);
        console.log("Minted on Base:", amount);

        // 2. Approve Router
        baseToken.approve(ROUTER, amount);
        console.log("Approved Router to spend:", amount);

        // 3. Create token amount array
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: USHARES,
            amount: amount
        });

        // 4. Prepare EVMExtraArgsV2
        Client.EVMExtraArgsV2 memory extraArgs = Client.EVMExtraArgsV2({
            gasLimit: 200000,
            allowOutOfOrderExecution: false
        });

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
        bytes32 messageId = router.ccipSend{value: fee}(POLYGON_CHAIN_SELECTOR, message);
        console.log("Transfer initiated, messageId:", vm.toString(messageId));

        vm.stopBroadcast();
    }
}
