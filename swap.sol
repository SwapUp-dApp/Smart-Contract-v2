// SPDX-License-Identifier: MIT
pragma solidity >=0.4.17 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Swap {
  constructor() {}

  function transfer(bytes[] memory nfts, address init, address accept) public{
    for (uint i = 0; i < nfts.length; i++) {
      (address tkn, uint id, bool flag) = abi.decode(nfts[i],(address,uint,bool));      
      if (flag) {
        IERC721(tkn).safeTransferFrom(init,accept,id);
      } else {
        IERC721(tkn).safeTransferFrom(accept,init,id);
      }
    }
  }
}