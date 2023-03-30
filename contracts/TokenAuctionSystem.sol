// SPDX-License-Identifier: MIT

// Declare the version of Solidity being used
pragma solidity 0.8.18;

// Import the ERC721 interface from OpenZeppelin library
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// Import ReentrancyGuard contract from OpenZeppelin for security
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Define the main contract
contract TokenAuctionSystem is ReentrancyGuard {
    /* ========== EVENTS ========== */
    //event to be emitted whenever auction is created
    event AuctionCreated(
        address tokenCA, //the contract address of the token
        uint256 tokenId, //the id of the token
        address seller, //address of the seller
        uint256 reservePrice //reserve price set by seller
    );
    //event whenever a bid is placed
    event BidPlaced(
        address bidderAddress, //address of the person making a bid
        uint256 bidderAmount, //amount the person is bidding
        uint256 tokenId, //the id of the token
        address tokenCA //the contract address of the token
    );
    //event whenever an auction is closed
    event AuctionClosed(
        address tokenCA, //the contract address of the token
        uint256 tokenId, //id of thetoken
        uint256 amountPaid,
        address previousOwner,
        address newOwner
    );

    // Struct to hold auction details for a given token
    struct Auction {
        address seller; // Address of the seller
        address currentHighestBidder; // Address of the current highest bidder
        uint256 currentHighestBid; // The current highest bid for the token
        uint256 reservePrice; // The reserve price set for the token
        uint256 startTime; // The time when the auction started
        uint256 endTime; // The time when the auction will end
    }

    // Struct to hold a bid for a given token
    struct Bid {
        address bidderAddress; // Address of the bidder
        uint256 bidAmount; // The amount of the bid
    }

    // Struct to hold the details of a given token
    struct Token {
        uint256 tokenId; // ID of the token
        address tokenOwner; // Address of the owner of the token
        IERC721 tokenCA; // Interface for the token contract
    }

    // Mapping to associate each token ID with its respective Token struct
    mapping(uint => Token) tokens;
    // Mapping to associate each token ID with its respective Auction struct
    mapping(uint => Auction) auctions;
    // Mapping to associate each token ID with its respective Bid struct
    mapping(uint => Bid) bids;

    // Modifier to restrict access to only the seller or the current highest bidder
    modifier onlySellerOrWinner(uint _tokenId) {
        require(
            msg.sender == auctions[_tokenId].seller ||
                msg.sender == auctions[_tokenId].currentHighestBidder,
            "NOT ALLOWED"
        );
        _;
    }

    // Function to create an auction for a token
    function createAuction(
        uint _tokenId,
        uint _reservePrice,
        IERC721 _tokenCA
    ) external nonReentrant {
        // Check that the caller is the owner of the token
        require(_tokenCA.ownerOf(_tokenId) == msg.sender, "NOT OWNER OF TOKEN");
        // Check that the reserve price is not zero
        require(_reservePrice != 0, "PRICE CANT BE ZERO");

        // Create a new Token struct and add it to the tokens mapping
        tokens[_tokenId] = Token(_tokenId, msg.sender, _tokenCA);
        // Create a new Auction struct and add it to the auctions mapping
        auctions[_tokenId] = Auction(
            msg.sender,
            address(0),
            0,
            _reservePrice,
            0,
            0
        );

        // Transfer the token to the contract
        _tokenCA.transferFrom(msg.sender, address(this), _tokenId);

        //emit event when auction is created
        emit AuctionCreated(
            address(_tokenCA),
            _tokenId,
            msg.sender,
            _reservePrice
        );
    }

    // Function to place a bid on a token
    function placeBid(
        uint256 _tokenId
    ) external payable nonReentrant returns (bool isPlaced) {
        // Check that the token is being auctioned
        Auction memory auctionToken = auctions[_tokenId];
        require(auctionToken.seller != address(0), "Token not auctioned");
        // Check that the bid amount is higher than the reserve price
        require(
            msg.value > auctionToken.reservePrice,
            "bid amount must be greater than reservePrice"
        );

        // If this is the first bid, set the start and end
        if (auctionToken.currentHighestBidder == address(0)) {
            auctionToken.startTime = block.timestamp;
            auctionToken.endTime = block.timestamp + 15 minutes;
        }

        //if the bid amount is not higher than the current highest bid, refund the sender
        if (msg.value <= auctionToken.currentHighestBid) {
            (bool success, ) = payable(msg.sender).call{value: msg.value}("");
            if (success) {
                return false;
            } else {
                revert("return payment failed");
            }
        } else {
            //if the bid amount is higher than the current highest bid, update the mappings
            auctionToken.currentHighestBid = msg.value;
            auctionToken.currentHighestBidder = msg.sender;
            bids[_tokenId] = Bid(msg.sender, msg.value);
            //emit the Bid created event
            emit BidPlaced(
                msg.sender,
                msg.value,
                _tokenId,
                address(tokens[_tokenId].tokenCA)
            );
            //return true on successful bid
            return true;
        }
    }

    /**
     * @dev Closes an ongoing auction for the specified token ID and transfers ownership to the highest bidder.
     *      The auction can only be closed by the seller or the current highest bidder.
     *      The auction can only be closed after its end time has elapsed.
     *      The auctioned token is transferred to the highest bidder and the seller receives the sold price.
     * @param _tokenId uint256 ID of the token being auctioned.
     */
    function closeAuction(
        uint256 _tokenId
    ) external nonReentrant onlySellerOrWinner(_tokenId) {
        //check to ensure the token end time has reached
        Auction memory auctionToken = auctions[_tokenId];
        require(
            block.timestamp > auctionToken.endTime,
            "Auction time hasnt elapsed"
        );

        //get the winner and owner of the token
        address winner = auctionToken.currentHighestBidder;
        address owner = auctionToken.seller;
        uint256 soldPrice = auctionToken.currentHighestBid;

        //update all mapping
        auctionToken = Auction(address(0), address(0), 0, 0, 0, 0);
        bids[_tokenId] = Bid(address(0), 0);

        //transfer token to winner
        Token memory token = tokens[_tokenId];
        token.tokenOwner = winner;
        token.tokenCA.transferFrom(address(this), winner, _tokenId);

        //pay auctioner
        (bool success, ) = payable(owner).call{value: soldPrice}("");
        if (!success) {
            revert("pay auctioneer failed");
        }

        //emit event
        emit AuctionClosed(
            address(token.tokenCA),
            _tokenId,
            soldPrice,
            owner,
            winner
        );
    }

    /**
     * @dev Returns the current owner of the specified token.
     * @param _tokenId uint256 ID of the token.
     * @return address of the token owner.
     */
    function getTokenOwner(uint256 _tokenId) external view returns (address) {
        return tokens[_tokenId].tokenOwner;
    }
}
