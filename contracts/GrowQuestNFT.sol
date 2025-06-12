// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Burnable {
    function transfer(address to, uint256 amount) external returns (bool);
}

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import path from "path";

require("dotenv").config({ path: path.resolve(__dirname, ".env") });
const { ADMIN_ADDRESS } = process.env;

contract GrowQuestNFT is ERC721, AccessControl {
    bytes32 public constant GROWTH_UTILITY_ROLE = keccak256("GROWTH_UTILITY_ROLE");

    enum Rarity { Common, Uncommon, Rare, Epic, Legendary, Mythical }

    uint256 public singleMintCost; // in wei (ETH)
    uint256 public batchMintCost;  // in wei (ETH)
    uint256 public nftBurnReward;  // Base GREEN tokens returned on burn

    IERC20Burnable public greenToken;
    uint256 public nextTokenId;

    mapping(uint256 => Rarity) public nftRarity;
    mapping(uint256 => uint256) public nftCurrentExpPts;   // EXP towards next level (resets on level up)
    mapping(uint256 => uint256) public nftTotalExpPts;     // Total EXP ever earned (never resets)
    mapping(uint256 => uint256) public nftLevel;

    mapping(Rarity => uint256) public rarityMaxLevel;
    mapping(Rarity => uint256) public rarityBaseEXP;

    constructor(
        address initialGreenToken,
        uint256 _singleCost,
        uint256 _batchCost,
        uint256 _burnReward
    ) ERC721("GrowQuestNFT", "GQNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, ADMIN_ADDRESS);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
        greenToken = IERC20Burnable(initialGreenToken);
        singleMintCost = _singleCost > 0 ? _singleCost : 0.00001 ether;
        batchMintCost = _batchCost > 0 ? _batchCost : 0.00005 ether;
        nftBurnReward = _burnReward > 0 ? _burnReward : 100 * 1e18; // Default 100 GREEN tokens
        nextTokenId = 1;

        // Set max levels per rarity
        rarityMaxLevel[Rarity.Common] = 5;
        rarityMaxLevel[Rarity.Uncommon] = 5;
        rarityMaxLevel[Rarity.Rare] = 6;
        rarityMaxLevel[Rarity.Epic] = 7;
        rarityMaxLevel[Rarity.Legendary] = 8;
        rarityMaxLevel[Rarity.Mythical] = 10;

        // Set base EXP per rarity (example values, adjust as you wish)
        rarityBaseEXP[Rarity.Common] = 100;
        rarityBaseEXP[Rarity.Uncommon] = 120;
        rarityBaseEXP[Rarity.Rare] = 150;
        rarityBaseEXP[Rarity.Epic] = 200;
        rarityBaseEXP[Rarity.Legendary] = 300;
        rarityBaseEXP[Rarity.Mythical] = 500;
    }

    // Admin functions
    function setSingleMintCost(uint256 cost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        singleMintCost = cost;
    }
    function setBatchMintCost(uint256 cost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        batchMintCost = cost;
    }
    function setnftBurnReward(uint256 reward) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nftBurnReward = reward;
    }
    function setGreenToken(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        greenToken = IERC20Burnable(tokenAddress);
    }
    function setrarityBaseEXP(Rarity rarity, uint256 exp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rarityBaseEXP[rarity] = exp;
    }

    // Mint a single token: pay ETH, mint NFT, set exp/level, assign rarity
    function mint() external payable {
        require(msg.value == singleMintCost, "Incorrect ETH sent");
        uint256 tokenId = nextTokenId;
        nextTokenId += 1;
        _safeMint(msg.sender, tokenId);
        nftCurrentExpPts[tokenId] = 0;
        nftTotalExpPts[tokenId] = 0;
        nftLevel[tokenId] = 1;
        nftRarity[tokenId] = _assignRarity(tokenId);
    }

    // Batch mint exactly 10 tokens: pay ETH, then mint 10
    function batchMint() external payable {
        require(msg.value == batchMintCost, "Incorrect ETH sent");
        for (uint i = 0; i < 10; i++) {
            uint256 tokenId = nextTokenId;
            nextTokenId += 1;
            _safeMint(msg.sender, tokenId);
            nftCurrentExpPts[tokenId] = 0;
            nftTotalExpPts[tokenId] = 0;
            nftLevel[tokenId] = 1;
            nftRarity[tokenId] = _assignRarity(tokenId);
        }
    }

    // Add EXP to a token (utility role only)
    function addExp(uint256 tokenId, uint256 amount) external onlyRole(GROWTH_UTILITY_ROLE) {
        require(_exists(tokenId), "Nonexistent token");
        nftCurrentExpPts[tokenId] += amount;
        nftTotalExpPts[tokenId] += amount;
    }

    // Upgrade level (utility role only)
    function upgradeLevel(uint256 tokenId) external onlyRole(GROWTH_UTILITY_ROLE) {
        require(_exists(tokenId), "Nonexistent token");
        uint256 currentLevel = nftLevel[tokenId];
        Rarity rarity = nftRarity[tokenId];
        require(currentLevel < rarityMaxLevel[rarity], "Already at max level for rarity");
        uint256 requiredExp = rarityBaseEXP[rarity] * currentLevel; // Linear, but per rarity
        require(nftCurrentExpPts[tokenId] >= requiredExp, "Not enough EXP to level up");
        nftLevel[tokenId] = currentLevel + 1;
        nftCurrentExpPts[tokenId] = 0; // Reset EXP towards next level
    }

    // Internal function to assign rarity based on weighted probability
    function _assignRarity(uint256 tokenId) internal view returns (Rarity) {
        uint256 rand = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            tokenId
        ))) % 100;

        if (rand < 50) return Rarity.Common;         // 50%
        else if (rand < 80) return Rarity.Uncommon;  // 30%
        else if (rand < 90) return Rarity.Rare;      // 10%
        else if (rand < 96) return Rarity.Epic;      // 6%
        else if (rand < 99) return Rarity.Legendary; // 3%
        else return Rarity.Mythical;                 // 1%
    }

    // Burn token and return GREEN tokens to owner (only GROWTH_UTILITY_ROLE)
    function burnFromUtility(uint256 tokenId) external onlyRole(GROWTH_UTILITY_ROLE) {
        require(_exists(tokenId), "Nonexistent token");
        address owner = ownerOf(tokenId);
        uint256 expBonus = (nftTotalExpPts[tokenId] * 5) / 10; // 0.5x total EXP, integer math
        uint256 totalReward = nftBurnReward + expBonus;
        _burn(tokenId);
        delete nftRarity[tokenId];
        delete nftCurrentExpPts[tokenId];
        delete nftTotalExpPts[tokenId];
        delete nftLevel[tokenId];
        require(greenToken.transfer(owner, totalReward), "GREEN transfer failed");
    }

    // Withdraw collected ETH (admin only)
    function withdrawETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        to.transfer(address(this).balance);
    }
}