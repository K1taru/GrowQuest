import { ethers } from "hardhat";
import { Contract } from "ethers";

/**
 * Helper function to deploy a contract by name with optional constructor arguments and library addresses.
 * @param name The contract name (must match compiled artifact)
 * @param args Constructor arguments
 * @param libraries Optional library addresses for linked libraries
 * @returns The deployed contract instance (type-safe)
 */
export async function deployContract<T extends Contract>(
  name: string,
  args: any[] = [],
  libraries: { [libraryName: string]: string } = {}
): Promise<T> {
  try {
    const factory = await ethers.getContractFactory(name, { libraries });
    const contract = await factory.deploy(...args);
    await contract.waitForDeployment();
    const address = await contract.getAddress();
    console.log(`${name} deployed at: ${address}`);
    return contract as T;
  } catch (error) {
    console.error(`Failed to deploy ${name}:`, error);
    throw error;
  }
}