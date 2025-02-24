// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract CoveredCall {
    address public seller; 
    address public buyer;
    address public weth;
    address public dai;
    address public uniswapRouter;
    uint256 public strikePrice;
    uint256 public expiration;
    uint256 public premium;
    bool public optionSold;
    bool public optionExercised;
    uint256 public escrowAmount;
    address public token; // For handling different tokens like WETH, DAI, USDC

    // Events for logging
    event OptionPurchased(address indexed buyer);
    event OptionExercised(address indexed buyer, uint256 amountSold);
    event OptionExpired(address indexed seller);

    constructor(
        address _weth,
        address _dai,
        address _uniswapRouter,
        uint256 _strikePrice,
        uint256 _expiration,
        uint256 _premium,
        address _token
    ) {
        seller = msg.sender;
        weth = _weth;
        dai = _dai;
        uniswapRouter = _uniswapRouter;
        strikePrice = _strikePrice;
        expiration = _expiration;
        premium = _premium;
        token = _token;
    }

    function buyOption() external {
        require(block.timestamp < expiration, "Option expired");
        require(!optionSold, "Option already sold");

        IERC20(token).transferFrom(msg.sender, address(this), premium);
        buyer = msg.sender;
        optionSold = true;

        emit OptionPurchased(msg.sender);
    }

    function exerciseOption() external {
        require(msg.sender == buyer, "Only buyer can exercise");
        require(block.timestamp < expiration, "Option expired");
        require(optionSold, "Option not sold");
        require(!optionExercised, "Option already exercised");
        require(getCurrentPrice() >= strikePrice, "Option is not ITM");

        uint256 amountToSell = escrowAmount;
        IERC20(token).transfer(buyer, amountToSell);

        optionExercised = true;

        emit OptionExercised(buyer, amountToSell);
    }

    function expireWorthless() external {
        require(msg.sender == seller, "Only seller can expire worthless");
        require(block.timestamp >= expiration, "Option not expired yet");
        require(!optionExercised, "Option already exercised");

        uint256 amountToReclaim = escrowAmount;
        IERC20(token).transfer(seller, amountToReclaim);

        emit OptionExpired(seller);
    }

    function getCurrentPrice() public view returns (uint256) {
        // Mock current price, should be fetched from an oracle
        return 60; // Example value
    }

    function escrowTokens(uint256 amount) external {
        require(msg.sender == seller, "Only seller can escrow");
        escrowAmount = amount;
        IERC20(token).transferFrom(seller, address(this), amount);
    }

    receive() external payable {}
}
