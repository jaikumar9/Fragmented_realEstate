// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DepositAndGetRealTokenContract is ReentrancyGuard {
    address public owner;
    uint256 public constant TOKEN_PRICE = 1e18; // 1 USDT = 1 REAL token
    IERC20 public RealToken;
    IERC20 public USDT;
    IERC20 public USDC;

    mapping(address => uint256) public tokensPurchased;
    uint256 public totalCollectedUSDT;
    uint256 public totalCollectedUSDC;
    uint256 public totalRealTokens;

    bool public paused;

    event TokensDeposited(uint256 amount);
    event TokensWithdrawn(uint256 amount);
    event TokensPurchased(address buyer, uint256 amount);

    constructor(
        address _owner,
        address _RealToken,
        address _usdtAddress,
        address _usdcAddress
    ) {
        require(_RealToken != address(0), "Invalid presale token address");
        require(_usdtAddress != address(0), "Invalid USDT address");
        require(_usdcAddress != address(0), "Invalid USDC address");

        RealToken = IERC20(_RealToken);
        USDT = IERC20(_usdtAddress);
        USDC = IERC20(_usdcAddress);

        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not an owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function depositRealTokens(uint256 amount) external onlyOwner {
        require(
            RealToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );
        totalRealTokens += amount;
        emit TokensDeposited(amount);
    }

    function withdrawRealTokens(uint256 amount) external onlyOwner {
        require(totalRealTokens >= amount, "Not Enough Tokens to Withdraw");
        require(
            RealToken.transfer(msg.sender, amount),
            "Token transfer failed"
        );
        totalRealTokens -= amount;
        emit TokensWithdrawn(amount);
    }

    function buyTokensWithUSDT(uint256 usdtAmount) external nonReentrant whenNotPaused {
        require(usdtAmount >= 1e18, "Must send at least 1 USDT");
        uint256 tokensToBuy = usdtAmount; // 1 USDT = 1 REAL token
        require(
            RealToken.balanceOf(address(this)) >= tokensToBuy,
            "Not enough tokens available"
        );
        require(
            USDT.allowance(msg.sender, address(this)) >= usdtAmount,
            "Insufficient USDT allowance"
        );
        
        require(
            USDT.transferFrom(msg.sender, address(this), usdtAmount),
            "USDT transfer failed"
        );

        totalCollectedUSDT += usdtAmount;
        tokensPurchased[msg.sender] += tokensToBuy;
        require(
            RealToken.transfer(msg.sender, tokensToBuy),
            "Token transfer failed"
        );
        totalRealTokens -= tokensToBuy;

        emit TokensPurchased(msg.sender, tokensToBuy);
    }

    function buyTokensWithUSDC(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(usdcAmount >= 1e18, "Must send at least 1 USDC");
        uint256 tokensToBuy = usdcAmount; // 1 USDC = 1 REAL token
        require(
            RealToken.balanceOf(address(this)) >= tokensToBuy,
            "Not enough tokens available"
        );
        require(
            USDC.allowance(msg.sender, address(this)) >= usdcAmount,
            "Insufficient USDC allowance"
        );
        require(
            USDC.transferFrom(msg.sender, address(this), usdcAmount),
            "USDC transfer failed"
        );

        totalCollectedUSDC += usdcAmount;
        tokensPurchased[msg.sender] += tokensToBuy;
        require(
            RealToken.transfer(msg.sender, tokensToBuy),
            "Token transfer failed"
        );
        totalRealTokens -= tokensToBuy;

        emit TokensPurchased(msg.sender, tokensToBuy);
    }

    function WithdrawUSDT_with_RT(uint256 RTAmt) external nonReentrant {
        require(RTAmt >= 10 * 1e18, "You need at least 10 Real Tokens");

        uint256 usdtAmount = RTAmt; // 1 RT = 1 USDT

        require(
            USDT.balanceOf(address(this)) >= usdtAmount,
            "Not enough USDT in contract"
        );

        require(
            RealToken.transferFrom(msg.sender, address(this), RTAmt),
            "RT Token transfer failed"
        );

        require(
            USDT.transfer(msg.sender, usdtAmount),
            "USDT transfer failed"
        );

        totalRealTokens += RTAmt;
        totalCollectedUSDT -= usdtAmount;

        emit TokensDeposited(RTAmt);
    }

    function withdrawCollectedUSDT(uint256 _amount) external onlyOwner {
        uint256 totalUsdtAmount = USDT.balanceOf(address(this));
        require(_amount <= totalUsdtAmount, "Not sufficient USDT to withdraw");

        require(USDT.transfer(owner, _amount), "USDT transfer to owner failed");
        
        totalCollectedUSDT -= _amount;  
    }

    function withdrawCollectedUSDC(uint256 _amount) external onlyOwner {
        uint256 totalUsdcAmount = USDC.balanceOf(address(this));
        require(_amount <= totalUsdcAmount, "Not sufficient USDC to withdraw");

        require(USDC.transfer(owner, _amount), "USDC transfer to owner failed");
        
        totalCollectedUSDC -= _amount;  
    }

    function AddUSDT(uint256 amt) external onlyOwner {
        require( USDT.transferFrom(msg.sender, address(this), amt), "Insufficient USDT");
        totalCollectedUSDT += amt;
    }

    function AddUSDC(uint256 amt) external onlyOwner {
        require( USDC.transferFrom(msg.sender, address(this), amt), "Insufficient USDC");
        totalCollectedUSDC += amt;
    }

    function getRemaininRTokens() external view returns (uint256) {
        return RealToken.balanceOf(address(this));
    }

    function getTokensPurchasedByUser(address user) external view returns (uint256) {
        return tokensPurchased[user];
    }

    function getTotalRealTokens() external view returns (uint256) {
        return totalRealTokens;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    receive() external payable {}
}
