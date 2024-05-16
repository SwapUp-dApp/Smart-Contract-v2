// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165Checker.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/utils/cryptography/EIP712.sol';

contract SwapUp is EIP712 {
    using ERC165Checker for address;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    // Event emitted when a token transfer occurs
    event TokenTransferred(
        address indexed assetAddress,
        address indexed party1Address,
        address indexed party2Address,
        uint256 amount
    );
    event NFTTransferred(
        address indexed assetAddress,
        address indexed party1Address,
        address indexed party2Address,
        uint256 tokenId
    );
    event SwapCreated(string swapId, address inititator, address responder);
    event SwapCompleted(string swapId, address inititator, address responder);
    event LogEvent(string text);

    constructor() EIP712('SwapUp', '1') {}

    struct Asset {
        address assetAddress;
        // can be either amount or NFT identifier
        uint256 value;
    }

    struct Swap {
        string swapId;
        address initiatorAddress;
        Asset[] initiatorAssets;
        address responderAddress;
        Asset[] responderAssets;
        bool initiatorApprove;
        bool responderApprove;
        string status; // PENDING, COMPLETED, REJECT
        string swapType; // OPEN, PRIVATE
    }

    mapping(string => Swap) public swaps;

    function approveAndSwap(
        string calldata swapId,
        address responderAddress,
        Asset[] calldata initiatorAssets,
        Asset[] calldata responderAssets,
        string calldata swapType
    ) public {
        Swap storage targetSwap = swaps[swapId];

        require(responderAddress != address(0), 'invalid initiator address');
        require(initiatorAssets.length > 0, 'no initiator assets found');
        require(responderAssets.length > 0, 'no contragent assets found');

        if (bytes(targetSwap.swapId).length > 0) {
            require(
                msg.sender == targetSwap.responderAddress,
                'only responder is allowed to proceed with this swap'
            );
            require(
                keccak256(bytes(targetSwap.status)) ==
                    keccak256(bytes('PENDING')),
                'Swap is not pending'
            );
            require(
                initiatorAssets.length == targetSwap.initiatorAssets.length,
                "Provided assets don't match to the initial swap setup"
            );
            require(
                responderAssets.length == targetSwap.responderAssets.length,
                "Provided assets don't match to the initial swap setup"
            );

            _validateAssetsBeforeTransfer(
                targetSwap.initiatorAssets,
                initiatorAssets
            );
            _validateAssetsBeforeTransfer(
                targetSwap.responderAssets,
                responderAssets
            );

            for (uint i = 0; i < targetSwap.initiatorAssets.length; i++) {
                _transferAssets(
                    targetSwap.initiatorAddress,
                    targetSwap.responderAddress,
                    targetSwap.initiatorAssets[i].assetAddress,
                    targetSwap.initiatorAssets[i].value
                );
            }

            for (uint i = 0; i < targetSwap.responderAssets.length; i++) {
                _transferAssets(
                    targetSwap.responderAddress,
                    targetSwap.initiatorAddress,
                    targetSwap.responderAssets[i].assetAddress,
                    targetSwap.responderAssets[i].value
                );
            }

            targetSwap.responderApprove = true;
            targetSwap.status = 'COMPLETED';

            emit SwapCompleted(
                swapId,
                targetSwap.initiatorAddress,
                targetSwap.responderAddress
            );
        } else {
            require(bytes(swapType).length > 0, 'Swap type is missing');
            require(
                keccak256(bytes(swapType)) == keccak256(bytes('OPEN')) ||
                    keccak256(bytes(swapType)) == keccak256(bytes('PRIVATE')),
                'Incorrect swapType provided'
            );

            targetSwap.swapId = swapId;
            targetSwap.initiatorAddress = msg.sender;
            targetSwap.responderAddress = responderAddress;
            targetSwap.initiatorApprove = true;
            targetSwap.responderApprove = false;
            targetSwap.status = 'PENDING';
            targetSwap.swapType = swapType;

            for (uint i = 0; i < initiatorAssets.length; i++) {
                targetSwap.initiatorAssets.push(
                    Asset({
                        assetAddress: initiatorAssets[i].assetAddress,
                        value: initiatorAssets[i].value
                    })
                );
            }

            for (uint i = 0; i < responderAssets.length; i++) {
                targetSwap.responderAssets.push(
                    Asset({
                        assetAddress: responderAssets[i].assetAddress,
                        value: responderAssets[i].value
                    })
                );
            }

            emit SwapCreated(
                swapId,
                targetSwap.initiatorAddress,
                targetSwap.responderAddress
            );
        }
    }

    function _validateAssetsBeforeTransfer(
        Asset[] storage swapPartyAssets,
        Asset[] calldata actualPartyAssets
    ) private view {
        require(swapPartyAssets.length > 0, 'No assets provided');
        require(actualPartyAssets.length > 0, 'No assets provided');
        require(
            actualPartyAssets.length == swapPartyAssets.length,
            'Invalid assets provided'
        );

        for (uint i = 0; i < actualPartyAssets.length; i++) {
            require(
                swapPartyAssets[i].assetAddress ==
                    actualPartyAssets[i].assetAddress,
                'asset address is incorrect'
            );
            require(
                swapPartyAssets[i].value == actualPartyAssets[i].value,
                'asset value is incorrect'
            );
        }
    }

    // Function to swap tokens from the contract address to the recipient address
    function transferTokens(
        address senderAddress,
        address recipient,
        address tokenAddress,
        uint256 amount
    ) public {
        require(senderAddress != address(0), 'Invalid sender address');

        // Check if receiver address is not zero
        require(recipient != address(0), 'Invalid receiver address');

        // Check if amount is not zero
        require(amount > 0, 'Invalid amount');

        // initiate safe transfer
        _safeTransferFrom(tokenAddress, senderAddress, recipient, amount);
    }

    function transferNFT(
        address senderAddress,
        address recipient,
        address nftAddress,
        uint256 tokenId
    ) public {
        require(senderAddress != address(0), 'Invalid sender address');
        require(recipient != address(0), 'Invalid receiver address');

        if (_isERC721(nftAddress)) {
            IERC721 nft = IERC721(nftAddress);
            require(
                nft.getApproved(tokenId) == address(this),
                'Token not approved for transfer'
            );

            // Transfer the NFT
            nft.safeTransferFrom(senderAddress, recipient, tokenId);
        } else if (_isERC1155(nftAddress)) {
            IERC1155 nft = IERC1155(nftAddress);

            nft.safeTransferFrom(senderAddress, recipient, tokenId, 1, '');
        }

        // Emit the NFT transfer event
        emit NFTTransferred(nftAddress, senderAddress, recipient, tokenId);
    }

    function _transferAssets(
        address party1,
        address party2,
        address assetAddress,
        uint256 assetValue
    ) internal {
        if (_isERC721(assetAddress) || _isERC1155(assetAddress)) {
            transferNFT(party1, party2, assetAddress, assetValue);
        } else {
            transferTokens(party1, party2, assetAddress, assetValue);
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
        require(token.balanceOf(sender) >= amount, 'Insufficient balance');

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
