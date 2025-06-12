const hre = require("hardhat");
require("dotenv").config();

async function main() {
    // Replace with your deployed contract addresses
    const GREEN_TOKEN_ADDRESS = process.env.GREEN_TOKEN_ADDRESS;
    const GROWTH_UTILITY_ADDRESS = process.env.GROWTH_UTILITY_ADDRESS;

    // Amount to mint (e.g., 10,000 GREEN tokens with 18 decimals)
    const amount = hre.ethers.utils.parseUnits("10000", 18);

    // Get signer (must have MINTER_ROLE)
    const [minter] = await hre.ethers.getSigners();

    // Attach to contracts
    const GreenToken = await hre.ethers.getContractFactory("GreenToken");
    const greenToken = GreenToken.attach(GREEN_TOKEN_ADDRESS);

    // Mint tokens to GrowthUtility contract
    const tx = await greenToken.connect(minter).mint(GROWTH_UTILITY_ADDRESS, amount);
    await tx.wait();

    console.log(`Minted ${amount.toString()} GREEN tokens to ${GROWTH_UTILITY_ADDRESS}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});