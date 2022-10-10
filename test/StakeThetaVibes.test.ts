import { expect } from "chai";
import { ethers, network } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("StakeThetaVibes", function () {
  let RewardToken: ContractFactory, 
  rewardToken: Contract, 
  rewardTokenAddress: string, 
  NFTContract: ContractFactory, 
  nftContract: Contract, 
  nftContractAddress: string, 
  StakingContract: ContractFactory, 
  stakingContract: Contract, 
  stakingContractAddress: string, 
  addr1: SignerWithAddress, 
  addr2: SignerWithAddress, 
  owner: SignerWithAddress;

  this.beforeEach(async () => {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Reward Token Deployment and address retrieval
    let ethersToWei = ethers.utils.parseUnits((10000000).toString(), "ether");
    RewardToken = await ethers.getContractFactory('RewardToken');
    rewardToken = await RewardToken.deploy("Reward Token", "RTKN", 18, ethersToWei, true);
    await rewardToken.deployed();
    rewardTokenAddress = rewardToken.address;

    // Nft
    NFTContract = await ethers.getContractFactory('Guardian');
    nftContract = await NFTContract.deploy(owner.address,'testURI');
    await nftContract.deployed();
    nftContractAddress = nftContract.address;

    // Staking Contract
    StakingContract = await ethers.getContractFactory('StakeThetaVibes');
    stakingContract = await StakingContract.deploy(nftContractAddress, rewardTokenAddress, 100);
    await stakingContract.deployed();
    stakingContractAddress = stakingContract.address;

    // Deposit reward token to staking contract
    rewardToken.approve(owner.address, ethers.utils.parseUnits((10000000).toString(), "ether"));
    await rewardToken.transferFrom(owner.address, stakingContractAddress, 1000000)

    // Activate nft minting
    await nftContract.flipSaleState();

    // mint 2 nfts to addr1
    await nftContract.connect(addr1).safeMint(addr1.address, {
      value: ethers.utils.parseEther("500"),
    });
    await nftContract.connect(addr1).safeMint(addr1.address, {
      value: ethers.utils.parseEther("500"),
    });

    // // stake approval for addr1
    await nftContract.connect(addr1).setApprovalForAll(stakingContractAddress, true);

    // stake nft from addr1
    await stakingContract.connect(addr1).deposit([1,2]);
  });

  xit('should be able to print the deployed contract addresses and confirm they are strings', async () => {

    expect(rewardTokenAddress).to.be.a('string');
    expect(nftContractAddress).to.be.a('string');
    expect(stakingContractAddress).to.be.a('string');
  });

  xit('should deposit 100000 reward tokens to staking contract', async () => {
    expect((await rewardToken.balanceOf(stakingContractAddress)).toNumber()).to.equal(1000000);
  });

  it('should allow the user to stake their NFTs', async () => {
    const idArr = await stakingContract.depositsOf(addr1.address);
    expect(parseInt(idArr[0])).to.equal(1);
    expect(parseInt(idArr[1])).to.equal(2);
  });

  it('should accrue 100 reward tokens per day', async () => {
    // advance 6000 block ~ 1 day
    await network.provider.send("hardhat_mine", [ethers.utils.hexlify(6000)]);
    // calculate current reward
    const reward = await stakingContract.calculateReward(addr1.address, 1);
    const rewardInEth = ethers.utils.formatEther(reward);
    // reward should be 100 tokens per day based on deploy params of stake contract
    expect(Math.round(parseFloat(rewardInEth))).to.equal(100);
  })
});
