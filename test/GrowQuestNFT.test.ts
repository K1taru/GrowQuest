import { expect } from "chai";
import { ethers } from "hardhat";

describe("GrowQuestNFT", () => {
  let nft: any;
  let deployer: any;
  let user: any;
  let other: any;

  beforeEach(async () => {
    [deployer, user, other] = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("GrowQuestNFT");
    nft = await NFT.deploy();
    await nft.deployed();
    // Assign roles to deployer
    await nft.grantRole(await nft.MINTER_ROLE(), deployer.address);
    await nft.grantRole(await nft.XP_ROLE(), deployer.address);
  });

  it("assigns default admin and specific roles to deployer", async () => {
    const DEFAULT_ADMIN_ROLE = ethers.constants.HashZero;
    expect(await nft.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)).to.be.true;
    const minter = await nft.MINTER_ROLE();
    expect(await nft.hasRole(minter, deployer.address)).to.be.true;
    const xpRole = await nft.XP_ROLE();
    expect(await nft.hasRole(xpRole, deployer.address)).to.be.true;
  });

  it("only allows MINTER_ROLE to mint NFTs", async () => {
    // User (no role) tries to mint should revert
    await expect(nft.connect(user).mint(user.address))
      .to.be.revertedWith("Caller is not a minter");
    // Deployer (with minter role) can mint
    await nft.connect(deployer).mint(user.address);
    expect(await nft.ownerOf(0)).to.equal(user.address);
  });

  it("tracks experience and levels correctly", async () => {
    // Mint a new NFT to user
    await nft.connect(deployer).mint(user.address);
    const tokenId = 0;
    // Initial level and exp
    expect(await nft.levelOf(tokenId)).to.equal(1);
    expect(await nft.experienceOf(tokenId)).to.equal(0);

    // Add experience below threshold (assuming 1000 XP per level)
    await nft.connect(deployer).addExperience(tokenId, 500);
    expect(await nft.experienceOf(tokenId)).to.equal(500);
    expect(await nft.levelOf(tokenId)).to.equal(1);

    // Add experience to exceed threshold and level up
    await nft.connect(deployer).addExperience(tokenId, 600);
    // Total XP = 1100, so level should now be 2
    expect(await nft.experienceOf(tokenId)).to.equal(1100);
    expect(await nft.levelOf(tokenId)).to.equal(2);
  });

  it("allows only XP_ROLE to add experience", async () => {
    await nft.connect(deployer).mint(user.address);
    const tokenId = 0;
    // User without XP_ROLE tries to add experience
    await expect(nft.connect(user).addExperience(tokenId, 100))
      .to.be.revertedWith("Caller is not an experience manager");
  });

  it("reverts when adding experience to a non-existent token", async () => {
    await expect(nft.connect(deployer).addExperience(999, 100))
      .to.be.reverted;
  });
});
