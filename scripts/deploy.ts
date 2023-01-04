import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const NFTContract = await ethers.getContractFactory('StakeGuardian');
  const nftContract = await NFTContract.deploy("0xcd8ee3078fa8565135f1e17974e04a6fbabedd66", "0xfdbf39114ba853d811032d3e528c2b4b7adcecd6", 500);
  await nftContract.deployed();

  console.log("Token address:", nftContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
