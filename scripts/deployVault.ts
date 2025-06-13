import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";
import * as dotenv from "dotenv";
dotenv.config();

async function main() {
  const [deployer] = await ethers.getSigners();
  const nftAddress = process.env.NFT_ADDRESS as string;
  const greenTokenAddress = process.env.GREEN_TOKEN_ADDRESS as string;
  console.log(`Deploying StakingVault with account: ${deployer.address}`);

  const vault = await deployContract("StakingVault", [nftAddress, greenTokenAddress]);
  console.log(`StakingVault deployed to: ${vault.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});