import { expect } from "chai";
import { ethers } from "hardhat";

describe("GreenToken", () => {
  let token: any;
  let deployer: any;
  let user: any;

  beforeEach(async () => {
    [deployer, user] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("GreenToken");
    token = await Token.deploy();
    await token.deployed();
    // Assign roles to deployer
    await token.grantRole(await token.MINTER_ROLE(), deployer.address);
    await token.grantRole(await token.BURNER_ROLE(), deployer.address);
  });

  it("assigns default admin role to deployer", async () => {
    const DEFAULT_ADMIN_ROLE = ethers.constants.HashZero;
    expect(await token.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)).to.be.true;
  });

  it("only allows MINTER_ROLE to mint", async () => {
    // User without minter role should revert
    await expect(token.connect(user).mint(user.address, 100))
      .to.be.revertedWith("Caller is not a minter");
    // Deployer can mint
    await token.connect(deployer).mint(user.address, 100);
    expect(await token.balanceOf(user.address)).to.equal(100);
  });

  it("only allows BURNER_ROLE to burn", async () => {
    // Mint some tokens first
    await token.connect(deployer).mint(user.address, 100);
    // User (no burner role) tries to burn
    await expect(token.connect(user).burn(user.address, 50))
      .to.be.revertedWith("Caller is not a burner");
    // Deployer can burn
    await token.connect(deployer).burn(user.address, 50);
    expect(await token.balanceOf(user.address)).to.equal(50);
  });

  it("reverts when burning or minting with insufficient balance", async () => {
    // Unauthorized mint (no role) should revert
    await expect(token.connect(user).mint(user.address, 100))
      .to.be.reverted;
    // Authorized burn exceeding balance should revert
    await token.connect(deployer).mint(user.address, 50);
    await expect(token.connect(deployer).burn(user.address, 100))
      .to.be.revertedWith("burn amount exceeds balance");
  });
});
