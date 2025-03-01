// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import "../src/PriceFetcher.sol";

contract PriceFetcherTest is Test {
    PriceFetcher private fetcher;

    function setUp() public {
        fetcher = new PriceFetcher();
    }

    function test_getETHPrice() public {
        uint256 ethPrice = fetcher.getETHPrice();
        console2.log("ETH/USD Price from Chainlink:", ethPrice);

        assertGt(ethPrice, 0, "Expected ETH price to be greater than 0");
    }
}
