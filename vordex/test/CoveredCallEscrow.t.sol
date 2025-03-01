// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import "../src/CoveredCallEscrow.sol";

contract CoveredCallEscrowTest is Test {
    CoveredCallEscrow private escrow;
    address private seller;
    address private buyer;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {
        escrow = new CoveredCallEscrow();

        seller = vm.addr(1);
        buyer = vm.addr(2);

        // Fund seller & buyer
        deal(WETH, seller, 10 ether);
        deal(USDC, buyer, 5000 * 1e6); // USDC has 6 decimals

        vm.prank(seller);
        IERC20(WETH).approve(address(escrow), type(uint256).max);

        vm.prank(buyer);
        IERC20(USDC).approve(address(escrow), type(uint256).max);
    }

    function test_exerciseCoveredCall() public {
        vm.startPrank(seller);
        uint256 callId = escrow.createCall(3000 * 1e6, block.timestamp + 1 days, 1 ether);
        vm.stopPrank();

        vm.startPrank(buyer);
        escrow.lockCall(callId, 100 * 1e6);
        vm.stopPrank();

        vm.mockCall(address(escrow), abi.encodeWithSignature("getETHPrice()"), abi.encode(3100 * 1e6));

        vm.startPrank(buyer);
        escrow.exercise(callId);
        vm.stopPrank();
    }

    function test_expireCoveredCall() public {
        vm.startPrank(seller);
        uint256 callId = escrow.createCall(3500 * 1e6, block.timestamp + 1 days, 1 ether);
        vm.stopPrank();

        vm.startPrank(buyer);
        escrow.lockCall(callId, 100 * 1e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);

        vm.startPrank(seller);
        escrow.expire(callId);
        vm.stopPrank();
    }
}
