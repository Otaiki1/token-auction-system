// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenAuctionSystem is ReentrancyGuard{

    //store token schema
    struct Auction{
        address seller;

        address currentHighestBidder;
        uint256 currentHighestBid;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
 
    }

    struct Bid{
        address bidderAddress;
        uint256 bidAmount;
    }

    struct Token{
        uint256 tokenId;
        address tokenOwner;
        IERC721 tokenCA;
    }

    
    //mapping of token id to tokens
    mapping(uint => Token) tokens;
    //tokenId to Auction structs
    mapping(uint  => Auction) auctions;
    //tokenId to bids
    mapping(uint => Bid) bids;

  
    
    function createAuction(uint _tokenId, uint _reservePrice, IERC721 _tokenCA) external{
        require(_tokenCA.ownerOf(_tokenId) == msg.sender, "NOT OWNER OF TOKEN");
        require(_reservePrice != 0, "PRICE CANT BE ZERO");

        //update Mappings
        tokens[_tokenId] = Token(_tokenId, msg.sender, _tokenCA);
        auctions[_tokenId] = Auction(msg.sender, address(0), 0, _reservePrice, 0, 0);

        //transfer token to contract
        _tokenCA.transferFrom(msg.sender, address(this), _tokenId);


    }
 
    function placeBid(uint256 _tokenId) external payable returns(bool isPlaced){
        //check to ensure the token is auctioned
        Auction memory auctionToken = auctions[_tokenId];
        require(auctionToken.seller != address(0), "Token not auctioned");
        require(msg.value > auctionToken.reservePrice, "bid amount must be greater than reservePrice");
        //check  if this is first bid 
        if(auctionToken.currentHighestBidder == address(0)){
            auctionToken.startTime  = block.timestamp;
            auctionToken.endTime = block.timestamp +15 minutes;
        }

        if(msg.value <= auctionToken.currentHighestBid){
           (bool success, ) =  payable(msg.sender).call{value: msg.value}("");
           if(success){
            return false;
           }else{
            revert("return payment failed");
           }
        }else{
            auctionToken.currentHighestBid = msg.value;
            auctionToken.currentHighestBidder = msg.sender;
            //update bids mapping
            bids[_tokenId] = Bid(msg.sender, msg.value);
            //return true on successful bid
            return true;
        }


    }

 
    function closeAuction(uint256 _tokenId) external {
        //check to ensure the token end time has reached
        Auction memory auctionToken = auctions[_tokenId];
        require(block.timestamp > auctionToken.endTime, "Auction time hasnt elapsed");
        require(msg.sender == auctionToken.seller || msg.sender == auctionToken.currentHighestBidder, "only seller or highest bidder can call ");

        address winner = auctionToken.currentHighestBidder;
        address owner= auctionToken.seller;
        uint256 soldPrice = auctionToken.currentHighestBid;
        //update all mapping
        auctionToken = Auction(address(0), address(0), 0, 0, 0 ,0);
        bids[_tokenId] = Bid(address(0), 0);
        //transfer token
        Token memory token  = tokens[_tokenId];
        token.tokenOwner = winner;
        token.tokenCA.transferFrom(address(this), winner, _tokenId);
        //pay auctioner
        (bool success, ) = payable(owner).call{value: soldPrice}("");
        if(!success){
            revert("pay auctioneer failed");
        }
    }
    

    function getTokenOwner(uint256 _tokenId) external view returns(address){
        return tokens[_tokenId].tokenOwner;
    }
    

}                                      