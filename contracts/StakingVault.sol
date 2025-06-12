// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./GreenToken.sol";
import "./GrowQuestNFT.sol";

/**
 * @title StakingVault
 * @notice Handles staking (locking) of GrowQuestNFTs to earn GREEN tokens and EXP.
 */
contract StakingVault is AccessControl {
    using SafeMath for uint256;

    // Interfaces to NFT and token contracts
    GrowQuestNFT public immutable nft;
    GreenToken public immutable greenToken;

    // Lock durations (in seconds) and corresponding reward multipliers (percentage basis)
    uint256[] public lockDurations = [1 days, 3 days, 7 days, 14 days, 30 days];
    uint256[] public multipliers = [100, 200, 400, 800, 1600]; // e.g., 100% (1x), 200% (2x), etc.

    // Base rewards (per 1-day lock)
    uint256 public constant BASE_GREEN_REWARD = 100 * (10 ** 18); // 100 GREEN tokens
    uint256 public constant BASE_EXP = 100;

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
     * @notice Constructor sets NFT and token contract addresses.
     * @param nftAddress Address of the GrowQuestNFT contract.
     * @param tokenAddress Address of the GreenToken contract.
     */
    constructor(address nftAddress, address tokenAddress) {
        nft = GrowQuestNFT(nftAddress);
        greenToken = GreenToken(tokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
     * @notice Claim a staked NFT after the lock period. Mints GREEN and grants EXP.
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
        uint256 idx;
        for (uint256 i = 0; i < lockDurations.length; i++) {
            if (lockDurations[i] == userStake.lockDuration) {
                idx = i;
                break;
            }
        }

        // Calculate rewards
        uint256 reward = BASE_GREEN_REWARD.mul(multipliers[idx]).div(100);
        uint256 expReward = BASE_EXP.mul(multipliers[idx]).div(100);

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
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
