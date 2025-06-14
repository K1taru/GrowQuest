import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";
import * as dotenv from "dotenv";
dotenv.config();

async function main() {
  const [deployer] = await ethers.getSigners();
  const nftAddress = process.env.NFT_ADDRESS as string;
  const tokenAddress = process.env.GREEN_TOKEN_ADDRESS as string;
  console.log(`Deploying GrowthUtility with account: ${deployer.address}`);

  const utility = await deployContract("GrowthUtility", [tokenAddress, nftAddress]);
  const utilityAddress = await utility.getAddress();
  console.log(`GrowthUtility deployed to: ${utilityAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});