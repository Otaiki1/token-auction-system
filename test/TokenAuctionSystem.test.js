const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenAuctionSystem", function () {
  let tokenAuctionSystem;
  let token;
  let tokenCA;
  let owner;
  let seller;
  let bidder1;
  let bidder2;
  let nonBidder;

  let tokenId;
  const RESERVE_PRICE = ethers.utils.parseEther("1");
  const LOW_BID_AMOUNT = ethers.utils.parseEther("0.5");
  const HIGH_BID_AMOUNT = ethers.utils.parseEther("1.5");

  before(async function () {
    // Get signers
    [owner, seller, bidder1, bidder2, nonBidder] = await ethers.getSigners();

    // Deploy Token contract
    const Token = await ethers.getContractFactory("KnowledgeToken");
    token = await Token.deploy("KnowldegeToken", "KT", "https://ipfs.io/");

    // Mint token to seller
    tokenId = await token.connect(seller).mintToken();
    tokenId = tokenId.value.toNumber();

    // Deploy TokenAuctionSystem contract
    const TokenAuctionSystem = await ethers.getContractFactory(
      "TokenAuctionSystem"
    );
    tokenAuctionSystem = await TokenAuctionSystem.deploy();

    // Set up TokenAuctionSystem contract for the seller's token
    tokenCA = await ethers.getContractAt("IERC721", token.address);
  });

  it("should not allow non-owner of token to create auctions", async function () {
    await expect(
      tokenAuctionSystem
        .connect(bidder1)
        .createAuction(tokenId, RESERVE_PRICE, tokenCA.address)
    ).to.be.revertedWith("NOT OWNER OF TOKEN");
  });

  it("should create an auction", async function () {
    // Approve TokenAuctionSystem contract to manage seller's token
    await token.connect(seller).approve(tokenAuctionSystem.address, tokenId);

    await tokenAuctionSystem
      .connect(seller)
      .createAuction(tokenId, RESERVE_PRICE, tokenCA.address);

    expect(await tokenCA.ownerOf(tokenId)).to.equal(tokenAuctionSystem.address);

    const auction = await tokenAuctionSystem.auctions(tokenId);
    expect(auction.seller).to.equal(seller.address);
    expect(auction.currentHighestBidder).to.equal(ethers.constants.AddressZero);
    expect(auction.currentHighestBid).to.equal(0);
    expect(auction.reservePrice).to.equal(RESERVE_PRICE);
  });

  it("should not allow bids below the reserve price", async function () {
    await expect(
      tokenAuctionSystem.connect(bidder1).placeBid(tokenId, {
        value: LOW_BID_AMOUNT,
      })
    ).to.be.revertedWith("bid amount must be greater than reservePrice");
  });

  it("should allow bids above the reserve price", async function () {
    await expect(
      tokenAuctionSystem.connect(bidder1).placeBid(tokenId, {
        value: HIGH_BID_AMOUNT,
      })
    )
      .to.emit(tokenAuctionSystem, "BidPlaced")
      .withArgs(bidder1.address, HIGH_BID_AMOUNT, tokenId, tokenCA.address);

    const auction = await tokenAuctionSystem.auctions(tokenId);
    expect(auction.currentHighestBidder).to.equal(bidder1.address);
    expect(auction.currentHighestBid).to.equal(HIGH_BID_AMOUNT);
  });
});
