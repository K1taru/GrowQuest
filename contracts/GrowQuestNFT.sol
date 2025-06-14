// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

interface IERC20Burnable {
    function transfer(address to, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}

contract GrowQuestNFT is ERC721, AccessControl {
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary, Mythical }

    bytes32 public constant GROWTH_UTILITY_ROLE = keccak256("GROWTH_UTILITY_ROLE");

    IERC20Burnable public greenToken;
    uint256 public singleMintCost;
    uint256 public batchMintCost;
    uint256 public nftBurnReward;
    uint256 public nextTokenId;

    mapping(uint256 => uint256) public nftCurrentExpPts;
    mapping(uint256 => uint256) public nftTotalExpPts;
    mapping(uint256 => uint256) public nftLevel;
    mapping(uint256 => Rarity) public nftRarity;

    mapping(Rarity => uint256) public rarityMaxLevel;
    mapping(Rarity => uint256) public rarityBaseEXP;

    // Dynamic NFT image logic: rarity + level group (every 2 levels)
    mapping(Rarity => mapping(uint256 => string)) public rarityLevelImage;

    event Minted(address indexed to, uint256 indexed tokenId, Rarity rarity);
    event BatchMinted(address indexed to, uint256[] tokenIds);
    event LevelUpgraded(uint256 indexed tokenId, uint256 newLevel);
    event Burned(address indexed owner, uint256 indexed tokenId, uint256 reward);

    // Required for ERC721 + AccessControl inheritance
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    constructor(
        address initialGreenToken,
        address growthUtility,
        uint256 _singleCost,
        uint256 _batchCost,
        uint256 _burnReward
    ) ERC721("GrowQuestNFT", "GQNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GROWTH_UTILITY_ROLE, growthUtility);

        greenToken = IERC20Burnable(initialGreenToken);
        singleMintCost = _singleCost > 0 ? _singleCost : 0.00001 ether;
        batchMintCost = _batchCost > 0 ? _batchCost : 0.00005 ether;
        nftBurnReward = _burnReward > 0 ? _burnReward : 100 * 1e18;
        nextTokenId = 1;

        rarityMaxLevel[Rarity.Common] = 5;
        rarityMaxLevel[Rarity.Uncommon] = 5;
        rarityMaxLevel[Rarity.Rare] = 6;
        rarityMaxLevel[Rarity.Epic] = 7;
        rarityMaxLevel[Rarity.Legendary] = 8;
        rarityMaxLevel[Rarity.Mythical] = 10;

        rarityBaseEXP[Rarity.Common] = 100;
        rarityBaseEXP[Rarity.Uncommon] = 120;
        rarityBaseEXP[Rarity.Rare] = 150;
        rarityBaseEXP[Rarity.Epic] = 200;
        rarityBaseEXP[Rarity.Legendary] = 300;
        rarityBaseEXP[Rarity.Mythical] = 500;
    }

    // Mint a single NFT
    function mint() external payable {
        require(msg.value == singleMintCost, "Incorrect ETH sent");
        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        nftCurrentExpPts[tokenId] = 0;
        nftTotalExpPts[tokenId] = 0;
        nftLevel[tokenId] = 1;
        nftRarity[tokenId] = _assignRarity(tokenId);
        emit Minted(msg.sender, tokenId, nftRarity[tokenId]);
    }

    // Batch mint exactly 10 tokens
    function batchMint() external payable {
        require(msg.value == batchMintCost, "Incorrect ETH sent");
        uint256[] memory tokenIds = new uint256[](10);
        for (uint i = 0; i < 10; i++) {
            uint256 tokenId = nextTokenId++;
            _safeMint(msg.sender, tokenId);
            nftCurrentExpPts[tokenId] = 0;
            nftTotalExpPts[tokenId] = 0;
            nftLevel[tokenId] = 1;
            nftRarity[tokenId] = _assignRarity(tokenId);
            tokenIds[i] = tokenId;
        }
        emit BatchMinted(msg.sender, tokenIds);
    }

    // Add EXP to a token (utility role only)
    function addExp(uint256 tokenId, uint256 amount) external onlyRole(GROWTH_UTILITY_ROLE) {
        require(nftLevel[tokenId] > 0, "Nonexistent token");
        nftCurrentExpPts[tokenId] += amount;
        nftTotalExpPts[tokenId] += amount;
    }

