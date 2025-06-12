import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";

async function main() {
  const [deployer] = await ethers.getSigners();
  
  // TODO: Set these to the deployed GrowQuestNFT and GreenToken addresses
  const nftAddress = "0xYOUR_NFT_ADDRESS";
  const tokenAddress = "0xYOUR_GREEN_TOKEN_ADDRESS";
  console.log(`Deploying GrowthUtility with account: ${deployer.address}`);
  
  // Deploy the GrowthUtility contract, passing NFT and token addresses
  const utility = await deployContract("GrowthUtility", [tokenAddress, nftAddress]);
  console.log(`GrowthUtility deployed to: ${utility.address}`);
  
  // Grant GrowthUtility the MINTER_ROLE on GreenToken (so it can mint rewards)
  const token = await ethers.getContractAt("GreenToken", tokenAddress);
  const MINTER_ROLE = await token.MINTER_ROLE();
  await token.grantRole(MINTER_ROLE, utility.address);
  console.log(`Granted MINTER_ROLE on GreenToken to GrowthUtility`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
