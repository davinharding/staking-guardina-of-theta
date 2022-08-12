// SPDX-License-Identifier: MIT

// @Davin - This is simply the sappy seals staking contract copied into a new hardhat repo, will need to go in an retrofit all after this comment

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

pragma solidity ^0.8.13;

// 
/**
 * @title StakeThetaVibes
 * @custom:website www.thetavibes.com (subject to change)
 * @author Original author @lozzereth (www.allthingsweb3.com), forked and modified for the Theta Vibes project.
 * Make sure to check him out and give him a follow on twitter 
 */

contract StakeThetaVibes is ERC721, Ownable, IERC721Receiver {

    event ClaimedPixl(
        address person,
        uint256[] sealIds,
        uint256 pixlAmount,
        uint256 claimedAt
    );

    using Math for uint256;

    /// @notice Contract addresses
    IERC721[6] public erc721Addresses;
    IERC20 public erc20Address;
    uint256 public EXPIRATION;
    /// @notice Track the deposit and claim state of tokens
    struct StakedToken {
        uint256 claimedAt;
    }
    /// @notice Token info to be retrieved per account
    struct TokenPerAccount {
      address contractAddress;
      uint256 id;
    }

    uint256 rate;

    mapping(uint256 => StakedToken) public staked;

    mapping(address => TokenPerAccount[]) public tokensPerAccount;

    bool public pauseTokenEmissions = false;

    /// @notice Token non-existent
    error TokenNonExistent(uint256 tokenId);

    /// @notice Not an owner of the token
    error TokenNonOwner(uint256 tokenId);

    /// @notice Using a non-zero value
    error NonZeroValue();

    /// @notice Pause deposit blocks so this suffering can never happen again
    bool public pausedDepositBlocks = false;

    constructor(
        IERC721[6] _erc721Addresses,
        IERC20 _erc20Address,
        uint256 _rate
    ) public {
        erc721Addresses = _erc721Addresses;
        erc20Address = _erc20Address;
        rate = _rate;
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
        returns (StakedToken[] memory)
    {
       return tokensPerAccount[account];
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
            uint256 rewards = rate *
                (Math.min(block.number, EXPIRATION) -
                    staked[tokenId].claimedAt);
            return rewards;
        }
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
     * @dev Modify the ERC721 contract address
     * @param _newErc721Address - the new Staking contract
     */
    function setERC721Address(IERC721 _newErc721Address) external onlyOwner {
        erc721Address = _newErc721Address;
    }

    /**
     * @dev Update the rates
     * @param _rate - the new rate
     */
    function updateRewardRate(uint256 _rate) external onlyOwner {
        rate = _rate;
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