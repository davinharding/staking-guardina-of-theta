import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();

const THETA_TESTNET_KEY =process.env.THETA_TESTNET_KEY;
const THETA_MAINNET_KEY =process.env.THETA_MAINNET_KEY;

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    thetaTestnet: {
      url: `https://eth-rpc-api-testnet.thetatoken.org/rpc`,
      accounts: [THETA_TESTNET_KEY as string],
      chainId: 365,
      gasPrice: 4000000000000
    },
    thetaMainnet: {
      url: `https://eth-rpc-api.thetatoken.org/rpc`,
      accounts: [THETA_MAINNET_KEY as string],
      chainId: 361,
      gasPrice: 4000000000000
    }
  }
}

export default config;
