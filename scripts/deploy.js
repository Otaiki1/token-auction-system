// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const KnowledgeToken = await hre.ethers.getContractFactory("KnowledgeToken");
  const knowledgeToken = await KnowledgeToken.deploy(
    "KnowldegeToken",
    "KT",
    "https://ipfs.io/"
  );

  await knowledgeToken.deployed();

  const TokenAuctionSystem = await hre.ethers.getContractFactory(
    "TokenAuctionSystem"
  );
  const tokenAuctionSystem = await TokenAuctionSystem.deploy();

  await tokenAuctionSystem.deployed();

  console.log(
    `Knowledge Token deployed with ${knowledgeToken.address}`
  );

  console.log(
    `Token Auction System deployed with ${tokenAuctionSystem.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
