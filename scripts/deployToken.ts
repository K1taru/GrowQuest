import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";

async function main() {
  const [deployer] = await ethers.getSigners();
  // Use zero address as placeholder
  const placeholder = "0x0000000000000000000000000000000000000000";
  console.log(`Deploying GreenToken with account: ${deployer.address}`);

  // Deploy the GreenToken contract with placeholder addresses
  const token = await deployContract("GreenToken", [placeholder, placeholder]);
  const tokenAddress = await token.getAddress();
  console.log(`GreenToken deployed to: ${tokenAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});