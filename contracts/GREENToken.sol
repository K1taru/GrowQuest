// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title GreenToken
 * @notice ERC20 token used as rewards (GREEN) in the GrowQuest game. Minting is role-restricted.
 */
contract GreenToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @notice Constructor sets up roles and token details.
     * @param stakingVault Address of the StakingVault (granted MINTER_ROLE).
     * @param growthUtility Address of the GrowthUtility (granted MINTER_ROLE).
     */
    constructor(address stakingVault, address growthUtility) ERC20("Green Token", "GREEN") {
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, 0x767f100538EE5C9a48bE755d25455A7Df1Db8C63);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, 0x767f100538EE5C9a48bE755d25455A7Df1Db8C63);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, stakingVault);
        _grantRole(MINTER_ROLE, growthUtility);
    }

    /**
     * @notice Mints GREEN tokens to a specified address. Caller must have MINTER_ROLE.
     * @param to Recipient address.
     * @param amount Amount of tokens to mint (in wei, assuming 18 decimals).
     */
    function mint(address to, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender), "GreenToken: caller is not a minter");
        _mint(to, amount);
    }

    // Note: ERC20Burnable provides a public burn() allowing any holder to burn their tokens.
}
