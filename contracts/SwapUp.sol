// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapUp {
    // Event emitted when a token transfer occurs
    event TokenTransferred(address indexed tokenAddress, address indexed sender, address indexed receiver, uint256 amount);
    event NFTTransferred(address indexed nftAddress, address indexed sender, address indexed receiver, uint256 tokenId);

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

    // function transferNFT(
    //     address senderAddress,
    //     address recipient,
    //     address nftAddress,
    //     uint256 tokenId
    // ) public {
    //     require(senderAddress != address(0), "Invalid sender address");
    //     require(recipient != address(0), "Invalid receiver address");

    //     IERC721 nft = IERC721(nftAddress);

    //     // Ensure the sender is the current owner of the token
    //     require(nft.ownerOf(tokenId) == senderAddress, "Sender must be the owner of the token");

    //     // Transfer the NFT
    //     nft.transferFrom(senderAddress, recipient, tokenId);

    //     // Emit the NFT transfer event
    //     emit NFTTransferred(nftAddress, senderAddress, recipient, tokenId);
    // }

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
}