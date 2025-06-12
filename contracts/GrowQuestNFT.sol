// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract GrowQuestNFT is ERC721A, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant EXP_ROLE = keccak256("EXP_ROLE");

    string private _baseTokenURI;

    mapping(uint256 => uint8) public rarity;
    mapping(uint256 => uint256) private _xp;
    mapping(uint256 => uint8) private _level;

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721A(name, symbol) {
        _baseTokenURI = baseURI;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(EXP_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, AccessControl) returns (bool) {
        return ERC721A.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory baseURI) external onlyRole(URI_SETTER_ROLE) {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Mint function allowing only quantities of 1 or 10.
    function mint(uint256 quantity) external onlyRole(MINTER_ROLE) {
        require(quantity == 1 || quantity == 10, "Invalid quantity: must be 1 or 10");

        uint256 startTokenId = _nextTokenId();
        _safeMint(msg.sender, quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = startTokenId + i;
            _assignRarity(tokenId);
        }
    }

    // Assign rarity based on pseudorandomness (block data).
    function _assignRarity(uint256 tokenId) internal {
        // Pseudo-randomness using block data
        uint256 randomNum = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    msg.sender,
                    tokenId
                )
            )
        );

        uint8 rarityValue;
        uint256 rand100 = randomNum % 100;

        // Rarity distribution: 50% common (1), 30% uncommon (2), 10% rare (3), 6% epic (4), 3% legendary (5), 1% mythical (6)
        if (rand100 < 50) {
            rarityValue = 1; // common
        } else if (rand100 < 80) {
            rarityValue = 2; // uncommon
        } else if (rand100 < 90) {
            rarityValue = 3; // rare
        } else if (rand100 < 96) {
            rarityValue = 4; // epic
        } else if (rand100 < 99) {
            rarityValue = 5; // legendary
        } else {
            rarityValue = 6; // mythical (rand100 == 99)
        }

        rarity[tokenId] = rarityValue;
    }

    // Returns the rarity of a given token ID.
    function getRarity(uint256 tokenId) external view returns (uint8) {
        require(_exists(tokenId), "Nonexistent token");
        return rarity[tokenId];
    }

    // Adds experience points to a token and handles leveling.
    function gainExperience(uint256 tokenId, uint256 amount) external onlyRole(EXP_ROLE) {
        require(_exists(tokenId), "Nonexistent token");
        _xp[tokenId] += amount;
        // Example leveling: level up for each 100 XP
        uint8 newLevel = uint8(_xp[tokenId] / 100);
        if (newLevel > _level[tokenId]) {
            _level[tokenId] = newLevel;
        }
    }

    // Returns the experience of a given token ID.
    function getExperience(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Nonexistent token");
        return _xp[tokenId];
    }


    // Returns the level of a given token ID.
    function getLevel(uint256 tokenId) external view returns (uint8) {
        require(_exists(tokenId), "Nonexistent token");
        return _level[tokenId];
    }


    // Burn function, allowing token owner or BURNER_ROLE to burn.
    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwnerERC721A(msg.sender, tokenId) || hasRole(BURNER_ROLE, msg.sender), "Not authorized to burn");
        _burn(tokenId, true);
    }

    function _isApprovedOrOwnerERC721A(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }
}
