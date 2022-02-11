//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../voting-tokens/VotesToken.sol";
import "../ACL.sol";

/**
 * @dev Initilizes Supply of votesToken
 */
contract VotesTokenWithSupplyModule is VotesToken {
    ACL acl;
    bytes32[] roles;

    /**
     * @dev Mints tokens to hodlers w/ allocations
     * @dev Returns the difference between total supply and allocations to treasury
     * @param name Token Name
     * @param symbol Token Symbol
     * @param hodlers Array of token receivers
     * @param allocations Allocations for each receiver
     * @param totalSupply Token's total supply
     * @param treasury Address to send difference between total supply and allocations
     * @param _acl Access controll list address
     * @param _roles Array of roles for permissions
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory hodlers,
        uint256[] memory allocations,
        uint256 totalSupply,
        address treasury,
        address _acl,
        bytes32[] memory _roles
    ) VotesToken(name, symbol) {
        uint256 tokenSum;
        for (uint256 i = 0; i < hodlers.length; i++) {
            _mint(hodlers[i], allocations[i]);
            tokenSum += allocations[i];
        }

        if (totalSupply > tokenSum) {
            _mint(treasury, totalSupply - tokenSum);
        }
        acl = ACL(_acl);
        roles = _roles;
    }

    function mint(address _receiver, uint256 _amount) public {
        require(acl.hasRole(roles[0], msg.sender), "Not Minter");
        _mint(_receiver, _amount);
    }
}
