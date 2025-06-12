import { expect } from "chai";
import { ethers } from "hardhat";

describe("GrowthUtility", () => {
  let nft: any;
  let token: any;
  let utility: any;
  let deployer: any;
  let user: any;

  beforeEach(async () => {
    [deployer, user] = await ethers.getSigners();

    // Deploy and set up NFT
    const NFT = await ethers.getContractFactory("GrowQuestNFT");
    nft = await NFT.deploy();
    await nft.deployed();
    await nft.grantRole(await nft.MINTER_ROLE(), deployer.address);
    await nft.grantRole(await nft.XP_ROLE(), deployer.address);

    // Deploy and set up GreenToken
    const Token = await ethers.getContractFactory("GreenToken");
    token = await Token.deploy();
    await token.deployed();
    await token.grantRole(await token.MINTER_ROLE(), deployer.address);
    await token.grantRole(await token.BURNER_ROLE(), deployer.address);

    // Deploy GrowthUtility with NFT and token addresses
    const Utility = await ethers.getContractFactory("GrowthUtility");
    utility = await Utility.deploy(nft.address, token.address);
    await utility.deployed();
    // Grant GrowthUtility minter role on token for rewards
    await token.grantRole(await token.MINTER_ROLE(), utility.address);

    // Mint an NFT for user and add experience
    await nft.connect(deployer).mint(user.address);
    await nft.connect(deployer).addExperience(0, 1500); // Level up NFT
    // User approves utility to burn their NFT
    await nft.connect(user).approve(utility.address, 0);
  });

  it("burns NFT for GREEN tokens based on level", async () => {
    const beforeBalance = await token.balanceOf(user.address);
    await utility.connect(user).burnForGreen(0);
    const afterBalance = await token.balanceOf(user.address);
    // NFT was leveled up (XP=1500 -> level 2), reward = 200 tokens (100 per level)
    expect(afterBalance.sub(beforeBalance)).to.equal(200);
    // The NFT should be burned (no owner)
    await expect(nft.ownerOf(0)).to.be.reverted;
  });

  it("reverts when a non-owner tries to burn an NFT", async () => {
    // Mint an NFT to deployer, approve it to utility (not needed but setup)
    await nft.connect(deployer).mint(deployer.address);
    await nft.connect(deployer).approve(utility.address, 1);
    // User (not owner) attempts to burn
    await expect(utility.connect(user).burnForGreen(1))
      .to.be.revertedWith("Caller is not owner");
  });

  it("reverts when trying to burn a nonexistent NFT", async () => {
    await expect(utility.connect(user).burnForGreen(999))
      .to.be.reverted;
  });
});
