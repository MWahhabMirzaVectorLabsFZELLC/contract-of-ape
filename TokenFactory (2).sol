// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Token.sol";
import "./TokenMarketplace.sol";

contract TokenFactory {
    struct TokenInfo {
        string name;
        string symbol;
        address tokenAddress;
        address owner;
    }

    TokenInfo[] public tokens;
    address public marketplaceAddress;
    address public owner;

    event TokenCreated(string name, string symbol, address tokenAddress);
    event TokenListedOnMarketplace(
        address tokenAddress,
        address seller,
        uint256 amount,
        uint256 pricePerToken
    );
  event RemainingTokensTransferred(
        address tokenAddress,
        address owner,
        uint256 amount
    );
    event TokenUpdatedOnMarketplace(
    address tokenAddress,
    address owner,
    uint256 amount,
    uint256 pricePerToken
);
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setMarketplaceAddress(address _marketplaceAddress)
        public
        onlyOwner
    {
        marketplaceAddress = _marketplaceAddress;
    }

    function createToken(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _listingAmount,
        uint256 _pricePerToken
    ) public {
        require(
            _initialSupply >= _listingAmount,
            "Initial supply must be greater than or equal to the listing amount"
        );

        // Create new ERC20 token
        ERC20Token newToken = new ERC20Token(
            _name,
            _symbol,
            _initialSupply,
            address(this)
        );

        tokens.push(
            TokenInfo({
                name: _name,
                symbol: _symbol,
                tokenAddress: address(newToken),
                owner: address(this) // Set the owner of the token as the creator
            })
        );

        emit TokenCreated(_name, _symbol, address(newToken));

        // Approve the marketplace for the entire initial supply
        if (marketplaceAddress != address(0) && _initialSupply > 0) {
            newToken.approve(marketplaceAddress, _initialSupply);

            TokenMarketplace marketplace = TokenMarketplace(marketplaceAddress);
            marketplace.relistToken(
                address(newToken),
                _listingAmount,
                _pricePerToken
            );

            emit TokenListedOnMarketplace(
                address(newToken),
                address(this), // Set the seller to the creator of the token
                _listingAmount,
                _pricePerToken
            );
        }

        // Transfer the remaining tokens to the creator
        uint256 remainingAmount = _initialSupply - _listingAmount;
        if (remainingAmount > 0) {
            newToken.transfer(address(this), remainingAmount);
            emit RemainingTokensTransferred(address(newToken), address(this), remainingAmount);
        }
    }

    function listExistingToken(
    address _tokenAddress,
    uint256 _amount,
    uint256 _pricePerToken
) public {
    require(
        marketplaceAddress != address(0),
        "Marketplace address is not set"
    );

    ERC20Token token = ERC20Token(_tokenAddress);

    // Check if the factory contract (address(this)) has sufficient token balance
    require(
        token.balanceOf(address(this)) >= _amount,
        "Insufficient token balance in the contract"
    );
    require(
        token.allowance(address(this), marketplaceAddress) >= _amount,
        "Marketplace not approved to spend tokens"
    );

    TokenMarketplace marketplace = TokenMarketplace(marketplaceAddress);

    // Relist the token, which will handle both creating and updating the listing
    marketplace.relistToken(_tokenAddress, _amount, _pricePerToken);
}





    function getToken(uint256 index)
        public
        view
        returns (
            string memory,
            string memory,
            address,
            address
        )
    {
        require(index < tokens.length, "Token does not exist");
        TokenInfo storage token = tokens[index];
        return (token.name, token.symbol, token.tokenAddress, token.owner);
    }

    function totalTokens() public view returns (uint256) {
        return tokens.length;
    }

    // Add receive function to accept Ether payments
    receive() external payable {}
}
