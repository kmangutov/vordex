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

        // Fund seller & buyer with WETH and USDC
        deal(WETH, seller, 10 ether);
        deal(USDC, buyer, 5000 * 1e6); // USDC has 6 decimals

        vm.startPrank(seller);
        IERC20(WETH).approve(address(escrow), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(buyer);
        IERC20(USDC).approve(address(escrow), type(uint256).max);
        vm.stopPrank();
    }

    function test_exerciseCoveredCall() public {
        vm.startPrank(seller);
        uint256 callId = escrow.createCall(3000 * 1e6, block.timestamp + 1 days, 1 ether);
        console2.log("Covered Call Created: ID", callId);
        vm.stopPrank();

        vm.startPrank(buyer);
        escrow.lockCall(callId, 100 * 1e6);
        console2.log("Buyer Locked Call: ID", callId);
        vm.stopPrank();

        // Mock ETH price going ITM (Above Strike Price)
        vm.mockCall(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // Chainlink ETH/USD price feed
            abi.encodeWithSignature("latestAnswer()"),
            abi.encode(3100 * 1e8) // Chainlink prices are in 8 decimals
        );
        console2.log("Mocked ETH Price: 3100 USDC");

        uint256 buyerUSDCBefore = IERC20(USDC).balanceOf(buyer);
        console2.log("Buyer USDC Before Exercise:", buyerUSDCBefore);

        vm.startPrank(buyer);
        escrow.exercise(callId);
        vm.stopPrank();

        uint256 buyerUSDCAfter = IERC20(USDC).balanceOf(buyer);
        console2.log("Buyer USDC After Exercise:", buyerUSDCAfter);

        assertGt(buyerUSDCAfter, buyerUSDCBefore, "Expected USDC balance to increase after exercise");
    }


    function test_expireCoveredCall() public {
        vm.startPrank(seller);
        uint256 callId = escrow.createCall(3500 * 1e6, block.timestamp + 1 days, 1 ether);
        vm.stopPrank();

        vm.startPrank(buyer);
        escrow.lockCall(callId, 100 * 1e6);
        vm.stopPrank();

        uint256 sellerWETHBefore = IERC20(WETH).balanceOf(seller);
        uint256 sellerUSDCBefore = IERC20(USDC).balanceOf(seller);
        console2.log("Seller WETH Before Expiration:", sellerWETHBefore);
        console2.log("Seller USDC Before Expiration:", sellerUSDCBefore);

        vm.warp(block.timestamp + 2 days);

        vm.startPrank(seller);
        escrow.expire(callId);
        vm.stopPrank();

        uint256 sellerWETHAfter = IERC20(WETH).balanceOf(seller);
        uint256 sellerUSDCAfter = IERC20(USDC).balanceOf(seller);
        console2.log("Seller WETH After Expiration:", sellerWETHAfter);
        console2.log("Seller USDC After Expiration:", sellerUSDCAfter);

        assertGt(sellerWETHAfter, sellerWETHBefore, "Expected WETH balance to increase after expiration");
        assertGt(sellerUSDCAfter, sellerUSDCBefore, "Expected USDC premium to be returned after expiration");
    }

    function test_cannotExpireBeforeExpiration() public {
        vm.startPrank(seller);
        uint256 callId = escrow.createCall(3200 * 1e6, block.timestamp + 1 days, 1 ether);
        vm.stopPrank();

        vm.startPrank(buyer);
        escrow.lockCall(callId, 100 * 1e6);
        vm.stopPrank();

        vm.expectRevert("Not expired yet");
        vm.startPrank(seller);
        escrow.expire(callId);
        vm.stopPrank();
    }

    function test_cannotExerciseIfNotITM() public {
        vm.startPrank(seller);
        uint256 callId = escrow.createCall(3500 * 1e6, block.timestamp + 1 days, 1 ether);
        vm.stopPrank();

        vm.startPrank(buyer);
        escrow.lockCall(callId, 100 * 1e6);
        vm.stopPrank();

        // Correctly mock Chainlink `latestAnswer()` function
        vm.mockCall(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // Chainlink ETH/USD price feed
            abi.encodeWithSignature("latestAnswer()"),
            abi.encode(3400 * 1e8) // Chainlink prices are in 8 decimals
        );

        console2.log("Mocked ETH Price: 3400 USDC, should be below strike price");

        vm.expectRevert("Not ITM");
        vm.startPrank(buyer);
        escrow.exercise(callId);
        vm.stopPrank();
    }

}
