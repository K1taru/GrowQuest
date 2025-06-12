import { ethers } from "hardhat";
import { deployContract } from "./utils/deployHelpers";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying GrowQuestNFT with account: ${deployer.address}`);
  
  // Deploy the GrowQuestNFT contract
  const nft = await deployContract("GrowQuestNFT");
  
  // Grant roles to deployer (assumes MINTER_ROLE and XP_ROLE are defined in contract)
  const MINTER_ROLE = await nft.MINTER_ROLE();
  const XP_ROLE = await nft.XP_ROLE();
  await nft.grantRole(MINTER_ROLE, deployer.address);
  await nft.grantRole(XP_ROLE, deployer.address);

  console.log(`GrowQuestNFT deployed to: ${nft.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
