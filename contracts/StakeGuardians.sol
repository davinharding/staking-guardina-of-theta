// SPDX-License-Identifier: MIT

// @Davin - This is simply the sappy seals staking contract copied into a new hardhat repo, will need to go in an retrofit all after this comment

// @Davin - Need to add all openzeppelin import statements here

pragma solidity ^0.8.13;

/**
 * @title UntransferableERC721
 * @author @lozzereth (www.allthingsweb3.com)
 * @notice An NFT implementation that cannot be transfered no matter what
 *         unless minting or burning.
 */
contract UntransferableERC721 is ERC721, Ownable {
    /// @dev Base URI for the underlying token
    string private baseURI;

    /// @dev Thrown when an approval is made while untransferable
    error Unapprovable();

    /// @dev Thrown when making an transfer while untransferable
    error Untransferable();

    constructor(string memory name_, string memory symbol_)
    ERC721(name_, symbol_)
    {}

    /**
     * @dev Prevent token transfer unless burn
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721) {
        if (to != address(0) && from != address(0)) {
            revert Untransferable();
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Prevent approvals of staked token
     */
    function approve(address, uint256) public virtual override {
        revert Unapprovable();
    }

    /**
     * @dev Prevent approval of staked token
     */
    function setApprovalForAll(address, bool) public virtual override {
        revert Unapprovable();
    }

    /**
     * @notice Set the base URI for the NFT
     */
    function setBaseURI(string memory baseURI_) public virtual onlyOwner {
        baseURI = baseURI_;
    }

    /**
     * @dev Returns the base URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}

// 
/**
 * @title StakeSeals
 * @custom:website www.sappyseals.com
 * @author Original author @lozzereth (www.allthingsweb3.com), forked for Seals.
 * Make sure to check him out and give him a follow on twitter xoxo
 */
interface IStakeSeals {
    function setTokenAddress(address _tokenAddress) external;

    function depositsOf(address account)
        external
        view
        returns (uint256[] memory);

    function findRate(uint256 tokenId) external view returns (uint256 rate);

    function calculateRewards(address account, uint256[] memory tokenIds)
        external
        view
        returns (uint256[] memory rewards);

    function claimRewards(uint256[] calldata tokenIds) external;

    function deposit(uint256[] calldata tokenIds) external;

    function admin_deposit(uint256[] calldata tokenIds) external;

    function withdraw(uint256[] calldata tokenIds) external;

    function tokenRarity(uint256 tokenId)
        external
        view
        returns (uint256 rarity);
}

contract StakeSealsV2 is UntransferableERC721, IERC721Receiver {

    event ClaimedPixl(
        address person,
        uint256[] sealIds,
        uint256 pixlAmount,
        uint256 claimedAt
    );

    using Math for uint256;

    /// @notice Contract addresses
    IERC721 public erc721Address;
    IERC20 public erc20Address;
    IStakeSeals public stakeSealsV1;
    uint256 public EXPIRATION;
    /// @notice Track the deposit and claim state of tokens
    struct StakedToken {
        uint256 claimedAt;
    }
    mapping(uint256 => StakedToken) public staked;

    mapping(uint256 => uint256) public rewardRate;

    bool public pauseTokenEmissions = false;

    /// @notice Token non-existent
    error TokenNonExistent(uint256 tokenId);

    /// @notice Not an owner of the frog
    error TokenNonOwner(uint256 tokenId);

    /// @notice Using a non-zero value
    error NonZeroValue();

    /// @notice Pause deposit blocks so this suffering can never happen again
    bool public pausedDepositBlocks = false;

    constructor(
        IERC721 _erc721Address,
        IERC20 _erc20Address,
        IStakeSeals _stakeSealsV1Address,
        uint256[] memory _defaultRates
    ) UntransferableERC721("StakedSealsV2", "sSEAL") {
        erc721Address = _erc721Address;
        erc20Address = _erc20Address;
        stakeSealsV1 = _stakeSealsV1Address;
        setBaseURI("ipfs://QmXUUXRSAJeb4u8p4yKHmXN1iAKtAV7jwLHjw35TNm5jN7/");
        for (uint256 i = 0; i < 7; i++) {
            rewardRate[i] = _defaultRates[i];
        }
        EXPIRATION = block.number + 1000000000000000000000;
    }

    /**
     * @notice Track deposits of an account
     * @dev Intended for off-chain computation having O(totalSupply) complexity
     * @param account - Account to query
     * @return tokenIds
     */
    function depositsOf(address account)
        external
        view
        returns (uint256[] memory)
    {
        unchecked {
            uint256 tokenIdsIdx;
            uint256 tokenIdsLength = balanceOf(account);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            for (uint256 i; tokenIdsIdx != tokenIdsLength; ++i) {
                if (!_exists(i)) {
                    continue;
                }
                if (ownerOf(i) == account) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    /**
     * @notice Calculates the rewards for specific tokens under an address
     * @param account - account to check
     * @param tokenIds - token ids to check against
     * @return rewards
     */
    function calculateRewards(address account, uint256[] memory tokenIds)
        external
        view
        returns (uint256[] memory rewards)
    {
        rewards = new uint256[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            rewards[i] = _calculateReward(account, tokenIds[i]);
        }
        return rewards;
    }

    /**
     * @notice Calculates the rewards for specific token
     * @param account - account to check
     * @param tokenId - token id to check against
     * @return total
     */
    function calculateReward(address account, uint256 tokenId)
        external
        view
        returns (uint256 total)
    {
        return _calculateReward(account, tokenId);
    }

    function _calculateReward(address account, uint256 tokenId)
        private
        view
        returns (uint256 total)
    {
        if (!_exists(tokenId)) {
            revert TokenNonExistent(tokenId);
        }
        if (ownerOf(tokenId) != account) {
            revert TokenNonOwner(tokenId);
        }
        unchecked {
            uint256 rate = _findRate(tokenId);
            uint256 rewards = rate *
                (Math.min(block.number, EXPIRATION) -
                    staked[tokenId].claimedAt);
            return rewards;
        }
    }

    /**
     * @notice Finds the rates of NFTs from the old StakeSeal contract
     * @param tokenId - The id where you want to find the rate
     * @return rate - The rate
     */
    function findRate(uint256 tokenId) external view returns (uint256 rate) {
        return _findRate(tokenId);
    }

    function _findRate(uint256 tokenId) private view returns (uint256 rate) {
        uint256 rarity = stakeSealsV1.tokenRarity(tokenId);
        uint256 perDay = rewardRate[rarity];
        // 6000 blocks per day
        // perDay / 6000 = reward per block
        rate = (perDay * 1e18) / 6000;
        return rate;
    }

    /**
     * @notice Represent the staked information of specific token ids as an array of bytes.
     *         Intended for off-chain computation.
     * @param tokenIds - token ids to check against
     * @return stakedInfoBytes
     */
    function stakedInfoOf(uint256[] memory tokenIds)
        external
        view
        returns (bytes[] memory)
    {
        bytes[] memory stakedTimes = new bytes[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            stakedTimes[i] = abi.encodePacked(
                tokenId,
                staked[tokenId].claimedAt
            );
        }
        return stakedTimes;
    }

    /**
     * @notice Claim the rewards for the tokens
     * @param tokenIds - Array of token ids
     */
    function claimRewards(uint256[] calldata tokenIds) external {
        _claimRewards(tokenIds);
    }

    function _claimRewards(uint256[] calldata tokenIds) private {
        uint256 reward;
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            unchecked {
                reward += _calculateReward(msg.sender, tokenId);
            }
            if (!pausedDepositBlocks) {
                staked[tokenId].claimedAt = block.number;
            }
        }
        emit ClaimedPixl(msg.sender, tokenIds, reward, block.number);
        if (reward > 0 && !pauseTokenEmissions) {
            _safeTransferRewards(msg.sender, reward);
        }
    }

    /**
     * @notice Deposit tokens into the contract
     * @param tokenIds - Array of token ids to stake
     */
    function deposit(uint256[] calldata tokenIds) external {
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (!pausedDepositBlocks) {
                staked[tokenId].claimedAt = block.number;
            }
            erc721Address.safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                ""
            );
            _mint(msg.sender, tokenId);
        }
    }

    /**
     * @notice Withdraw tokens from the contract
     * @param tokenIds - Array of token ids to stake
     */
    function withdraw(uint256[] calldata tokenIds) external {
        _claimRewards(tokenIds);
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (!_exists(tokenId)) {
                revert TokenNonExistent(tokenId);
            }
            if (ownerOf(tokenId) != msg.sender) {
                revert TokenNonOwner(tokenId);
            }
            _burn(tokenId);
            erc721Address.safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                ""
            );
        }
    }

    /**
     * @notice Withdraw tokens from the staking contract
     * @param amount - Amount in wei to withdraw
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        _safeTransferRewards(msg.sender, amount);
    }

    /**
     *  @notice Toggles pause deposit blocks
     */

    function togglePauseDepositBlocks() external onlyOwner {
        pausedDepositBlocks = !pausedDepositBlocks;
    }

    /**
     * @dev Issues tokens only if there is a sufficient balance in the contract
     * @param recipient - receiving address
     * @param amount - amount in wei to transfer
     */
    function _safeTransferRewards(address recipient, uint256 amount) private {
        uint256 balance = erc20Address.balanceOf(address(this));
        if (amount <= balance) {
            erc20Address.transfer(recipient, amount);
        }
    }

    /**
     * @dev Modify the ERC20 token being emitted
     * @param _newErc20Address - address of token to emit
     */
    function setErc20Address(IERC20 _newErc20Address) external onlyOwner {
        erc20Address = _newErc20Address;
    }

    /**
     * @dev Modify the Staking contract address
     * @param _stakingContractV1Address - the new Staking contract
     */
    function setStakedSealsAddress(address _stakingContractV1Address)
        external
        onlyOwner
    {
        stakeSealsV1 = IStakeSeals(_stakingContractV1Address);
    }

    /**
     * @dev Modify the ERC721 contract address
     * @param _newErc721Address - the new Staking contract
     */
    function setERC721Address(IERC721 _newErc721Address) external onlyOwner {
        erc721Address = _newErc721Address;
    }

    /**
     * @dev Update the rates
     * @param index - the index of the new rate
     * @param rate - the new rate
     */
    function updateRewardRate(uint256 index, uint256 rate) external onlyOwner {
        rewardRate[index] = rate;
    }

    /**
     * @dev Toggle pausing the emissions
     */
    function toggleEmissions() external onlyOwner {
        pauseTokenEmissions = !pauseTokenEmissions;
    }

    /**
     * @dev Receive ERC721 tokens
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}