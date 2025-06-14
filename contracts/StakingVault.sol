// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./GREENToken.sol";
import "./GrowQuestNFT.sol";

/**
 * @title StakingVault
 * @notice Handles staking (locking) of GrowQuestNFTs to earn GREEN tokens and EXP, with rewards based on rarity.
 */
contract StakingVault is AccessControl, IERC721Receiver {
    // Interfaces to NFT and token contracts
    GrowQuestNFT public immutable nft;
    GreenToken public immutable greenToken;

    // Lock durations (in seconds) and corresponding reward multipliers (percentage basis)
    uint256[] public lockDurations = [1 days, 3 days, 7 days, 14 days, 30 days];
    uint256[] public multipliers = [100, 200, 400, 800, 1600]; // e.g., 100% (1x), 200% (2x), etc.

    // Base rewards per rarity (per 1-day lock)
    mapping(GrowQuestNFT.Rarity => uint256) public baseGreenRewardPerRarity;
    mapping(GrowQuestNFT.Rarity => uint256) public baseExpPerRarity;

    // Stake information mapped by NFT tokenId
    struct Stake {
        address owner;
        uint256 startTime;
        uint256 lockDuration;
        bool claimed;
    }
    mapping(uint256 => Stake) public stakes;

    // Events
    event Staked(address indexed user, uint256 indexed tokenId, uint256 lockDuration);
    event Unstaked(address indexed user, uint256 indexed tokenId, uint256 reward, uint256 expGained);

    /**
     * @notice Constructor sets NFT and token contract addresses and initializes base rewards per rarity.
     * @param nftAddress Address of the GrowQuestNFT contract.
     * @param tokenAddress Address of the GreenToken contract.
     */
    constructor(address nftAddress, address tokenAddress) {
        nft = GrowQuestNFT(nftAddress);
        greenToken = GreenToken(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Example base rewards per rarity, will adjust later
        baseGreenRewardPerRarity[GrowQuestNFT.Rarity.Common] = 100 * 1e18;
        baseGreenRewardPerRarity[GrowQuestNFT.Rarity.Uncommon] = 120 * 1e18;
        baseGreenRewardPerRarity[GrowQuestNFT.Rarity.Rare] = 150 * 1e18;
        baseGreenRewardPerRarity[GrowQuestNFT.Rarity.Epic] = 200 * 1e18;
        baseGreenRewardPerRarity[GrowQuestNFT.Rarity.Legendary] = 300 * 1e18;
        baseGreenRewardPerRarity[GrowQuestNFT.Rarity.Mythical] = 500 * 1e18;

        baseExpPerRarity[GrowQuestNFT.Rarity.Common] = 10;
        baseExpPerRarity[GrowQuestNFT.Rarity.Uncommon] = 12;
        baseExpPerRarity[GrowQuestNFT.Rarity.Rare] = 15;
        baseExpPerRarity[GrowQuestNFT.Rarity.Epic] = 20;
        baseExpPerRarity[GrowQuestNFT.Rarity.Legendary] = 30;
        baseExpPerRarity[GrowQuestNFT.Rarity.Mythical] = 50;
    }

    /**
     * @notice Stake an NFT by locking it for a chosen duration.
     * @param tokenId The NFT token ID to stake.
     * @param durationIndex Index into the lockDurations array (0 to 4).
     */
    function stake(uint256 tokenId, uint8 durationIndex) external {
        require(durationIndex < lockDurations.length, "Invalid lock duration");
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(stakes[tokenId].owner == address(0), "Already staked");

        // Transfer NFT to this contract
        IERC721(address(nft)).transferFrom(msg.sender, address(this), tokenId);

        // Record stake details
        stakes[tokenId] = Stake({
            owner: msg.sender,
            startTime: block.timestamp,
            lockDuration: lockDurations[durationIndex],
            claimed: false
        });

        emit Staked(msg.sender, tokenId, lockDurations[durationIndex]);
    }

    /**
     * @notice Claim a staked NFT after the lock period. Mints GREEN and grants EXP based on rarity.
     * @param tokenId The NFT token ID to claim.
     */
    function claim(uint256 tokenId) external {
        Stake storage userStake = stakes[tokenId];
        require(userStake.owner == msg.sender, "Not stake owner");
        require(!userStake.claimed, "Already claimed");
        require(block.timestamp >= userStake.startTime + userStake.lockDuration, "Lock period not ended");

        // Mark as claimed
        userStake.claimed = true;

        // Compute reward multiplier index
        uint256 idx = 0;
        for (uint256 i = 0; i < lockDurations.length; i++) {
            if (lockDurations[i] == userStake.lockDuration) {
                idx = i;
                break;
            }
        }

        // Get rarity of NFT
        GrowQuestNFT.Rarity rarity = nft.nftRarity(tokenId);

        // Calculate rewards based on rarity and multiplier
        uint256 reward = (baseGreenRewardPerRarity[rarity] * multipliers[idx]) / 100;
        uint256 expReward = (baseExpPerRarity[rarity] * multipliers[idx]) / 100;

        // Return NFT to user
        IERC721(address(nft)).safeTransferFrom(address(this), msg.sender, tokenId);

        // Mint GREEN tokens to user
        greenToken.mint(msg.sender, reward);

        // Grant EXP to the NFT
        nft.addExp(tokenId, expReward);

        emit Unstaked(msg.sender, tokenId, reward, expReward);
    }

    /**
     * @notice ERC721 receiver hook to allow safeTransferFrom.
     */
    function onERC721Received( //commented to silence unused parameter warnings
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}