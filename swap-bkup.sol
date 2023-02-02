// SPDX-License-Identifier: MIT
pragma solidity >=0.4.17 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Swap is EIP712 {
  constructor() EIP712("swap up","1.0") {}

  struct details {
    address token;
    address from;
    address to;
    uint id;
  }

  event txnSuccessful(string a, address tkn, string b, uint id, string c, address from, string d, address to);

  function executeSetIfSignatureMatch(
    address sender,
    uint256 deadline,
    string calldata msg,
    bytes memory signature
  ) external view {
    require(block.timestamp < deadline, "Signed transaction expired");

    bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
      keccak256("set(address sender,string msg,uint deadline)"),
      sender,
      keccak256(abi.encodePacked(msg)),
      deadline
    )));

    address signer = ECDSA.recover(digest, signature);
    require(signer == sender, "MyFunction: invalid signature");
    require(signer != address(0), "ECDSA: invalid signature");
  }

  function transfer(bytes[] memory nfts, address from, address to) public{
    for (uint i = 0; i < nfts.length; i++) {
      (address tkn, uint id) = abi.decode(nfts[i],(address,uint));
      IERC721(tkn).transferFrom(from,to,id);
      emit txnSuccessful("NFT address: ", tkn, "NFT ID: ", id, "sender: ", from, "receiver: ", to);
    }
  }
}