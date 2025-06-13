// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IGreenToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IGrowQuestNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function expOf(uint256 tokenId) external view returns (uint256);
    function levelOf(uint256 tokenId) external view returns (uint256);
    function burnFromUtility(uint256 tokenId) external;
    function upgradeLevel(uint256 tokenId) external;
    function addExp(uint256 tokenId, uint256 amount) external;
}

contract GrowthUtility is AccessControl {
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    IGreenToken public greenToken;
    IGrowQuestNFT public nftContract;

    // Cost in GREEN tokens to level up
    uint256 public levelUpCost;
    // EXP points per 1 GREEN token when burning (e.g., 10 EXP per 1 GREEN)
    uint256 public expPerGreenToken;

    event SetGreenToken(address indexed tokenAddress);
    event SetNFTContract(address indexed nftAddress);
    event SetLevelUpCost(uint256 cost);
    event SetExpPerGreen(uint256 expPerToken);
    event PlantUpgraded(address indexed owner, uint256 tokenId, uint256 newLevel);
    event PlantBurned(address indexed owner, uint256 tokenId, uint256 exp, uint256 reward);
    event PlantFed(address indexed owner, uint256 tokenId, uint256 greenAmount, uint256 expAdded);

    constructor(address greenTokenAddress, address nftAddress) {
        require(greenTokenAddress != address(0), "Invalid token address");
        require(nftAddress != address(0), "Invalid NFT address");
        _grantRole(ADMIN_ROLE, msg.sender);

        greenToken = IGreenToken(greenTokenAddress);
        nftContract = IGrowQuestNFT(nftAddress);

        levelUpCost = 100;      // default level-up cost
        expPerGreenToken = 10;  // default ratio
    }

    // Admin functions to set addresses
    function setGreenTokenAddress(address tokenAddress) external onlyRole(ADMIN_ROLE) {
        require(tokenAddress != address(0), "Invalid address");
        greenToken = IGreenToken(tokenAddress);
        emit SetGreenToken(tokenAddress);
    }
    function setNFTContract(address nftAddress) external onlyRole(ADMIN_ROLE) {
        require(nftAddress != address(0), "Invalid address");
        nftContract = IGrowQuestNFT(nftAddress);
        emit SetNFTContract(nftAddress);
    }

    // Admin setters for costs and ratios
    function setLevelUpCost(uint256 cost) external onlyRole(ADMIN_ROLE) {
        levelUpCost = cost;
        emit SetLevelUpCost(cost);
    }
    function setExpPerGreenToken(uint256 expPerToken) external onlyRole(ADMIN_ROLE) {
        expPerGreenToken = expPerToken;
        emit SetExpPerGreen(expPerToken);
    }

    // User calls this to manually upgrade (level up) their plant
    function upgradePlant(uint256 tokenId) external {
        address owner = nftContract.ownerOf(tokenId);
        require(owner == msg.sender, "Not token owner");
        require(levelUpCost > 0, "Level up cost not set");

        uint256 currentExp = nftContract.expOf(tokenId);
        uint256 currentLevel = nftContract.levelOf(tokenId);
        // Example EXP requirement per level (customizable logic)
        require(currentExp >= currentLevel * 100, "Not enough EXP to level up");

        // Transfer and burn GREEN tokens
        require(greenToken.transferFrom(msg.sender, address(this), levelUpCost), "Transfer failed");
        greenToken.burn(levelUpCost);

        // Increase level on NFT
        nftContract.upgradeLevel(tokenId);

        emit PlantUpgraded(msg.sender, tokenId, currentLevel + 1);
    }

    // User calls this to burn their plant NFT and receive GREEN tokens reward
    function burnPlant(uint256 tokenId) external {
        address owner = nftContract.ownerOf(tokenId);
        require(owner == msg.sender, "Not token owner");

        uint256 exp = nftContract.expOf(tokenId);
        uint256 reward = expPerGreenToken > 0 ? exp / expPerGreenToken : 0;

        // Burn the NFT
        nftContract.burnFromUtility(tokenId);

        // Transfer reward to user (contract must hold sufficient GREEN tokens)
        if (reward > 0) {
            require(greenToken.transfer(msg.sender, reward), "Reward transfer failed");
        }
        emit PlantBurned(msg.sender, tokenId, exp, reward);
    }

    // User calls this to feed their plant and increase EXP (1 GREEN = 1 EXP)
    function feedPlant(uint256 tokenId, uint256 greenAmount) external {
        address owner = nftContract.ownerOf(tokenId);
        require(owner == msg.sender, "Not token owner");
        require(greenAmount > 0, "Must feed at least 1 GREEN token");

        // Transfer GREEN tokens from user to this contract and burn them
        require(greenToken.transferFrom(msg.sender, address(this), greenAmount), "Transfer failed");
        greenToken.burn(greenAmount);

        // 1 GREEN = 1 EXP
        uint256 expToAdd = greenAmount;

        // Add EXP to the NFT
        nftContract.addExp(tokenId, expToAdd);

        emit PlantFed(msg.sender, tokenId, greenAmount, expToAdd);
    }
}