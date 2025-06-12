import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying GreenToken with account: ${deployer.address}`);
  
  // Deploy the GreenToken contract
  const token = await deployContract("GreenToken");
  
  // Grant roles to deployer (MINTER_ROLE and BURNER_ROLE)
  const MINTER_ROLE = await token.MINTER_ROLE();
  const BURNER_ROLE = await token.BURNER_ROLE();
  await token.grantRole(MINTER_ROLE, deployer.address);
  await token.grantRole(BURNER_ROLE, deployer.address);

  console.log(`GreenToken deployed to: ${token.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
