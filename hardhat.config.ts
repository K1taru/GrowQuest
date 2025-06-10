import path from "path";
require("dotenv").config({ path: path.resolve(__dirname, ".env")});
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const { PRIVATE_KEY } = process.env;

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    base_sepolia:{
      accounts:[
        PRIVATE_KEY as string
      ],
      url: "https://sepolia.base.org",
    }
  },
};

export default config;
