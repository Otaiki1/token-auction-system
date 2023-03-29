// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenAuctionSystem is ReentrancyGuard{

    enum BidStates{
        Inactive,
        Active,
        Ended
    }
    //store token schema
    struct Token{
        address owner;
        mapping(address => uint256) bidders;
        address[] allBidders;
        address currentHighestBidder;
        uint256 reservePrice;
        uint256 startTime;
        BidStates bidState;
        IERC721 token;
        uint256 tokenId;
    }

    mapping(uint256 => Token) idToToken;
    mapping(address => uint256[]) balances;

    uint256 public ID;
    //add a token to the token auction system
    // list token
        //set reserve price
        //update bid, allows users update their bids
    function auctionToken(IERC721 _token, uint256 _reservePrice, uint _tokenId) external nonReentrant{
        require(_reservePrice > 0, "Reserve price must be greater than 0");
        require(_token.ownerOf(_tokenId) == msg.sender, "NOT OWNER OF TOKEN");

        ID++;

        _token.transferFrom(msg.sender, address(this), _tokenId);

        idToToken[ID].owner = msg.sender;
        idToToken[ID].reservePrice = _reservePrice;
        idToToken[ID].token = _token;
        idToToken[ID].tokenId = _tokenId;
         
        balances[msg.sender].push(ID);
    }
    
    //allow sellers make bid
        //upon first bid , start counting of 15 minutes 
        //ignore prices below reserve price
        //emit each bidding
    function makeBid(uint256 _tokenId) external payable{
        require(_tokenId > 0 && _tokenId <= ID, "Invalid ID");
        Token storage biddedToken  = idToToken[_tokenId];

        require(biddedToken.bidState ==BidStates.Active, "BID CLOSED");
    
        //checking for first time bidding
        if(biddedToken.currentHighestBidder == address(0)){
            biddedToken.startTime = block.timestamp;
            biddedToken.currentHighestBidder = msg.sender;
            biddedToken.bidState = BidStates.Active;
        }

        require (block.timestamp < (biddedToken.startTime + 15 minutes), "BIDDING TIME HAS PASSED");

        biddedToken.bidders[msg.sender] += msg.value;

        //update the current highest bidder if msg.value is higher than previous current highest bidder
        if((biddedToken.bidders[msg.sender]) > (biddedToken.bidders[biddedToken.currentHighestBidder])){
            biddedToken.currentHighestBidder = msg.sender;
        }

        biddedToken.allBidders.push(msg.sender);
        //emit events  at this point
    }

    //Token is sold to highest bidder and rest of money is reverted to the bidders
    function settleAuction(uint256 _tokenId) external{
        require(_tokenId > 0 && _tokenId <= ID, "Invalid ID");
        Token storage biddedToken  = idToToken[_tokenId];

        require(biddedToken.startTime != 0, "auction not ready");
        require(block.timestamp > (biddedToken.startTime + 15 minutes) , "TIME NOT ELAPSED");
        require(biddedToken.currentHighestBidder == msg.sender, "NOT WINNER OF THE AUCTION");

        address winner = biddedToken.currentHighestBidder;

        //update storage mapping
        uint index = findIndex(_tokenId, balances[biddedToken.owner]);
        delete balances[biddedToken.owner][index];//works on premise that its impossible for an auction id to be 0
        balances[msg.sender].push(_tokenId);

        for(uint i = 0;i <biddedToken.allBidders.length; i++){
            address current = payable(biddedToken.allBidders[i]);
            uint payAmount = biddedToken.bidders[current];

            (bool success, ) = current.call{value: payAmount}("");
            if(!success){
                revert("payment failed");
            }
        }
        
        IERC721 tokenStandard = biddedToken.token;
        tokenStandard.transferFrom(address(this), winner, biddedToken.tokenId);
        
        

        //reset it
        delete idToToken[_tokenId];

    

        //emit event
    }

    
    function getBalance(address _addr) external view returns(uint[] memory){
        return balances[_addr];
    }
    function getAuctionBidders(uint256 _tokenId) external view returns(address[] memory){
        return idToToken[_tokenId].allBidders;
    }
    
    function getBidderAmount(uint256 _tokenId, address _addr) external view returns(uint256){
        return idToToken[_tokenId].bidders[_addr];
    }
    function getHighestBidder(uint256 _tokenId) external view returns(address){
        return idToToken[_tokenId].currentHighestBidder;
    }
    function getReservePrice(uint256 _tokenId) external view returns(uint256){
        return idToToken[_tokenId].reservePrice;
    }
    function getBidState(uint256 _tokenId) external view returns(BidStates){
        return idToToken[_tokenId].bidState;
    }
    function getTokenInfo(uint256 _tokenId) external view returns(IERC721, uint256){
        return (idToToken[_tokenId].token, idToToken[_tokenId].tokenId);
    }

    //A function that finds the index of a particular unique number
    function findIndex(uint _num, uint[] memory arr) public pure returns(uint){
        uint i;
        for(i=0;i<arr.length;i++){
            if(arr[i] == _num){
                return i;
            }
        }
        return i+1;
    }
    

}                                      