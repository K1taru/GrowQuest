// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./GreenToken.sol";
import "./GrowQuestNFT.sol";

/**
 * @title GrowthUtility
 * @notice Handles feeding (spending GREEN to add EXP), upgrading (leveling up plants), and burning plants.
 */
contract GrowthUtility is AccessControl {
    GrowQuestNFT public immutable nft;
    GreenToken public immutable greenToken;

    // Example burn reward base (per rarity level and plant level)
    uint256 public constant BURN_BASE = 10 * (10 ** 18); // 10 GREEN per (rarity+1)*level

    // Events
    event PlantFed(address indexed user, uint256 indexed tokenId, uint256 greenBurned, uint256 expGained);
    event PlantUpgraded(address indexed user, uint256 indexed tokenId, uint256 newLevel);
    event PlantBurned(address indexed user, uint256 indexed tokenId, uint256 greenMinted);

    /**
     * @notice Constructor sets NFT and token addresses.
     * @param nftAddress Address of the GrowQuestNFT contract.
     * @param tokenAddress Address of the GreenToken contract.
     */
    constructor(address nftAddress, address tokenAddress) {
        nft = GrowQuestNFT(nftAddress);
        greenToken = GreenToken(tokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Feed a plant by burning GREEN tokens to add EXP.
     * @param tokenId The plant NFT to feed.
     * @param greenAmount Amount of GREEN tokens to burn.
     */
    function feedPlant(uint256 tokenId, uint256 greenAmount) external {
        require(nft.ownerOf(tokenId) == msg.sender, "Not plant owner");
        require(greenAmount > 0, "Need to burn some GREEN");

        // Transfer and burn GREEN from user
        greenToken.transferFrom(msg.sender, address(this), greenAmount);
        greenToken.burn(greenAmount);

        // Grant EXP to the plant (1 EXP per token burned as example)
        nft.addExp(tokenId, greenAmount / (10 ** 18)); 

        emit PlantFed(msg.sender, tokenId, greenAmount, greenAmount / (10 ** 18));
    }

    /**
     * @notice Upgrade a plant's level if it has enough EXP and burns a GREEN fee.
     * @param tokenId The plant NFT to upgrade.
     */
    function upgradePlant(uint256 tokenId) external {
        require(nft.ownerOf(tokenId) == msg.sender, "Not plant owner");
        uint256 currentLevel = nft.tokenLevel(tokenId);
        Rarity rarity = nft.tokenRarity(tokenId);
        require(currentLevel < nft.maxLevelByRarity(rarity), "Max level reached");

        // Determine EXP requirement (e.g., level * 100 as in NFT logic)
        uint256 expNeeded = currentLevel * 100;
        require(nft.tokenEXP(tokenId) >= expNeeded, "Not enough EXP to upgrade");

        // Determine GREEN cost to upgrade (e.g., 50 tokens per level as example)
        uint256 greenCost = 50 * (10 ** 18);
        greenToken.transferFrom(msg.sender, address(this), greenCost);
        greenToken.burn(greenCost);

        // Call NFT to increase level
        nft.levelUp(tokenId);

        emit PlantUpgraded(msg.sender, tokenId, currentLevel + 1);
    }

    /**
     * @notice Burn a plant NFT in exchange for GREEN tokens based on rarity and level.
     * @param tokenId The plant NFT to burn.
     */
    function burnPlant(uint256 tokenId) external {
        require(nft.ownerOf(tokenId) == msg.sender, "Not plant owner");
        Rarity rarity = nft.tokenRarity(tokenId);
        uint256 level = nft.tokenLevel(tokenId);

        // Compute mint reward: base * (rarityIndex+1) * level
        uint256 rarityIndex = uint256(rarity);
        uint256 mintAmount = BURN_BASE * (rarityIndex + 1) * level;

        // Burn the NFT via the contract (requires role)
        // Grant this contract the role if not done already
        nft.burn(tokenId);

        // Mint GREEN tokens to user
        greenToken.mint(msg.sender, mintAmount);

        emit PlantBurned(msg.sender, tokenId, mintAmount);
    }
}
