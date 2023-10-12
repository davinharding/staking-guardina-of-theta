import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  const NFTContract = await ethers.getContractFactory('StakeLilMonsters');
  const nftContract = await NFTContract.deploy(
    "0xDe402d4dEfF8CEa11F515a7BeF886277b32CBC5a", // erc721 address 
    "0x14e4c61d6aa9accda3850b201077cebf464dcb31", // erc20 address
    1, // reward rate per day
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
