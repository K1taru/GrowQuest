import { ethers } from "hardhat";

/**
 * Helper function to deploy a contract by name with optional constructor arguments.
 * @param name The contract name (must match compiled artifact)
 * @param args Constructor arguments
 * @param libraries Optional library addresses
 * @returns The deployed contract instance
 */
export async function deployContract(
  name: string,
  args: any[] = [],
  libraries: any = {}
): Promise<any> {
  const factory = await ethers.getContractFactory(name, { libraries });
  const contract = await factory.deploy(...args);
  await contract.deployed();
  console.log(`${name} deployed at: ${contract.address}`);
  return contract;
}
