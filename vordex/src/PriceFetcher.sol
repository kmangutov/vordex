// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}

contract PriceFetcher {
    address private constant CHAINLINK_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Correct checksummed address

    function getETHPrice() external view returns (uint256) {
        return uint256(IChainlinkAggregator(CHAINLINK_FEED).latestAnswer()); // Price in 8 decimals
    }
}
