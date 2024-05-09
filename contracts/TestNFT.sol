// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestNFT is ERC721Enumerable, Ownable {
    uint256 public nextTokenId;

    constructor(address _owner) ERC721("TestNFT", "MTNFT") Ownable(_owner) {}

    function mintTo(address to) public onlyOwner {
        _safeMint(to, nextTokenId++);
    }
}