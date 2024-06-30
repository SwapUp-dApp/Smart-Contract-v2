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
import '@openzeppelin/contracts/utils/Strings.sol';
import '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';


contract SwapUp is EIP712, Ownable {
    using ERC165Checker for address;
    using Strings for string;

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
        string status; // PENDING, COMPLETED, REJECTED, (COUNTER will be treated as PENDING for simplicity)
        string swapType; // OPEN, PRIVATE
        uint256 platformFee;
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
    event SwapCountered(string swapId, address initiator, address responder);
    event SwapCompleted(string swapId, address initiator, address responder, string status);

    event CommissionUpdated(string commissionType, uint256 amount);
    event AddressUpdated(string addressType, address newAddress);

    // 
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

    //create a new swap and save the state. deposit the platform fee
    function createSwap(
        string calldata swapId,
        address responderAddress,
        Asset[] memory initiatorAssets,
        Asset[] memory responderAssets,
        string memory swapType
    ) public payable {
        //Create a new swap and verify it does not exist
        Swap storage newSwap = swaps[swapId];
        require(bytes(newSwap.swapId).length == 0, 'A swap with this id already exists');
        
        require(responderAddress != address(0), 'Invalid responder address');
        require(initiatorAssets.length > 0, 'No initiator assets found');
        require(responderAssets.length > 0, 'No responder assets found');

        require(bytes(swapType).length > 0, 'Swap type is missing');
        require(swapType.equal('OPEN') || swapType.equal('PRIVATE'), "Swap Type is invalid");

        // Calculate the equivalent ETH amount of the platform fee using Chainlink price feed
        uint256 ethAmountForPlatformFee = getFeeInETH();
        
        // Ensure both parties have provided enough ETH for the platform fee
        require(
            msg.value >= ethAmountForPlatformFee,
            'Insufficient ETH for platform fee'
        );

        newSwap.swapId = swapId;
        newSwap.initiatorAddress = msg.sender;
        newSwap.responderAddress = responderAddress;
        newSwap.initiatorApprove = true;
        newSwap.responderApprove = false;
        newSwap.status = 'PENDING';
        newSwap.swapType = swapType;
        newSwap.platformFee = ethAmountForPlatformFee;
       
        for (uint i = 0; i < initiatorAssets.length; i++) {
            newSwap.initiatorAssets.push(
                Asset({
                    assetAddress: initiatorAssets[i].assetAddress,
                    value: initiatorAssets[i].value
                })
            );
        }
        for (uint i = 0; i < responderAssets.length; i++) {
            newSwap.responderAssets.push(
                Asset({
                    assetAddress: responderAssets[i].assetAddress,
                    value: responderAssets[i].value
                })
            );
        }
        
        // TODO: Transfer platform fee from responder to the contract at the end when the function call is complete
        payable(treasuryWalletAddress).transfer(msg.value);

        emit SwapCreated(
            swapId,
            newSwap.initiatorAddress,
            newSwap.responderAddress
        );
    }
    // Counter the swap offer. 
    function counterSwap(
        string calldata swapId,
        Asset[] memory initiatorAssets,
        Asset[] memory responderAssets        
    ) public payable {
        //Fetch an existing swap and verify it contains data
        Swap storage existingSwap = swaps[swapId];
        require(bytes(existingSwap.swapId).length > 0, 'A swap with this id does not exist');

        require(
            msg.sender == existingSwap.responderAddress,
            'Only responder is allowed to counter a swap offer'
        );
        require(
            keccak256(bytes(existingSwap.status)) ==
                keccak256(bytes('PENDING')),
            'Swap is not pending'
        );
        
        //change the swap parties for this swap
        existingSwap.responderAddress = existingSwap.initiatorAddress;
        existingSwap.initiatorAddress = msg.sender;
        for (uint i = 0; i < existingSwap.initiatorAssets.length; i++){
            existingSwap.initiatorAssets.pop();
        }
        for (uint i = 0; i < existingSwap.responderAssets.length; i++){
            existingSwap.responderAssets.pop();
        }
        for (uint i = 0; i < initiatorAssets.length; i++) {
            existingSwap.initiatorAssets.push(
                Asset({
                    assetAddress: initiatorAssets[i].assetAddress,
                    value: initiatorAssets[i].value
                })
            );
        }
        for (uint i = 0; i < responderAssets.length; i++) {
            existingSwap.responderAssets.push(
                Asset({
                    assetAddress: responderAssets[i].assetAddress,
                    value: responderAssets[i].value
                })
            );
        }

        emit SwapCountered(
            swapId,
            existingSwap.initiatorAddress,
            existingSwap.responderAddress
        );
    }
    //complete the swap offer, either as accept or reject
    function completeSwap(
        string calldata swapId,       
        Asset[] memory initiatorAssets,
        Asset[] memory responderAssets,        
        string memory swapStatus
    ) public payable {
        //Fetch an existing swap and verify it contains data
        Swap storage existingSwap = swaps[swapId];
        require(bytes(existingSwap.swapId).length > 0, 'A swap with this id does not exist');

        require(
            msg.sender == existingSwap.responderAddress,
            'Only responder is allowed to counter a swap offer'
        );
        require(
            keccak256(bytes(existingSwap.status)) ==
                keccak256(bytes('PENDING')),
            'Swap is not pending'
        );

        require(swapStatus.equal('COMPLETED') || swapStatus.equal('REJECTED'), 'Invalid swap status');
        
        existingSwap.status = swapStatus;
        if(existingSwap.status.equal('REJECTED')) {
            emit SwapCompleted(
                swapId,
                existingSwap.initiatorAddress,
                existingSwap.responderAddress,
                'REJECTED'
            );
            return;
        }

        // _validateAssetsBeforeTransfer(
        //     existingSwap.initiatorAssets,
        //     initiatorAssets
        // );
        // _validateAssetsBeforeTransfer(
        //     existingSwap.responderAssets,
        //     responderAssets
        // );

        for (uint i = 0; i < existingSwap.initiatorAssets.length; i++) {
            _transferAssets(
                existingSwap.initiatorAddress,
                existingSwap.responderAddress,
                existingSwap.initiatorAssets[i].assetAddress,
                existingSwap.initiatorAssets[i].value
            );
        }

        for (uint i = 0; i < existingSwap.responderAssets.length; i++) {
            _transferAssets(
                existingSwap.responderAddress,
                existingSwap.initiatorAddress,
                existingSwap.responderAssets[i].assetAddress,
                existingSwap.responderAssets[i].value
            );
        }

        existingSwap.responderApprove = true;       

        emit SwapCompleted(
            swapId,
            existingSwap.initiatorAddress,
            existingSwap.responderAddress,
            'COMPLETED'
        );
    }

    // function _validateAssetsBeforeTransfer(
    //     Asset[] memory swapPartyAssets,
    //     Asset[] memory actualPartyAssets
    // ) private pure {
    //     require(swapPartyAssets.length > 0, 'No assets provided');
    //     require(actualPartyAssets.length > 0, 'No assets provided');
    //     require(
    //         actualPartyAssets.length == swapPartyAssets.length,
    //         'Invalid assets provided'
    //     );

    //     for (uint i = 0; i < actualPartyAssets.length; i++) {
    //         require(
    //             swapPartyAssets[i].assetAddress ==
    //                 actualPartyAssets[i].assetAddress,
    //             'Asset address is incorrect'
    //         );
    //         require(
    //             swapPartyAssets[i].value == actualPartyAssets[i].value,
    //             'Asset value is incorrect'
    //         );
    //     }
    // }

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