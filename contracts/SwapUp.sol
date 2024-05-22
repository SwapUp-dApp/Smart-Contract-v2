// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/common/ERC2981.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165Checker.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';

contract SwapUp is EIP712, Ownable {
    using ERC165Checker for address;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    AggregatorV3Interface internal priceFeed;

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

    address public treasuryWalletAddress;
    uint256 public platformFeeAmount;
    uint256 public currencyFeeAmount;
    uint256 public currencyFeeAmountWithSubdomen;

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
    event SwapCreated(string swapId, address initiator, address responder);
    event SwapCompleted(string swapId, address initiator, address responder);
    event CommissionUpdated(string commissionType, uint256 amount);
    event AddressUpdated(string addressType, address newAddress);

    constructor(
        address initialOwner,
        address _treasuryWalletAddress,
        uint256 _platformFeeAmount,
        uint256 _currencyFeeAmount,
        uint256 _currencyFeeAmountWithSubdomen,
        address _priceFeedAddress
    ) EIP712('SwapUp', '1') Ownable(initialOwner) {
        treasuryWalletAddress = _treasuryWalletAddress;
        platformFeeAmount = _platformFeeAmount;
        currencyFeeAmount = _currencyFeeAmount;
        currencyFeeAmountWithSubdomen = _currencyFeeAmountWithSubdomen;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function setTreasuryWalletAddress(
        address _treasuryWalletAddress
    ) external onlyOwner {
        treasuryWalletAddress = _treasuryWalletAddress;
        emit AddressUpdated('TreasuryWalletAddress', _treasuryWalletAddress);
    }

    function setPlatformFeeAmount(
        uint256 _platformFeeAmount
    ) external onlyOwner {
        platformFeeAmount = _platformFeeAmount;
        emit CommissionUpdated('PlatformFeeAmount', _platformFeeAmount);
    }

    function setCurrencyFeeAmount(
        uint256 _currencyFeeAmount
    ) external onlyOwner {
        require(_currencyFeeAmount <= 100, 'Fee must be between 0 and 100');
        currencyFeeAmount = _currencyFeeAmount;
        emit CommissionUpdated('CurrencyFeeAmount', _currencyFeeAmount);
    }

    function setCurrencyFeeAmountWithSubdomen(
        uint256 _currencyFeeAmountWithSubdomen
    ) external onlyOwner {
        currencyFeeAmountWithSubdomen = _currencyFeeAmountWithSubdomen;
        emit CommissionUpdated(
            'CurrencyFeeAmountWithSubdomen',
            _currencyFeeAmountWithSubdomen
        );
    }

    function approveAndSwap(
        string calldata swapId,
        address responderAddress,
        Asset[] calldata initiatorAssets,
        Asset[] calldata responderAssets,
        string calldata swapType
    ) public payable {
        Swap storage targetSwap = swaps[swapId];

        require(responderAddress != address(0), 'Invalid responder address');
        require(initiatorAssets.length > 0, 'No initiator assets found');
        require(responderAssets.length > 0, 'No responder assets found');

        // Calculate the equivalent ETH amount for $10 using Chainlink price feed
        uint256 ethAmountForPlatformFee = getFeeInETH();

        // Ensure both parties have provided enough ETH for the platform fee
        require(
            msg.value >= ethAmountForPlatformFee,
            'Insufficient ETH for platform fee'
        );

        // Transfer platform fee from responder to the contract
        payable(treasuryWalletAddress).transfer(msg.value);

        if (bytes(targetSwap.swapId).length > 0) {
            require(
                msg.sender == targetSwap.responderAddress,
                'Only responder is allowed to proceed with this swap'
            );
            require(
                keccak256(bytes(targetSwap.status)) ==
                    keccak256(bytes('PENDING')),
                'Swap is not pending'
            );
            require(
                initiatorAssets.length == targetSwap.initiatorAssets.length,
                "Provided assets don't match the initial swap setup"
            );
            require(
                responderAssets.length == targetSwap.responderAssets.length,
                "Provided assets don't match the initial swap setup"
            );
            require(
                keccak256(bytes(targetSwap.swapType)) ==
                    keccak256(bytes(swapType)),
                'Incorrect swapType provided'
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
                'Provided swap type is invalid'
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
                'Asset address is incorrect'
            );
            require(
                swapPartyAssets[i].value == actualPartyAssets[i].value,
                'Asset value is incorrect'
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
        require(
            treasuryWalletAddress != address(0),
            'Invalid treasury wallet address'
        );
        require(recipient != address(0), 'Invalid receiver address');
        require(amount > 0, 'Invalid amount');

        uint256 treasuryAmount = (amount * currencyFeeAmount) / 100;
        uint256 recipientAmount = amount - treasuryAmount;

        _safeTransferFrom(
            tokenAddress,
            senderAddress,
            treasuryWalletAddress,
            treasuryAmount
        );
        _safeTransferFrom(
            tokenAddress,
            senderAddress,
            recipient,
            recipientAmount
        );
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

    function getFeeInETH() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, 'Price feed returned invalid value');

        uint256 ethPriceInUsd = uint256(price); // Price feed is already in 8 decimals
        uint256 amountInUsd = platformFeeAmount * 10 ** 8; // Convert USD to same decimals as price feed

        return (amountInUsd * 10 ** 18) / ethPriceInUsd;
    }
}
