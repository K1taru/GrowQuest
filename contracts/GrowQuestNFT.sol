// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "erc721a/contracts/ERC721A.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title GrowQuestNFT
 * @notice ERC721A NFT contract for GrowQuest game plants, with Chainlink VRF rarity, EXP, levels, and burnable feature.
 */
contract GrowQuestNFT is ERC721A, VRFConsumerBaseV2, AccessControl {
    using Strings for uint256;

    enum Rarity { Common, Uncommon, Rare, Epic, Legendary, Mythical }

    // Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant GROWTH_UTILITY_ROLE = keccak256("GROWTH_UTILITY_ROLE");

    // Chainlink VRF configuration
    VRFCoordinatorV2Interface private immutable COORDINATOR;
    bytes32 private immutable keyHash;
    uint64 private s_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private callbackGasLimit = 100000;

    // Token metadata base URI
    string public baseTokenURI;

    // Token properties
    mapping(uint256 => Rarity) public tokenRarity;
    mapping(uint256 => uint256) public tokenEXP;
    mapping(uint256 => uint256) public tokenLevel;
    mapping(Rarity => uint256) public maxLevelByRarity;

    // VRF request trackers
    mapping(uint256 => uint256) private vrfRequestToTokenId;

    // Events
    event RandomnessRequested(uint256 indexed requestId, uint256 indexed tokenId);
    event RarityAssigned(uint256 indexed tokenId, Rarity rarity);
    event LevelUp(uint256 indexed tokenId, uint256 newLevel);
    event TokenBurned(uint256 indexed tokenId);

    /**
     * @notice Constructor sets up ERC721A, VRF, and initial roles/levels.
     * @param name_ NFT collection name.
     * @param symbol_ NFT symbol.
     * @param vrfCoordinator Chainlink VRF coordinator contract address.
     * @param vrfKeyHash Chainlink VRF key hash.
     * @param subscriptionId_ VRF subscription ID.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address vrfCoordinator,
        bytes32 vrfKeyHash,
        uint64 subscriptionId_
    ) ERC721A(name_, symbol_) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = vrfKeyHash;
        s_subscriptionId = subscriptionId_;

        // Set role admin
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Define max levels by rarity (example values)
        maxLevelByRarity[Rarity.Common] = 10;
        maxLevelByRarity[Rarity.Uncommon] = 20;
        maxLevelByRarity[Rarity.Rare] = 30;
        maxLevelByRarity[Rarity.Epic] = 40;
        maxLevelByRarity[Rarity.Legendary] = 50;
        maxLevelByRarity[Rarity.Mythical] = 60;
    }

    /** 
     * @notice Mint between 1 and 10 NFTs in a single transaction. Uses ERC721A batch minting.
     * @dev After minting, requests random words for each token to determine rarity.
     * @param quantity Number of NFTs to mint (max 10).
     */
    function mintPlants(uint256 quantity) external {
        require(quantity > 0 && quantity <= 10, "Mint 1-10 tokens at once");
        uint256 startTokenId = _nextTokenId();

        // Batch mint using ERC721A
        _safeMint(msg.sender, quantity);

        // Initialize levels and request VRF for each token
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = startTokenId + i;
            tokenLevel[tokenId] = 1;
            // Request randomness for rarity
            uint256 requestId = COORDINATOR.requestRandomWords(
                keyHash,
                s_subscriptionId,
                REQUEST_CONFIRMATIONS,
                callbackGasLimit,
                1
            );
            vrfRequestToTokenId[requestId] = tokenId;
            emit RandomnessRequested(requestId, tokenId);
        }
    }

    /** 
     * @notice VRF callback to assign rarity based on random number.
     * @param requestId ID of the VRF request.
     * @param randomWords Array containing the random word.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 tokenId = vrfRequestToTokenId[requestId];
        require(_exists(tokenId), "Token does not exist");

        uint256 rand = randomWords[0] % 100;
        Rarity rarity;
        if (rand < 50) {
            rarity = Rarity.Common;
        } else if (rand < 75) {
            rarity = Rarity.Uncommon;
        } else if (rand < 90) {
            rarity = Rarity.Rare;
        } else if (rand < 97) {
            rarity = Rarity.Epic;
        } else if (rand < 99) {
            rarity = Rarity.Legendary;
        } else {
            rarity = Rarity.Mythical;
        }
        tokenRarity[tokenId] = rarity;
        emit RarityAssigned(tokenId, rarity);
    }

    /**
     * @notice Adds EXP to a plant. Can only be called by staking or utility contracts.
     * @param tokenId The plant token ID.
     * @param amount Amount of EXP to add.
     */
    function addExp(uint256 tokenId, uint256 amount) external {
        require(_exists(tokenId), "Nonexistent token");
        // Only authorized contracts (e.g., staking vault or utility) can add EXP
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(GROWTH_UTILITY_ROLE, msg.sender), 
                "Not authorized");
        tokenEXP[tokenId] += amount;
    }

    /**
     * @notice Upgrade a plant's level if it has enough EXP. Only callable by GrowthUtility.
     * @param tokenId The plant token ID.
     */
    function levelUp(uint256 tokenId) external {
        require(_exists(tokenId), "Nonexistent token");
        require(hasRole(GROWTH_UTILITY_ROLE, msg.sender), "Not authorized");
        Rarity rarity = tokenRarity[tokenId];
        uint256 currentLevel = tokenLevel[tokenId];
        require(currentLevel < maxLevelByRarity[rarity], "Already at max level");
        // Example EXP requirement: level * 100
        uint256 expRequired = currentLevel * 100;
        require(tokenEXP[tokenId] >= expRequired, "Not enough EXP");
        tokenLevel[tokenId] = currentLevel + 1;
        tokenEXP[tokenId] -= expRequired;
        emit LevelUp(tokenId, tokenLevel[tokenId]);
    }

    /**
     * @notice Burns a plant NFT. Allows GrowthUtility (or owner) to burn.
     * @param tokenId The plant token ID.
     */
    function burn(uint256 tokenId) public {
        if (!hasRole(GROWTH_UTILITY_ROLE, msg.sender)) {
            // Regular burn: only owner or approved
            require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner nor approved");
        }
        _burn(tokenId);
        emit TokenBurned(tokenId);
    }

    /**
     * @notice Override _burn from ERC721A.
     */
    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
    }

    /**
     * @notice Returns the token URI, which is dynamic based on rarity and level.
     * Example: baseURI + "Common_level5.json".
     * @param tokenId The plant token ID.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        Rarity rarity = tokenRarity[tokenId];
        uint256 level = tokenLevel[tokenId];
        string memory rarityName;
        if (rarity == Rarity.Common) rarityName = "Common";
        else if (rarity == Rarity.Uncommon) rarityName = "Uncommon";
        else if (rarity == Rarity.Rare) rarityName = "Rare";
        else if (rarity == Rarity.Epic) rarityName = "Epic";
        else if (rarity == Rarity.Legendary) rarityName = "Legendary";
        else rarityName = "Mythical";

        return string(abi.encodePacked(baseTokenURI, "/", rarityName, "_level", level.toString(), ".json"));
    }

    /**
     * @notice Sets the base URI for all tokens. Only admin can call.
     * @param baseURI_ The base URI string.
     */
    function setBaseTokenURI(string calldata baseURI_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        baseTokenURI = baseURI_;
    }

    /**
     * @notice Grants the GrowthUtility contract permission to burn and upgrade plants.
     * @param utility The GrowthUtility contract address.
     */
    function setGrowthUtility(address utility) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _setupRole(GROWTH_UTILITY_ROLE, utility);
    }
}
