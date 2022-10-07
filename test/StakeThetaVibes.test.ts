import { expect } from "chai";
import { ethers } from "hardhat";

describe("StakeThetaVibes", function () {
  let RewardToken, rewardToken, rewardTokenAddress: string, NFTContract, nftContract, nftContractAddress: string, StakingContract, stakingContract, stakingContractAddress: string, addr1, addr2, owner;

  this.beforeEach(async () => {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Reward Token Deployment and address retrieval
    RewardToken = await ethers.getContractFactory('RewardToken');
    rewardToken = await RewardToken.deploy();
    await rewardToken.deployed();
    rewardTokenAddress = rewardToken.address;


    // Nft
    NFTContract = await ethers.getContractFactory('NFTContract');
    nftContract = await NFTContract.deploy('NFTContract','NFT','testURI');
    await nftContract.deployed();
    nftContractAddress = nftContract.address;

    //Staking Contract
    StakingContract = await ethers.getContractFactory('StakeThetaVibes');
    stakingContract = await StakingContract.deploy(nftContractAddress, rewardTokenAddress, 100);
    await stakingContract.deployed();
    stakingContractAddress = stakingContract.address;
  });

  it('should be able to print the deployed contract addresses', async () => {
    console.log(rewardTokenAddress, nftContractAddress, stakingContractAddress)
  })
});
