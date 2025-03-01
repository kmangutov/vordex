// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console2.sol"; // Debugging

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract CoveredCallEscrow {
    address private constant CHAINLINK_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address private constant SWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 private constant FEE = 3000;

    enum State { Open, Locked, Exercised, Expired }

    struct CoveredCall {
        address seller;
        address buyer;
        uint256 strikePrice;
        uint256 expiration;
        uint256 premium;
        uint256 escrowedAmount;
        State state;
    }

    mapping(uint256 => CoveredCall) public calls;
    uint256 public callCount;

    event CallCreated(uint256 indexed callId, address indexed seller, uint256 strikePrice, uint256 expiration);
    event CallLocked(uint256 indexed callId, address indexed buyer, uint256 premium);
    event CallExercised(uint256 indexed callId);
    event CallExpired(uint256 indexed callId);

    function createCall(uint256 strikePrice, uint256 expiration, uint256 escrowedAmount) external returns (uint256) {
        require(expiration > block.timestamp, "Expiration must be in the future");

        console2.log("Creating call - Seller:", msg.sender);
        console2.log("Strike Price:", strikePrice, "Expiration:", expiration);
        console2.log("Escrowing WETH:", escrowedAmount);

        IERC20(WETH).transferFrom(msg.sender, address(this), escrowedAmount);

        uint256 callId = callCount++;
        calls[callId] = CoveredCall({
            seller: msg.sender,
            buyer: address(0),
            strikePrice: strikePrice,
            expiration: expiration,
            premium: 0,
            escrowedAmount: escrowedAmount,
            state: State.Open
        });

        emit CallCreated(callId, msg.sender, strikePrice, expiration);
        return callId;
    }

    function lockCall(uint256 callId, uint256 premiumAmount) external {
        CoveredCall storage call = calls[callId];

        require(call.state == State.Open, "Call is not open");
        require(call.expiration > block.timestamp, "Call has expired");
        require(call.buyer == address(0), "Already locked");

        console2.log("Locking call - Buyer:", msg.sender);
        console2.log("Premium Paid:", premiumAmount);

        IERC20(USDC).transferFrom(msg.sender, address(this), premiumAmount);

        call.buyer = msg.sender;
        call.premium = premiumAmount;
        call.state = State.Locked;

        emit CallLocked(callId, msg.sender, premiumAmount);
    }

    function exercise(uint256 callId) external {
        CoveredCall storage call = calls[callId];

        require(call.state == State.Locked, "Call is not locked");
        require(call.expiration > block.timestamp, "Call has expired");
        require(call.buyer == msg.sender, "Only buyer can exercise");

        uint256 currentPrice = uint256(IChainlinkAggregator(CHAINLINK_FEED).latestAnswer());
        uint256 adjustedPrice = currentPrice / 1e2; // Convert from 8 decimals to 6 decimals

        console2.log("Exercising call - Buyer:", msg.sender);
        console2.log("Current Price (scaled to 6 decimals):", adjustedPrice, "Strike Price:", call.strikePrice);

        require(adjustedPrice >= call.strikePrice, "Not ITM");

        IERC20(WETH).approve(SWAP_ROUTER, call.escrowedAmount);

        ISwapRouter02(SWAP_ROUTER).exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: USDC,
                fee: FEE,
                recipient: call.buyer,
                amountIn: call.escrowedAmount,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            })
        );

        call.state = State.Exercised;
        emit CallExercised(callId);
    }

    function expire(uint256 callId) external {
        CoveredCall storage call = calls[callId];

        require(call.state == State.Locked, "Call is not locked");
        require(call.expiration <= block.timestamp, "Not expired yet");

        console2.log("Expiring call - Seller:", call.seller);

        IERC20(WETH).transfer(call.seller, call.escrowedAmount);
        IERC20(USDC).transfer(call.seller, call.premium);

        call.state = State.Expired;
        emit CallExpired(callId);
    }
}
