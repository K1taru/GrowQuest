import { ethers, run } from "hardhat";
import * as dotenv from "dotenv";
import {
  deployGrowQuestNFT,
  deployGreenToken,
  deployStakingVault,
  deployGrowthUtility,
} from "./utils/deployHelpers";

dotenv.config(); // Load environment variables (RPC URL, private key, etc.)

async function main() {
  // Use the first signer (deployer)
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy contracts
  const growQuestNFT = await deployGrowQuestNFT();
  const greenToken = await deployGreenToken();
  // StakingVault likely needs (token, nft) addresses
  const stakingVault = await deployStakingVault(greenToken.address, growQuestNFT.address);
  // GrowthUtility likely needs (token, nft) addresses
  const growthUtility = await deployGrowthUtility(greenToken.address, growQuestNFT.address);

  // Grant MINTER_ROLE (GreenToken) to the Vault and Utility
  const MINTER_ROLE = await greenToken.MINTER_ROLE();
  await greenToken.grantRole(MINTER_ROLE, stakingVault.address);
  await greenToken.grantRole(MINTER_ROLE, growthUtility.address);

  // Grant GROWTH_UTILITY_ROLE (GrowQuestNFT) to the Utility contract
  const GROWTH_UTILITY_ROLE = await growQuestNFT.GROWTH_UTILITY_ROLE();
  await growQuestNFT.grantRole(GROWTH_UTILITY_ROLE, growthUtility.address);

  // Log deployed addresses
  console.log("GrowQuestNFT deployed to:", growQuestNFT.address);
  console.log("GreenToken deployed to:", greenToken.address);
  console.log("StakingVault deployed to:", stakingVault.address);
  console.log("GrowthUtility deployed to:", growthUtility.address);
  console.log("MINTER_ROLE granted to StakingVault and GrowthUtility");
  console.log("GROWTH_UTILITY_ROLE granted to GrowthUtility");

  // Verify contracts on Etherscan
  await run("verify:verify", {
    address: growQuestNFT.address,
    constructorArguments: [], // Add args if the constructor has parameters
  });
  await run("verify:verify", {
    address: greenToken.address,
    constructorArguments: [],
  });
  await run("verify:verify", {
    address: stakingVault.address,
    constructorArguments: [],
  });
  await run("verify:verify", {
    address: growthUtility.address,
    constructorArguments: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