    // Upgrade level (utility role only)
    function upgradeLevel(uint256 tokenId) external onlyRole(GROWTH_UTILITY_ROLE) {
        require(nftLevel[tokenId] > 0, "Nonexistent token");
        uint256 currentLevel = nftLevel[tokenId];
        Rarity rarity = nftRarity[tokenId];
        require(currentLevel < rarityMaxLevel[rarity], "Already at max level for rarity");
        uint256 requiredExp = rarityBaseEXP[rarity] * currentLevel;
        require(nftCurrentExpPts[tokenId] >= requiredExp, "Not enough EXP to level up");
        nftCurrentExpPts[tokenId] -= requiredExp;
        nftLevel[tokenId] += 1;
        emit LevelUpgraded(tokenId, nftLevel[tokenId]);
    }

    // Burn token and return GREEN tokens to owner (only GROWTH_UTILITY_ROLE)
    function burnFromUtility(uint256 tokenId) external onlyRole(GROWTH_UTILITY_ROLE) {
        require(nftLevel[tokenId] > 0, "Nonexistent token");
        address owner = ownerOf(tokenId);
        uint256 expBonus = (nftTotalExpPts[tokenId] * 5) / 10;
        uint256 totalReward = nftBurnReward + expBonus;
        _burn(tokenId);
        delete nftRarity[tokenId];
        delete nftCurrentExpPts[tokenId];
        delete nftTotalExpPts[tokenId];
        delete nftLevel[tokenId];
        require(greenToken.transfer(owner, totalReward), "GREEN transfer failed");
        emit Burned(owner, tokenId, totalReward);
    }

    // Assign rarity (example logic)
    function _assignRarity(uint256 tokenId) internal view returns (Rarity) {
        uint256 rand = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp, blockhash(block.number - 1)))) % 100;
        if (rand < 60) return Rarity.Common;
        else if (rand < 80) return Rarity.Uncommon;
        else if (rand < 90) return Rarity.Rare;
        else if (rand < 96) return Rarity.Epic;
        else if (rand < 99) return Rarity.Legendary;
        else return Rarity.Mythical;
    }

    // --- Dynamic NFT image logic ---

    // Admin sets the image URI for each rarity and level group (every 2 levels)
    function setImageURI(Rarity rarity, uint256 levelGroup, string calldata uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rarityLevelImage[rarity][levelGroup] = uri;
    }

    // Helper: Get the level group (1–2: 1, 3–4: 3, 5–6: 5, etc.)
    function _levelGroup(uint256 level) internal pure returns (uint256) {
        return ((level - 1) / 2) * 2 + 1;
    }

    // Helper: Rarity to string
    function _rarityToString(Rarity rarity) internal pure returns (string memory) {
        if (rarity == Rarity.Common) return "Common";
        if (rarity == Rarity.Uncommon) return "Uncommon";
        if (rarity == Rarity.Rare) return "Rare";
        if (rarity == Rarity.Epic) return "Epic";
        if (rarity == Rarity.Legendary) return "Legendary";
        if (rarity == Rarity.Mythical) return "Mythical";
        return "";
    }

    // Dynamic metadata with image that changes by rarity and every 2 levels
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(nftLevel[tokenId] > 0, "Nonexistent token");
        Rarity rarity = nftRarity[tokenId];
        uint256 level = nftLevel[tokenId];
        uint256 group = _levelGroup(level);
        string memory image = rarityLevelImage[rarity][group];

        string memory json = string(abi.encodePacked(
            '{"name":"GrowQuest NFT #', Strings.toString(tokenId),
            '","description":"A dynamic NFT that evolves with level and rarity.",',
            '"attributes":[{"trait_type":"Rarity","value":"', _rarityToString(rarity),
            '"},{"trait_type":"Level","value":"', Strings.toString(level), '"}],',
            '"image":"', image, '"}'
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }

    // --- End dynamic NFT image logic ---

    // Admin functions (setters)
    function setSingleMintCost(uint256 cost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        singleMintCost = cost;
    }
    function setBatchMintCost(uint256 cost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        batchMintCost = cost;
    }
    function setBurnReward(uint256 reward) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nftBurnReward = reward;
    }
    function setGreenToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        greenToken = IERC20Burnable(token);
    }
    function withdrawETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        to.transfer(address(this).balance);
    }
}