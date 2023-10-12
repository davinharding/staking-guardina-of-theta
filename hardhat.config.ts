import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();

const THETA_TESTNET_KEY =process.env.THETA_TESTNET_KEY;
const THETA_MAINNET_KEY =process.env.THETA_MAINNET_KEY;

const config: HardhatUserConfig = {
  solidity: "0.8.4",
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

["0xe66c19ac7da21b000b88b2bc888f6cde54b13c2256c03358f69fc6eade1ec379", "0xbfa278780c3a27e10f6719a4a80f9150ce91dbb96d523778a1731c1af7d1c107", "0xdd488299bdd66934a9ce43fd8deaf523e6a57a9e05401bd275ae510f5d2911f2", "0xb06a2c5014e94eb445e0dd3c2193691dcd5a3d64c7eebaf1b7df871bd8ca57b2", "0x04d2153afcf8b934b5d34efb598648638e44f087bc706360928805ca76d670b4"]
