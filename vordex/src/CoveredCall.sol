// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";


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

contract CoveredCall {
    // using SafeMath for uint256;

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
        uint256 _premium
    ) {
        seller = msg.sender;
        weth = _weth;
        dai = _dai;
        uniswapRouter = _uniswapRouter;
        strikePrice = _strikePrice;
        expiration = _expiration;
        premium = _premium;
    }

    function buyOption() external {
        require(block.timestamp < expiration, "Option expired");
        require(!optionSold, "Option already sold");
        
        IERC20(dai).transferFrom(msg.sender, address(this), premium);
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
        IWETH(weth).withdraw(amountToSell);
        
        // Swap WETH for DAI on Uniswap
        IERC20(weth).approve(uniswapRouter, amountToSell);
        // Call Uniswap swap function to sell WETH for DAI
        
        // Send the DAI proceeds to the buyer
        // Assuming the swap on Uniswap has been successful and returned DAI

        optionExercised = true;

        emit OptionExercised(buyer, amountToSell);
    }

    function expireWorthless() external {
        require(msg.sender == seller, "Only seller can expire worthless");
        require(block.timestamp >= expiration, "Option not expired yet");
        require(!optionExercised, "Option already exercised");

        uint256 amountToReclaim = escrowAmount;
        IWETH(weth).withdraw(amountToReclaim);
        
        payable(seller).transfer(amountToReclaim);

        emit OptionExpired(seller);
    }

    function getCurrentPrice() public view returns (uint256) {
        // Mock current price, should be fetched from an oracle
        return 60; // Example value
    }

    function escrowWETH(uint256 amount) external {
        require(msg.sender == seller, "Only seller can escrow");
        escrowAmount = amount;
        IWETH(weth).deposit{value: amount}();
    }

    receive() external payable {}
}
