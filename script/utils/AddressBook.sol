// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library AddressBook {
    // CHAIN IDS
    uint32 constant OPTIMISM = 10;
    uint32 constant BASE = 8453;

    // CHAIN_SELECTORS
    uint64 constant BASE_CHAIN_SELECTOR = 15_971_525_489_660_198_786;
    uint64 constant OP_CHAIN_SELECTOR = 3_734_403_246_176_062_136;

    // DEPLOYED_ADDRESSES
    address constant DEPLOYER_ADDRESS = 0x94aBa23b9Bbfe7bb62A9eB8b1215D72b5f6F33a1;

    address constant BASE_USharesToken = 0x159649a2B75F45349B525be7ab30F2E88f796Ac2;
    address constant BASE_POOL = 0xad6f2f39b82D9e3A2c516a34349e1db7175e5214;

    address constant OP_USharesToken = 0xA3c8461375527BDa3180265A80BE2E4090471b7A;
    address constant OP_POOL = 0x132b7ED2eD014d37ba9ad96aD3d72CC3f0C75917;
}
