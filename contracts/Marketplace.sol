// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AdminControlledMarketplace is Ownable, ReentrancyGuard {
    IERC1155 public nftContract;
    IERC20 public realToken;

    // Struct to represent a liquidity pool for a specific token ID
    struct LiquidityPool {
        uint256 totalFractions;
        uint256 availableFractions;
        uint256 basePrice; // Base price in REAL tokens per fraction
        uint256 exponent; // Exponent for dynamic pricing
    }

    // Mapping to track liquidity pools by token ID
    mapping(uint256 => LiquidityPool) public liquidityPools;

    // Event emitted when a new liquidity pool is created
    event LiquidityAdded(uint256 indexed tokenId, uint256 fractions, uint256 basePrice, uint256 exponent);

    // Event emitted when fractions are traded
    event FractionsTraded(uint256 indexed tokenId, address indexed buyer, uint256 fractions, uint256 totalCost);

    // Event emitted when fractions are sold by a user
    event FractionsSold(uint256 indexed tokenId, address indexed seller, uint256 fractions, uint256 totalEarnings);

    /**
     * @dev Constructor to set the NFT contract and REAL token contract addresses.
     * @param _nftContract Address of the already deployed ERC1155 contract.
     * @param _realToken Address of the REAL token contract.
     */
    constructor(address _nftContract, address _realToken) {
        require(_nftContract != address(0), "Invalid NFT contract address");
        require(_realToken != address(0), "Invalid REAL token contract address");
        nftContract = IERC1155(_nftContract);
        realToken = IERC20(_realToken);
    }

    /**
     * @dev Admin adds liquidity for an existing NFT.
     * @param tokenId The ID of the token to list.
     * @param fractions The total number of fractions to add to the liquidity pool.
     * @param basePrice The initial base price per fraction in REAL tokens.
     * @param exponent The exponent for dynamic pricing.
     */
    function addLiquidity(uint256 tokenId, uint256 fractions, uint256 basePrice, uint256 exponent) external onlyOwner {
        require(fractions > 0, "Fractions must be greater than zero");
        require(basePrice > 0, "Base price must be greater than zero");
        require(exponent > 0, "Exponent must be greater than zero");
        require(liquidityPools[tokenId].totalFractions == 0, "Liquidity already exists for this token ID");

        uint256 ownerBalance = nftContract.balanceOf(msg.sender, tokenId);
        require(ownerBalance >= fractions, "Not enough NFT fractions owned by admin");

        // Initialize the liquidity pool
        liquidityPools[tokenId] = LiquidityPool({
            totalFractions: fractions,
            availableFractions: fractions,
            basePrice: basePrice,
            exponent: exponent
        });

        emit LiquidityAdded(tokenId, fractions, basePrice, exponent);
    }

    /**
     * @dev Users buy fractions of a token from the liquidity pool.
     * @param tokenId The ID of the token to purchase fractions of.
     * @param fractions The number of fractions to purchase.
     */
    function buyFractions(uint256 tokenId, uint256 fractions) external nonReentrant {
        LiquidityPool storage pool = liquidityPools[tokenId];

        require(pool.totalFractions > 0, "Liquidity does not exist for this token ID");
        require(fractions > 0, "Fractions must be greater than zero");
        require(fractions <= pool.availableFractions, "Not enough fractions available");

        // Calculate dynamic price
        uint256 dynamicPrice = pool.basePrice * (pool.totalFractions * 1e18 / pool.availableFractions) ** pool.exponent / 1e18;
        uint256 totalCost = fractions * dynamicPrice;

        require(realToken.allowance(msg.sender, address(this)) >= totalCost, "Insufficient token allowance");
        require(realToken.balanceOf(msg.sender) >= totalCost, "Insufficient REAL token balance");

        // Transfer REAL tokens from the buyer to the contract
        realToken.transferFrom(msg.sender, address(this), totalCost);

        // Transfer fractions to the buyer
        nftContract.safeTransferFrom(owner(), msg.sender, tokenId, fractions, "");
        pool.availableFractions -= fractions;

        emit FractionsTraded(tokenId, msg.sender, fractions, totalCost);
    }

    /**
     * @dev Users sell fractions of a token back to the liquidity pool.
     * @param tokenId The ID of the token to sell fractions of.
     * @param fractions The number of fractions to sell.
     */
    function sellFractions(uint256 tokenId, uint256 fractions) external nonReentrant {
        LiquidityPool storage pool = liquidityPools[tokenId];

        require(pool.totalFractions > 0, "Liquidity does not exist for this token ID");
        require(fractions > 0, "Fractions must be greater than zero");
        require(fractions + pool.availableFractions <= pool.totalFractions, "Exceeds pool capacity");

        // Calculate dynamic price
        uint256 dynamicPrice = pool.basePrice * (pool.totalFractions * 1e18 / pool.availableFractions) ** pool.exponent / 1e18;
        uint256 totalEarnings = fractions * dynamicPrice;

        require(realToken.balanceOf(address(this)) >= totalEarnings, "Insufficient REAL token balance in contract");

        // Transfer fractions from the seller to the admin
        nftContract.safeTransferFrom(msg.sender, owner(), tokenId, fractions, "");

        // Transfer REAL tokens from the contract to the seller
        realToken.transfer(msg.sender, totalEarnings);
        pool.availableFractions += fractions;

        emit FractionsSold(tokenId, msg.sender, fractions, totalEarnings);
    }

    /**
     * @dev Admin withdraws REAL tokens earned from sales.
     * @param amount The amount of REAL tokens to withdraw.
     */
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        require(amount <= realToken.balanceOf(address(this)), "Insufficient REAL token balance");
        realToken.transfer(msg.sender, amount);
    }

    /**
     * @dev Get details of a liquidity pool for a specific token ID.
     * @param tokenId The ID of the token.
     * @return totalFractions, availableFractions, basePrice, exponent
     */
    function getLiquidityPool(uint256 tokenId) external view returns (uint256, uint256, uint256, uint256) {
        LiquidityPool memory pool = liquidityPools[tokenId];
        return (pool.totalFractions, pool.availableFractions, pool.basePrice, pool.exponent);
    }

    /**
 * @dev Get the current dynamic price per fraction for a specific token ID.
 * @param tokenId The ID of the token.
 * @return The current price per fraction in REAL tokens.
 */
function getCurrentPrice(uint256 tokenId) external view returns (uint256) {
    LiquidityPool memory pool = liquidityPools[tokenId];
    require(pool.totalFractions > 0, "Liquidity does not exist for this token ID");

    uint256 dynamicPrice = pool.basePrice * (pool.totalFractions * 1e18 / pool.availableFractions) ** pool.exponent / 1e18;
    return dynamicPrice;
}

}
