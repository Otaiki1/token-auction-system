# Token Auction System (TAS)

## Introduction

This smart contract is designed to enables users ("sellers" and "bidders") to exchange tokens via an English auction for which the following features are required:

## Data Structures

    Auction: a struct that stores information about an auction, including the seller's address, the reserve price, the current highest bid, the address of the highest bidder, and the end time of the auction.

    Bid: a struct that stores information about a bid, including the bidder's address and the amount of the bid.
    Token: a struct that stores information about a token, including the token ID and the owner's address.

## State Variables

    tokens: a mapping of token IDs to Token structs.

    auctions: a mapping of token IDs to Auction structs.

    bids: a mapping of token IDs to Bid structs.

## Modifiers

    onlySeller: a modifier that restricts access to a function to the seller of the corresponding auction.

    onlyBidder: a modifier that restricts access to a function to a bidder who has placed a bid on the corresponding auction.

## Functions

    createAuction(tokenId, reservePrice): allows a seller to create a new auction for a token with the specified ID and reserve price.
    placeBid(tokenId): allows a bidder to place a bid on an auction for a token with the specified ID. The bid must be at least equal to the reserve price set by the seller. If the bid is the first bid on the auction, the auction end time is set to 15 minutes from the time the bid was placed.

    closeAuction(tokenId): closes an auction and transfers the token to the highest bidder, if bids were placed and the reserve price was met. Only the seller or highest bidder can call this function.

    getTokenOwner(tokenId): returns the current owner of the specified token.


## Usage

To use this contract, follow these steps:

1. npm i
2. npx hardhat deploy
3. npx hardhat test



## Security

This contract has been designed with security in mind, but it is important to note that no contract is completely secure. Users should exercise caution when interacting with this contract and be aware of potential risks.

## License

This project is licensed under the MIT License.]

