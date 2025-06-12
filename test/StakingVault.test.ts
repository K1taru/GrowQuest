import { expect } from "chai";
import { ethers } from "hardhat";

describe("StakingVault", () => {
  let token: any;
  let vault: any;
  let deployer: any;
  let user: any;

  beforeEach(async () => {
    [deployer, user] = await ethers.getSigners();
    // Deploy GreenToken and give deployer minter role
    const Token = await ethers.getContractFactory("GreenToken");
    token = await Token.deploy();
    await token.deployed();
    await token.grantRole(await token.MINTER_ROLE(), deployer.address);

    // Deploy StakingVault with the token address
    const Vault = await ethers.getContractFactory("StakingVault");
    vault = await Vault.deploy(token.address);
    await vault.deployed();

    // Grant the vault minter role on the token for rewards
    await token.grantRole(await token.MINTER_ROLE(), vault.address);

    // Mint tokens for the user to stake
    await token.connect(deployer).mint(user.address, 1000);
  });

  it("allows staking and then withdrawing with reward", async () => {
    // User approves and stakes 100 tokens
    await token.connect(user).approve(vault.address, 100);
    await vault.connect(user).stake(100);
    expect(await vault.stakedBalance(user.address)).to.equal(100);

    // Withdraw the 100 staked tokens
    await vault.connect(user).withdraw(100);
    // Expect user to get back 100 plus a 10% reward (10 tokens)
    const finalBalance = await token.balanceOf(user.address);
    expect(finalBalance).to.equal(1000 - 100 + 100 + 10);
  });

  it("calculates staking rewards correctly", async () => {
    // Stake 50 tokens and withdraw immediately
    await token.connect(user).approve(vault.address, 50);
    await vault.connect(user).stake(50);
    await vault.connect(user).withdraw(50);
    // User should have initial 1000 - 50 + 50 + 5 (10% reward)
    expect(await token.balanceOf(user.address)).to.equal(1000 - 50 + 50 + 5);
  });

  it("reverts on invalid stake or withdraw", async () => {
    // Stake without approval should revert
    await expect(vault.connect(user).stake(10)).to.be.reverted;
    // Withdraw without staking should revert
    await expect(vault.connect(user).withdraw(10))
      .to.be.revertedWith("Insufficient balance");
    // Stake some and then try to withdraw more than staked
    await token.connect(user).approve(vault.address, 20);
    await vault.connect(user).stake(20);
    await expect(vault.connect(user).withdraw(30))
      .to.be.revertedWith("Insufficient balance");
  });
});
