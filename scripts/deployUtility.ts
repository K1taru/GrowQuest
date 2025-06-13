import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";

async function main() {
  const [deployer] = await ethers.getSigners();
  const nftAddress = "0xNFT_ADDRESS";
  const tokenAddress = "0xGREEN_TOKEN_ADDRESS";
  console.log(`Deploying GrowthUtility with account: ${deployer.address}`);

  // Deploy the GrowthUtility contract, passing token and NFT addresses
  const utility = await deployContract("GrowthUtility", [tokenAddress, nftAddress]);
  console.log(`GrowthUtility deployed to: ${utility.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});