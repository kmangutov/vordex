// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CoveredCall} from "../src/CoveredCall.sol";


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount)
        external
        returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}



address constant SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

contract CoveredCallTest is Test {
    CoveredCall public coveredCall;
    address public weth = address(WETH);
    address public dai = address(DAI);
    address public uniswapRouter = address(SWAP_ROUTER_02);
    address public buyer = address(0x1234567890AbcdEF1234567890aBcdef12345678); // Fixed, checksummed buyer address
    uint256 public strikePrice = 1000;
    uint256 public expiration = block.timestamp + 1 weeks;
    uint256 public premium = 50;

    function setUp() public {
        coveredCall = new CoveredCall(weth, dai, uniswapRouter, strikePrice, expiration, premium);

        // Fund the buyer with DAI (to purchase the option)
        deal(dai, buyer, premium); // Give buyer some DAI for premium

        // Fund the contract (seller) with WETH (for escrow)
        deal(weth, address(this), premium); // Give contract WETH for escrow
    }

    function test_BuyOption() public {
        deal(dai, buyer, premium);
        vm.prank(buyer);
        coveredCall.buyOption();
        assertEq(coveredCall.buyer(), buyer);
        assertTrue(coveredCall.optionSold());
    }

    function test_ExerciseOption() public {
        deal(dai, buyer, premium);
        vm.prank(buyer);
        coveredCall.buyOption();
        vm.mockCall(address(coveredCall), abi.encodeWithSignature("getCurrentPrice()"), abi.encode(strikePrice + 1));
        vm.prank(buyer);
        coveredCall.exerciseOption();
        assertTrue(coveredCall.optionExercised());
    }

    function test_ExpireWorthless() public {
        deal(weth, address(this), premium); // Fund the contract (seller) with WETH for escrow
        vm.warp(expiration + 1); // Move time past the expiration
        vm.prank(address(this));
        coveredCall.expireWorthless();
        assertEq(address(this).balance, premium); // Ensure escrow was returned to the seller
    }

    // Renamed the deal function to avoid override issue
    function mockDeal(address token, address to, uint256 amount) internal {
        super.deal(token, to, amount); // Calls the deal function from the parent (forge-std) library
    }
}
