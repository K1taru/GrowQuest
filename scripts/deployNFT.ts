import hre from "hardhat";
import { deployContract } from "./utils/deployHelpers";
import * as dotenv from "dotenv";
dotenv.config();

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const placeholder = "0x0000000000000000000000000000000000000000";
  const greenTokenAddress = process.env.GREEN_TOKEN_ADDRESS as string; // Loaded from .env
  console.log(`Deploying GrowQuestNFT with account: ${deployer.address}`);

  // Deploy the GrowQuestNFT contract with placeholder for growthUtility
  const nft = await deployContract("GrowQuestNFT", [
    greenTokenAddress,
    placeholder,
    hre.ethers.parseEther("0.00001"),
    hre.ethers.parseEther("0.00005"),
    hre.ethers.parseEther("100")
  ]);
  console.log(`GrowQuestNFT deployed to: ${nft.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});