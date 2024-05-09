// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestNFT1155 is ERC1155, Ownable {
    uint256 public nextTokenId;

    constructor(string memory uri, address _owner) ERC1155(uri) Ownable(_owner) {}

    function mintTo(address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, abi.encode("Token Minted Successfully"));
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}