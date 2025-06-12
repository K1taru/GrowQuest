import { ethers } from "hardhat";

/**
 * Deploy GrowQuestNFT contract.
 * @returns The deployed GrowQuestNFT contract instance.
 */
export async function deployGrowQuestNFT(): Promise<any> {
  const NFT = await ethers.getContractFactory("GrowQuestNFT");
  const nft = await NFT.deploy();
  await nft.deployed();
  return nft;
}

/**
 * Deploy GreenToken contract.
 * @returns The deployed GreenToken contract instance.
 */
export async function deployGreenToken(): Promise<any> {
  const Token = await ethers.getContractFactory("GreenToken");
  const token = await Token.deploy();
  await token.deployed();
  return token;
}

/**
 * Deploy StakingVault contract.
 * @param tokenAddress Address of the deployed GreenToken.
 * @param nftAddress Address of the deployed GrowQuestNFT.
 * @returns The deployed StakingVault contract instance.
 */
export async function deployStakingVault(
  tokenAddress: string,
  nftAddress: string
): Promise<any> {
  const Vault = await ethers.getContractFactory("StakingVault");
  const vault = await Vault.deploy(tokenAddress, nftAddress);
  await vault.deployed();
  return vault;
}

/**
 * Deploy GrowthUtility contract.
 * @param tokenAddress Address of the deployed GreenToken.
 * @param nftAddress Address of the deployed GrowQuestNFT.
 * @returns The deployed GrowthUtility contract instance.
 */
export async function deployGrowthUtility(
  tokenAddress: string,
  nftAddress: string
): Promise<any> {
  const Utility = await ethers.getContractFactory("GrowthUtility");
  const utility = await Utility.deploy(tokenAddress, nftAddress);
  await utility.deployed();
  return utility;
}
