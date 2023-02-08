// SPDX-License-Identifier: MIT
pragma solidity >=0.4.17 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract SwapUp is EIP712 {
  constructor() EIP712("swap up","1.0") {}

  event txnSuccessful(string a, address tkn, string b, uint id, string c, address from, string d, address to);

  function swap(
    address sender,
    bytes memory msg,
    bytes memory signature
  ) external {
    // regenerating sign hash
    bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
      keccak256("set(address sender,bytes msg)"),
      sender,
      keccak256(abi.encodePacked(msg))
    )));
    // verifying sign
    address signer = ECDSA.recover(digest, signature);
    require(signer == sender, "MyFunction: invalid signature");
    require(signer != address(0), "ECDSA: invalid signature");
    // NFT trade
    (bytes[] memory tradeData) = abi.decode(msg,(bytes[]));
    (bytes[] memory initNfts, address initAddress) = abi.decode(tradeData[0],(bytes[],address));
    (bytes[] memory acceptNfts, address acceptAddress) = abi.decode(tradeData[1],(bytes[],address));
    for (uint i = 0; i < initNfts.length; i++) {
      (address tkn, uint id, uint chain) = abi.decode(initNfts[i],(address,uint,uint));
        if (chain==721) {
          IERC721(tkn).safeTransferFrom(initAddress,acceptAddress,id);
          emit txnSuccessful("NFT address: ", tkn, "NFT ID: ", id, "sender: ", initAddress, "receiver: ", acceptAddress);
        } else {
          IERC1155(tkn).safeTransferFrom(initAddress,acceptAddress,id,1,"");
          emit txnSuccessful("NFT address: ", tkn, "NFT ID: ", id, "sender: ", initAddress, "receiver: ", acceptAddress);
        }
    }
    for (uint i = 0; i < acceptNfts.length; i++) {
      (address tkn, uint id, uint chain) = abi.decode(acceptNfts[i],(address,uint,uint));
        if (chain==721) {
          IERC721(tkn).safeTransferFrom(acceptAddress,initAddress,id);
          emit txnSuccessful("NFT address: ", tkn, "NFT ID: ", id, "sender: ", acceptAddress, "receiver: ", initAddress);
        } else {
          IERC1155(tkn).safeTransferFrom(acceptAddress,initAddress,id,1,"");
          emit txnSuccessful("NFT address: ", tkn, "NFT ID: ", id, "sender: ", acceptAddress, "receiver: ", initAddress);
        }
    }
  }
  
}