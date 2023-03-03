import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const NFTContract = await ethers.getContractFactory('StakeAiSamurai');
  const nftContract = await NFTContract.deploy(
    "0xf7578080ffae18c9e3ba2eccd9628946816a7dfe", // erc721 address 
    "0x14e4c61d6aa9accda3850b201077cebf464dcb31", // erc20 address
    15, // reward rate per day
    );
  await nftContract.deployed();

  console.log("Token address:", nftContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
