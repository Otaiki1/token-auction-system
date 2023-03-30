# Token Auction System

Token Auction System is a smart contract on the Ethereum blockchain that allows users to create auctions for their ERC721 tokens and receive bids from other users.

## Features

- Users can create auctions for their ERC721 tokens.
- Bidders can place bids on auctions.
- The auction closes after !5 mins when the first bid is made, and the highest bidder wins the token.
- The seller receives the winning bid amount, and the token is transferred to the winning bidder.

## Requirements

- Solidity 0.8.18
- OpenZeppelin 4.3.2

## Usage

### createAuction

To create an auction, call the `createAuction` function, passing in the `tokenId` of the ERC721 token to be auctioned, the `reservePrice` of the auction, and the `IERC721` contract address of the token. The function transfers the token to the contract, so the user must be the owner of the token.

### placeBid

To place a bid on an auction, call the `placeBid` function, passing in the `tokenId` of the auction and the bid amount in ETH. The bid must be greater than the reserve price and the current highest bid, if any. If the bid is successful, the function returns `true`. If the bid fails, the function returns `false`, and the user's ETH is refunded.

### closeAuction

To close an auction, call the `closeAuction` function, passing in the `tokenId` of the auction. The function transfers the token to the winning bidder and sends the winning bid amount to the seller.

### getTokenOwner

To get the owner of an ERC721 token, call the `getTokenOwner` function, passing in the `tokenId` of the token. The function returns the address of the token owner.

## License

This project is licensed under the MIT License.
