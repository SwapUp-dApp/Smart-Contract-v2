// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract SwapUp {
    // Event emitted when a token transfer occurs
    event TokenTransferred(address indexed tokenAddress, address indexed sender, address indexed receiver, uint256 amount);
    event NFTTransferred(address indexed nftAddress, address indexed sender, address indexed receiver, uint256 tokenId);

    using ERC165Checker for address;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    // Function to swap tokens from the contract address to the recipient address
    function transferTokens(
        address senderAddress,
        address recipient,
        address tokenAddress,
        uint256 amount
    ) public {
        require(senderAddress != address(0), "Invalid sender address");
        
        // Check if receiver address is not zero
        require(recipient != address(0), "Invalid receiver address");
        
        // Check if amount is not zero
        require(amount > 0, "Invalid amount");

        // initiate safe transfer
        _safeTransferFrom(tokenAddress, senderAddress, recipient, amount);
    }

    function transferNFT(
        address senderAddress,
        address recipient,
        address nftAddress,
        uint256 tokenId,
        uint256 quantity
    ) public {
        require(senderAddress != address(0), "Invalid sender address");
        require(recipient != address(0), "Invalid receiver address");

        if (_isERC721(nftAddress)) {
            IERC721 nft = IERC721(nftAddress);

            require(nft.ownerOf(tokenId) == senderAddress, "Sender must be the owner of the token");

            // Transfer the NFT
            nft.transferFrom(senderAddress, recipient, tokenId);
            
            // Emit the NFT transfer event
            emit NFTTransferred(nftAddress, senderAddress, recipient, tokenId);
        } else if (_isERC1155(nftAddress)) {
            IERC1155 nft = IERC1155(nftAddress);

            require(nft.balanceOf(senderAddress, tokenId) >= quantity, "Insufficient balance");

            nft.safeTransferFrom(senderAddress, recipient, tokenId, quantity, "");

            // Emit the NFT transfer event
            emit NFTTransferred(nftAddress, senderAddress, recipient, tokenId);
        }
        
    }

    function _safeTransferFrom(
        address tokenAddress,
        address sender,
        address recipient,
        uint256 amount
    ) private {
        IERC20 token = IERC20(tokenAddress);

        // Check if the sender has enough balance
        require(token.balanceOf(sender) >= amount, "Insufficient balance");

        token.approve(address(this), amount);
                
        token.transferFrom(sender, recipient, amount);
    }

    function _isERC721(address token) internal view returns (bool) {
        return token.supportsInterface(INTERFACE_ID_ERC721);
    }

    function _isERC1155(address token) internal view returns (bool) {
        return token.supportsInterface(INTERFACE_ID_ERC1155);
    }
}