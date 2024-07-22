// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BondingCurve {
    // Parameters of the bonding curve
    uint256 constant k = 1000; // Curve parameter (constant reserve ratio)
    uint256 constant initialSupply = 1000; // Initial token supply
    uint256 constant initialReserve = 1000 ether; // Initial reserve in wei (ETH)

    // State variables
    uint256 public totalSupply;
    uint256 public reserveBalance;

    // Events
    event TokenMinted(address indexed buyer, uint256 tokensMinted, uint256 reserveInvested);
    event TokenBurned(address indexed seller, uint256 tokensBurned, uint256 reserveReleased);

    // Constructor
    constructor() 
    {
        totalSupply = initialSupply;
        reserveBalance = initialReserve;
    }

    // Bonding curve function: Calculate price to mint `amount` tokens
    function calculateMintPrice(uint256 amount) public view returns (uint256) 
    {
        return calculatePurchaseReturn(totalSupply, reserveBalance, k, amount);
    }

    // Bonding curve function: Calculate price to burn `amount` tokens
    function calculateBurnReward(uint256 amount) public view returns (uint256) 
    {
        return calculateSaleReturn(totalSupply, reserveBalance, k, amount);
    }

    // Mint tokens by providing ETH to the curve
    function mint(uint256 amount) external payable 
    {
        require(amount > 0, "Must mint at least some tokens");
        uint256 price = calculateMintPrice(amount);
        require(msg.value >= price, "Insufficient ETH provided");

        totalSupply += amount;
        reserveBalance += price;

        emit TokenMinted(msg.sender, amount, price);
    }

    // Burn tokens to withdraw ETH from the curve
    function burn(uint256 amount) external 
    {
        require(amount > 0 && amount <= totalSupply, "Invalid amount to burn");

        uint256 reward = calculateBurnReward(amount);

        totalSupply -= amount;
        reserveBalance -= reward;

        // Transfer ETH to the caller
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Transfer failed");

        emit TokenBurned(msg.sender, amount, reward);
    }

    // Internal function: Calculate price to mint `amount` tokens
    function calculatePurchaseReturn(uint256 supply, uint256 balance, uint256 ratio, uint256 amount) internal pure returns (uint256) 
    {
        return balance * (1 - (1 - amount / (supply + 1)) ** ratio) / ratio;
    }

    // Internal function: Calculate price to burn `amount` tokens
    function calculateSaleReturn(uint256 supply, uint256 balance, uint256 ratio, uint256 amount) internal pure returns (uint256) 
    {
        return balance * (1 - (supply / (supply - amount + 1)) ** ratio) / ratio;
    }

    // Fallback function to receive ETH
    receive() external payable {}
}
