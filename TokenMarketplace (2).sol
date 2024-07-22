// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Token.sol";
import "./TokenFactory.sol";

contract TokenMarketplace {
    struct Listing {
        address tokenAddress;
        address seller;
        uint256 amount;
        uint256 pricePerToken;
    }

    Listing[] public listings;
    address payable public factoryContract;

    event TokenListed(
        address tokenAddress,
        address seller,
        uint256 amount,
        uint256 pricePerToken
    );
    event TokenPurchased(
        address tokenAddress,
        address buyer,
        uint256 amount,
        uint256 pricePerToken
    );
    event TokenListingUpdated(
        address tokenAddress,
        uint256 amount,
        uint256 pricePerToken
    );

    constructor(address payable _factoryAddress) {
        factoryContract = _factoryAddress;
    }

    function relistToken(
        address _tokenAddress,
        uint256 _amount,
        uint256 _pricePerToken
    ) public {
        require(TokenFactory(factoryContract).totalTokens() > 0, "No tokens created yet");
        require(
            TokenFactory(factoryContract).marketplaceAddress() == address(this),
            "Marketplace address not set in factory"
        );

        // Check that the factory contract has enough tokens
        ERC20Token token = ERC20Token(_tokenAddress);
        require(token.balanceOf(factoryContract) >= _amount, "Insufficient token balance");

        // Transfer the tokens from the factory contract to the marketplace
        require(token.transferFrom(factoryContract, address(this), _amount), "Token transfer to marketplace failed");

        // Check if the token is already listed
        (uint256 existingIndex, bool isListed) = findListingIndex(_tokenAddress);
        
        if (isListed) {
            // Update the existing listing by adding the new amount
            Listing storage existingListing = listings[existingIndex];
            existingListing.amount += _amount;
            existingListing.pricePerToken = _pricePerToken;

            emit TokenListingUpdated(_tokenAddress, existingListing.amount, existingListing.pricePerToken);
        } else {
            // Create a new listing
            listings.push(
                Listing({
                    tokenAddress: _tokenAddress,
                    seller: msg.sender,
                    amount: _amount,
                    pricePerToken: _pricePerToken
                })
            );

            emit TokenListed(_tokenAddress, msg.sender, _amount, _pricePerToken);
        }
    }

    function purchaseToken(uint256 index, uint256 _amount) public payable {
        require(index < listings.length, "Listing does not exist");
        Listing storage listing = listings[index];

        require(listing.amount >= _amount, "Not enough tokens in listing");

        uint256 totalPrice = _amount * listing.pricePerToken;
        require(msg.value >= totalPrice, "Insufficient Ether sent");

        uint256 excessAmount = msg.value - totalPrice;

        // Decrease the amount of tokens in the listing
        listing.amount -= _amount;

        ERC20Token token = ERC20Token(listing.tokenAddress);

        // Transfer the tokens to the buyer
        require(token.transfer(msg.sender, _amount), "Token transfer failed");

        // Transfer the total price to the seller
        (bool sentToSeller, ) = payable(listing.seller).call{value: totalPrice}("");
        require(sentToSeller, "Failed to transfer Ether to seller");

        // Refund the excess amount to the buyer if any
        if (excessAmount > 0) {
            (bool refunded, ) = payable(msg.sender).call{value: excessAmount}("");
            require(refunded, "Failed to refund excess Ether");
        }

        // Remove the listing if the amount is zero
        if (listing.amount == 0) {
            removeListing(index);
        }

        emit TokenPurchased(
            listing.tokenAddress,
            msg.sender,
            _amount,
            listing.pricePerToken
        );
    }

    function removeListing(uint256 index) internal {
        require(index < listings.length, "Listing does not exist");

        listings[index] = listings[listings.length - 1];
        listings.pop();
    }

    function totalListings() public view returns (uint256) {
        return listings.length;
    }

    function getListing(uint256 index)
        public
        view
        returns (
            address,
            address,
            uint256,
            uint256
        )
    {
        require(index < listings.length, "Listing does not exist");
        Listing storage listing = listings[index];
        return (
            listing.tokenAddress,
            listing.seller,
            listing.amount,
            listing.pricePerToken
        );
    }

    function checkAllowance(address _tokenAddress, address _owner)
        public
        view
        returns (uint256)
    {
        ERC20Token token = ERC20Token(_tokenAddress);
        return token.allowance(_owner, address(this));
    }

    function tokenBalance(address _tokenAddress, address _owner)
        public
        view
        returns (uint256)
    {
        ERC20Token token = ERC20Token(_tokenAddress);
        return token.balanceOf(_owner);
    }

    // Function to find the index of an existing listing
    function findListingIndex(address _tokenAddress) internal view returns (uint256, bool) {
        for (uint256 i = 0; i < listings.length; i++) {
            if (listings[i].tokenAddress == _tokenAddress) {
                return (i, true);
            }
        }
        return (0, false);
    }
}
