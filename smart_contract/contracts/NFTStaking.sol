// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IAntToken.sol";
import "./interfaces/IAntNFT.sol";

/// @title the AntNFT staking vault
/// @author @nt96325
/// @notice this vault allwos users to stake their AntNFT tokens and earn daily rewards based on their overall staking period,
/// the rewards are distributed in the form of our own ERC20 token 'AntToken'
/// @dev this contract must be set as controller in the 'AntToken' contract to enable ERC20 rewards minting
/// @dev the daily reward logic is hadcoded  based on predefined staking period (see _calculateReward) and cannot be changed after deployment
contract NFTStaking is IERC721Receiver {
    // VALUES
    // -------------------------------------------------------------------------
    uint256 public totalItemStaked;
    uint256 private constant MONTH = 30 days;
    IAntToken immutable token;
    IAntNFT immutable nft;

    struct Stake {
        address owner;
        uint64 stakedAt;
    }

    // tokenId => Stake
    mapping(uint256 => Stake) vault;

    // EVENTS
    // -------------------------------------------------------------------------
    event ItemsStaked(uint256[] tokenId, address owner);
    event ItemsUnStaked(uint256[] tokenIds, address owner);
    event Claimed(address owner, uint256 reward);

    // ERRORS
    // -------------------------------------------------------------------------
    error NFTStaking__ItemAlreadyStaked();
    error NFTStaking__NotItemOwner();

    constructor(address _nftAddress, address _tokenAddress) {
        nft = IAntNFT(_nftAddress);
        token = IAntToken(_tokenAddress);
    }

    // FUNCTINOS
    // -------------------------------------------------------------------------

    /// @notice allow caller to stake multiple NFTs
    /// @dev only NFT owner should be able to call this, should have approved ERC721 transfer
    /// @param tokenIds array of token ids (uint256) to be staked
    function stake(uint256[] calldata tokenIds) external {
        uint256 stakedCount = tokenIds.length;

        for(uint256 i; i < stakedCount; ) {
            uint256 tokenId = tokenIds[i];
            if (vault[tokenId].owner != address(0))
                revert NFTStaking__ItemAlreadyStaked();
            if (nft.ownerOf(tokenId) != msg.sender)
                revert NFTStaking__NotItemOwner();
            nft.safeTransferFrom(msg.sender, address(this), tokenId);
            vault[tokenId] = Stake(msg.sender, uint64(block.timestamp));
            unchecked { ++i; }
        }
        totalItemStaked += stakedCount;

        emit ItemsStaked(tokenIds, msg.sender);
    }

    /// @notice allow caller to unstake multiple NFTs white also claiming any accrued rewards
    /// @dev only NFTs owner should be able to call this
    /// @param tokenIds array of token ids (uint256) to be unstaked
    function unstake(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds, true);
    }

    /// @notice allow caller to claim accrued rewards on staked NFTs
    /// @dev only NFT owner should be able to call this, will not unstake NFTs
    /// @param tokenIds array of token ids (uint256) to claim rewards for
    function claim(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds, false);
    }

    function _claim(address user, uint256[] calldata tokenIds, bool unstakeAll) internal {
        uint256 tokenId;
        uint256 rewardEarned;
        uint256 len = tokenIds.length;

        for(uint256 i; i < len; ){
            tokenId = tokenIds[i];
            if (vault[tokenId].owner != user) {
                revert NFTStaking__NotItemOwner();
            }
            uint256 _stakedAt = uint256(vault[tokenId].stakedAt);
            uint256 stakingPeriod = block.timestamp - _stakedAt;
            uint256 _dailyReward = _calculateReward(stakingPeriod);
            rewardEarned += (_dailyReward * stakingPeriod * 1e18) / 1 days;
            vault[tokenId].stakedAt = uint64(block.timestamp);
            unchecked {
                ++i;
            }
        }
        if(rewardEarned != 0) {
            token.mint(user, rewardEarned);
            emit Claimed(user, rewardEarned);
        }
        if(unstakeAll) {
            _unstake(user, tokenIds);
        }
    }

    function _unstake(address user, uint256[] calldata tokenIds) internal {
        uint256 unstakedCount = tokenIds.length;

        for(uint256 i; i < unstakedCount;){
            uint256 tokenId = tokenIds[i];
            require(vault[tokenId].owner == user, "Not Owner");

            delete vault[tokenId];
            nft.safeTransferFrom(address(this), user, tokenId);
            unchecked { ++i; }
        }

        totalItemStaked -= unstakedCount;

        emit ItemsUnStaked(tokenIds, user);
    }

    function _calculateReward(uint256 stakingPeriod) internal pure returns (uint256 dailyReward) {
        if (stakingPeriod <= MONTH)
            dailyReward = 1;
        else if (stakingPeriod < 3 * MONTH)
            dailyReward = 2;
        else if (stakingPeriod < 6 * MONTH)
            dailyReward = 4;
        else if (stakingPeriod > 6 * MONTH)
            dailyReward = 8;
    }

    function getDailyReward(uint256 stakingPeriod) external pure returns (uint256 dailyReward) {
        dailyReward = _calculateReward(stakingPeriod);
    }

    function getTotalRewardEarned(address user) external view returns (uint256 rewardEarned){
        uint256[] memory tokens = tokensOfOwner(user);
        for(uint256 i; i < tokens.length;){
            rewardEarned += getRewardEarnedPerNft(tokens[i]);
            unchecked { ++ i;}
        }
    }

    function getRewardEarnedPerNft(uint256 tokenId) internal view returns (uint256 rewardEarned) {
        uint256 _stakedAt = uint256(vault[tokenId].stakedAt);
        uint256 stakingPeriod = block.timestamp - _stakedAt;
        uint256 _dailyReward = _calculateReward(stakingPeriod);
        rewardEarned = ( _dailyReward * stakingPeriod * 1e18 ) / 1 days;
    }

    function balanceOf(address user) public view returns (uint256 nftStakedBalance){
        uint256 supply = nft.totalSupply();
        unchecked {
            for (uint256 i; i < supply; i++){
                if(vault[i].owner == user)
                    nftStakedBalance += 1;
            }   
        }
    }

    function tokensOfOwner(address user) public view returns (uint256[] memory tokens){
        uint256 balance = balanceOf(user);
        if (balance == 0) return tokens;
        uint256 supply = nft.totalSupply();
        tokens = new uint256[](balance);
        
        uint256 counter;
        unchecked {
            for (uint256 i; i < supply; i++){
                if(vault[i].owner == user) {
                    tokens[counter] = i;
                    counter ++;
                    if (counter == balance) return tokens;
                }
            }
        }
    }

    function onERC721Received(
        address /**operator */,
        address /**from */,
        uint256 /**amount */,
        bytes calldata //data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}