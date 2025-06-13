import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";

async function main() {
  const [deployer] = await ethers.getSigners();
  const nftAddress = "0xNFT_ADDRESS";
  const greenTokenAddress = "0xGREEN_TOKEN_ADDRESS";
  console.log(`Deploying StakingVault with account: ${deployer.address}`);

  // Deploy the StakingVault contract, passing NFT and GreenToken addresses
  const vault = await deployContract("StakingVault", [nftAddress, greenTokenAddress]);
  console.log(`StakingVault deployed to: ${vault.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});