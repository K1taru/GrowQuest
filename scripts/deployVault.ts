import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";

async function main() {
  const [deployer] = await ethers.getSigners();
  
  // TODO: Set this to the deployed GreenToken address
  const greenTokenAddress = "0xYOUR_GREEN_TOKEN_ADDRESS";
  console.log(`Deploying StakingVault with account: ${deployer.address}`);
  
  // Deploy the StakingVault contract, passing the GreenToken address
  const vault = await deployContract("StakingVault", [greenTokenAddress]);
  console.log(`StakingVault deployed to: ${vault.address}`);
  
  // Grant the vault contract the MINTER_ROLE on GreenToken (for minting rewards)
  const token = await ethers.getContractAt("GreenToken", greenTokenAddress);
  const MINTER_ROLE = await token.MINTER_ROLE();
  await token.grantRole(MINTER_ROLE, vault.address);
  console.log(`Granted MINTER_ROLE on GreenToken to StakingVault`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
