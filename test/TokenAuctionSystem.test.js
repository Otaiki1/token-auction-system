const { expect } = require("chai");
const { ethers, network } = require("hardhat");

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
  const HIGHER_BID_AMOUNT = ethers.utils.parseEther("2.0");
  const getCurrentTime = () => Math.round(Date.now() / 1000);

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

  it("should not allow create auctions with reserve price of 0", async function () {
    await expect(
      tokenAuctionSystem
        .connect(seller)
        .createAuction(tokenId, 0, tokenCA.address)
    ).to.be.revertedWith("PRICE CANT BE ZERO");
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
  it("should not allow bids for unauctioned tokens", async function () {
    await expect(
      tokenAuctionSystem.connect(bidder1).placeBid(2, {
        value: HIGH_BID_AMOUNT,
      })
    ).to.be.revertedWith("Token not auctioned");
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

  // it("should refund bids lower than current highest bid", async function () {
  //   await tokenAuctionSystem.connect(bidder1).placeBid(tokenId, {
  //     value: HIGH_BID_AMOUNT,
  //   });
  //   const bidder2BalanceBeforeBid = await ethers.provider.getBalance(
  //     bidder2.address
  //   );
  //   console.log("bidder2 balance before bid---", bidder2BalanceBeforeBid);
  //   let bidTx = await tokenAuctionSystem.connect(bidder2).placeBid(tokenId, {
  //     value: HIGH_BID_AMOUNT,
  //   });
  //   console.log(bidTx);
  //   const bidder2BalanceAFterBid = await ethers.provider.getBalance(
  //     bidder2.address
  //   );
  //   expect(bidder2BalanceAFterBid).to.be.gt(
  //     bidder2BalanceBeforeBid - HIGH_BID_AMOUNT
  //   );
  // });
  it("should allow only displaced bidder to withdraw funds", async function () {
    await tokenAuctionSystem.connect(bidder1).placeBid(tokenId, {
      value: HIGH_BID_AMOUNT,
    });

    await tokenAuctionSystem.connect(bidder2).placeBid(tokenId, {
      value: HIGHER_BID_AMOUNT,
    });

    await expect(
      tokenAuctionSystem.connect(bidder2).withdrawBid()
    ).to.be.revertedWith("NOT DISPLACED BIDDER");
    console.log("withdrawing funds to bidder 1");
    await tokenAuctionSystem.connect(bidder1).withdrawBid();
    console.log("withdrawn funds");
  });

  it("should transfer token to highest bidder when 15 minutes has elapsed", async function () {
    const ownerBalanceBeforeFulfill = await ethers.provider.getBalance(
      seller.address
    );
    await tokenAuctionSystem.connect(bidder1).placeBid(tokenId, {
      value: HIGH_BID_AMOUNT,
    });

    await tokenAuctionSystem.connect(bidder2).placeBid(tokenId, {
      value: HIGHER_BID_AMOUNT,
    });

    //move time
    await network.provider.send("evm_increaseTime", [
      getCurrentTime() + 15 * 60 * 1000,
    ]);
    await network.provider.request({ method: "evm_mine", params: [] });

    //call closeAuction function
    await tokenAuctionSystem.connect(seller).closeAuction(tokenId);

    const ownerBalanceAfterFulfill = await ethers.provider.getBalance(
      seller.address
    );
    //check to ensure bidder 2 is new owner of token
    expect(await tokenCA.ownerOf(tokenId)).to.equal(bidder2.address);
    //ensure auctioner balance is updated
    expect(ownerBalanceAfterFulfill).to.be.gt(ownerBalanceBeforeFulfill);
  });
});
