const hre = require("hardhat");

async function main() {
  const contract = await hre.ethers.deployContract("GrowQuest");

  await contract.waitForDeployment();

  console.log(`Deployed to ${contract.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});