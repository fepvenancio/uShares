// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { USharesToken } from "../tokenization/USharesToken.sol";
import { IERC20Metadata } from "interfaces/IERC20Metadata.sol";
import { BaseModule } from "libraries/base/BaseModule.sol";

import { Errors } from "libraries/core/Errors.sol";
import { Events } from "libraries/core/Events.sol";

contract uSharesTokenRegistry is BaseModule {
    string public namePrefix = "uShares ";
    string public symbolPrefix = "u ";
    mapping(address => string) public customSymbols;

    constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseModule(moduleId_, moduleVersion_) { }

    function getUSharesToken(address asset) external view returns (address uSharesToken) {
        return uSharesTokens[asset];
    }

    function getUSharesTokenByIndex(uint16 index) external view returns (address asset, address uSharesToken) {
        Errors.verifyLength(index, uSharesTokenAssetLists.length);
        asset = uSharesTokenAssetLists[index];
        uSharesToken = uSharesTokens[asset];
    }

    function getUSharesTokenAssetList() external view returns (address[] memory) {
        return uSharesTokenAssetLists;
    }

    function allUSharesTokenAssetLength() external view returns (uint256) {
        return uSharesTokenAssetLists.length;
    }

    function createUSharesToken(address asset, uint256 preMint) external returns (address uSharesToken) {
        Errors.verifyAddress(asset);
        Errors.verifyAddress(uSharesTokens[asset]);

        string memory assetSymbol = customSymbols[asset];
        if (bytes(assetSymbol).length == 0) {
            assetSymbol = IERC20Metadata(asset).symbol();
        }
        string memory uSharesTokenName = string(abi.encodePacked(namePrefix, " ", assetSymbol));
        string memory uSharesTokenSymbol = string(abi.encodePacked(symbolPrefix, assetSymbol));

        uint8 decimals = IERC20Metadata(asset).decimals();
        address minter = _proxyLookup[4];

        uSharesToken = address(
            new USharesToken(uSharesTokenName, uSharesTokenSymbol, decimals, type(uint256).max, preMint, asset, minter)
        );

        uSharesTokens[asset] = uSharesToken;
        uSharesTokenAssetLists.push(asset);

        emit Events.USharesTokenCreated(asset, uSharesToken, uSharesTokenAssetLists.length);
    }

    function addCustomeSymbols(address[] memory assets_, string[] memory symbols_) external {
        uint256 length = assets_.length;
        Errors.verifyLength(assets_.length, symbols_.length);
        for (uint256 i; i < length;) {
            customSymbols[assets_[i]] = symbols_[i];
            unchecked {
                ++i;
            }
        }
    }
}
