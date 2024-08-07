// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165Checker.sol';
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
        string status; // PENDING, COMPLETED, REJECTED, CANCELED
        string swapType; // OPEN, PRIVATE
        uint256 platformFee;
        string[] proposalIds;
    }

    mapping(string => Swap) public swaps;
    mapping(string => Swap) public proposals;

    address public treasuryWalletAddress;
    uint256 public platformFeeAmount;
    uint256 public currencyFeeAmount;
    uint256 public currencyFeeAmountWithSubdomen;

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
    event SwapCompleted(
        string swapId,
        address initiator,
        address responder,
        string status
    );
    event CommissionUpdated(string commissionType, uint256 amount);
    event AddressUpdated(string addressType, address newAddress);

    event SwapCanceled(string swapId, address initiator);
    event ProposalCreated(
        string proposalId,
        string openSwapId,
        address proposer
    );

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

    function counterSwap(
        string calldata tradeId,
        string calldata swapType,
        Asset[] memory initiatorAssets,
        Asset[] memory responderAssets
    ) public payable {
        if (swapType.equal('PRIVATE')) {
            Swap storage existingSwap = swaps[tradeId];
            require(
                bytes(existingSwap.swapId).length > 0,
                'A swap with this id does not exist'
            );

            require(
                msg.sender == existingSwap.responderAddress,
                'Only responder is allowed to counter a swap offer'
            );
            require(
                keccak256(bytes(existingSwap.status)) ==
                    keccak256(bytes('PENDING')),
                'Swap is not pending'
            );

            // Swap the roles
            existingSwap.responderAddress = existingSwap.initiatorAddress;
            existingSwap.initiatorAddress = msg.sender;

            // Clear existing assets
            delete existingSwap.initiatorAssets;
            delete existingSwap.responderAssets;

            // Add new assets
            for (uint256 i = 0; i < initiatorAssets.length; i++) {
                existingSwap.initiatorAssets.push(
                    Asset({
                        assetAddress: initiatorAssets[i].assetAddress,
                        value: initiatorAssets[i].value
                    })
                );
            }
            for (uint256 i = 0; i < responderAssets.length; i++) {
                existingSwap.responderAssets.push(
                    Asset({
                        assetAddress: responderAssets[i].assetAddress,
                        value: responderAssets[i].value
                    })
                );
            }

            // Reset approvals
            existingSwap.initiatorApprove = true;
            existingSwap.responderApprove = false;

            emit SwapCountered(
                tradeId,
                existingSwap.initiatorAddress,
                existingSwap.responderAddress
            );
        } else if (swapType.equal('OPEN')) {
            Swap storage existingProposal = proposals[tradeId];
            require(
                bytes(existingProposal.swapId).length > 0,
                'A swap with this id does not exist'
            );

            require(
                msg.sender == existingProposal.responderAddress,
                'Only responder is allowed to counter a swap offer'
            );
            require(
                existingProposal.status.equal('PENDING'),
                'Swap is not pending'
            );

            // Swap the roles
            existingProposal.responderAddress = existingProposal
                .initiatorAddress;
            existingProposal.initiatorAddress = msg.sender;

            // Clear existing assets
            delete existingProposal.initiatorAssets;
            delete existingProposal.responderAssets;

            // Add new assets
            for (uint256 i = 0; i < initiatorAssets.length; i++) {
                existingProposal.initiatorAssets.push(
                    Asset({
                        assetAddress: initiatorAssets[i].assetAddress,
                        value: initiatorAssets[i].value
                    })
                );
            }
            for (uint256 i = 0; i < responderAssets.length; i++) {
                existingProposal.responderAssets.push(
                    Asset({
                        assetAddress: responderAssets[i].assetAddress,
                        value: responderAssets[i].value
                    })
                );
            }

            // Reset approvals
            existingProposal.initiatorApprove = true;
            existingProposal.responderApprove = false;

            emit SwapCountered(
                tradeId,
                existingProposal.initiatorAddress,
                existingProposal.responderAddress
            );
        }
    }

    function createSwap(
        string calldata swapId,
        address responderAddress,
        Asset[] memory initiatorAssets,
        Asset[] memory responderAssets,
        string memory swapType
    ) public payable {
        require(bytes(swapId).length > 0, 'Swap ID is required');
        require(initiatorAssets.length > 0, 'No initiator assets found');
        require(bytes(swapType).length > 0, 'Swap type is missing');
        require(
            swapType.equal('OPEN') || swapType.equal('PRIVATE'),
            'Swap Type is invalid'
        );

        Swap storage newSwap = swaps[swapId];
        require(
            bytes(newSwap.swapId).length == 0,
            'A swap with this id already exists'
        );

        if (swapType.equal('OPEN')) {
            require(
                responderAddress == address(0),
                'Responder address should be zero for open swaps'
            );
            require(
                responderAssets.length == 0,
                'Responder assets should be empty for open swaps'
            );
        } else {
            require(
                responderAddress != address(0),
                'Invalid responder address for private swaps'
            );
            require(
                responderAssets.length > 0,
                'No responder assets found for private swaps'
            );
        }

        // Calculate the equivalent ETH amount of the platform fee using Chainlink price feed
        uint256 ethAmountForPlatformFee = getFeeInETH();

        // Ensure the initiator has provided enough ETH for the platform fee
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
        newSwap.platformFee = 0.00;
        // newSwap.platformFee = ethAmountForPlatformFee;

        for (uint256 i = 0; i < initiatorAssets.length; i++) {
            newSwap.initiatorAssets.push(
                Asset({
                    assetAddress: initiatorAssets[i].assetAddress,
                    value: initiatorAssets[i].value
                })
            );
        }

        if (swapType.equal('PRIVATE')) {
            for (uint256 i = 0; i < responderAssets.length; i++) {
                newSwap.responderAssets.push(
                    Asset({
                        assetAddress: responderAssets[i].assetAddress,
                        value: responderAssets[i].value
                    })
                );
            }
        }

        // payable(treasuryWalletAddress).transfer(msg.value);

        emit SwapCreated(
            swapId,
            newSwap.initiatorAddress,
            newSwap.responderAddress
        );
    }

    function proposeToOpenSwap(
        string calldata openSwapId,
        string calldata proposalId,
        Asset[] memory proposerAssets
    ) public payable {
        Swap storage openSwap = swaps[openSwapId];
        require(bytes(openSwap.swapId).length > 0, 'Open swap does not exist');
        require(
            openSwap.swapType.equal('OPEN'),
            'Swap is not an open market swap'
        );
        require(openSwap.status.equal('PENDING'), 'Open swap is not pending');

        Swap storage newProposal = proposals[proposalId];
        require(
            bytes(newProposal.swapId).length == 0,
            'A proposal with this id already exists'
        );

        uint256 ethAmountForPlatformFee = getFeeInETH();
        require(
            msg.value >= ethAmountForPlatformFee,
            'Insufficient ETH for platform fee'
        );

        // newProposal.swapId = proposalId;
        newProposal.swapId = openSwapId;
        newProposal.initiatorAddress = msg.sender;
        newProposal.responderAddress = openSwap.initiatorAddress;
        newProposal.initiatorApprove = true;
        newProposal.responderApprove = false;
        newProposal.status = 'PENDING';
        newProposal.swapType = 'OPEN';
        newProposal.platformFee = ethAmountForPlatformFee;

        for (uint256 i = 0; i < proposerAssets.length; i++) {
            newProposal.initiatorAssets.push(
                Asset({
                    assetAddress: proposerAssets[i].assetAddress,
                    value: proposerAssets[i].value
                })
            );
        }
        for (uint256 i = 0; i < openSwap.initiatorAssets.length; i++) {
            newProposal.responderAssets.push(
                Asset({
                    assetAddress: openSwap.initiatorAssets[i].assetAddress,
                    value: openSwap.initiatorAssets[i].value
                })
            );
        }

        openSwap.proposalIds.push(proposalId);

        payable(treasuryWalletAddress).transfer(msg.value);

        emit ProposalCreated(proposalId, openSwapId, msg.sender);
    }

    function completeSwap(
        string calldata tradeId,
        string memory swapStatus,
        string memory swapType
    ) public payable {
        if (swapType.equal('OPEN')) {
            Swap storage acceptedProposal = proposals[tradeId];
            require(
                bytes(acceptedProposal.swapId).length > 0,
                'Accepted proposal does not exist'
            );
            string memory swapId = acceptedProposal.swapId;
            Swap storage openSwap = swaps[swapId];
            require(openSwap.swapType.equal('OPEN'), 'This is not OPEN swap');
            require(
                bytes(openSwap.swapId).length > 0,
                'Open Swap does not exist'
            );

            if (!swapStatus.equal('REJECTED')) {
                for (
                    uint256 i = 0;
                    i < acceptedProposal.initiatorAssets.length;
                    i++
                ) {
                    _transferAssets(
                        acceptedProposal.initiatorAddress,
                        openSwap.initiatorAddress,
                        acceptedProposal.initiatorAssets[i].assetAddress,
                        acceptedProposal.initiatorAssets[i].value
                    );
                }
                for (uint256 i = 0; i < openSwap.initiatorAssets.length; i++) {
                    _transferAssets(
                        openSwap.initiatorAddress,
                        acceptedProposal.initiatorAddress,
                        openSwap.initiatorAssets[i].assetAddress,
                        openSwap.initiatorAssets[i].value
                    );
                }
            }

            if (swapStatus.equal('REJECTED')) {
                acceptedProposal.status = 'REJECTED';
            }

            if (swapStatus.equal('COMPLETED')) {
                // Reject all other proposals
                for (uint256 i = 0; i < openSwap.proposalIds.length; i++) {
                    if (!openSwap.proposalIds[i].equal(tradeId)) {
                        proposals[openSwap.proposalIds[i]].status = 'REJECTED';
                    }
                }
                // Update statuses
                openSwap.status = 'COMPLETED';
                acceptedProposal.status = 'COMPLETED';
            }

            // Transfer the platform fee to the treasury wallet
            payable(treasuryWalletAddress).transfer(openSwap.platformFee);

            emit SwapCompleted(
                tradeId,
                openSwap.initiatorAddress,
                openSwap.responderAddress,
                'COMPLETED'
            );
        } else if (swapType.equal('PRIVATE')) {
            Swap storage existingSwap = swaps[tradeId];
            require(
                bytes(existingSwap.swapId).length > 0,
                'A swap with this id does not exist'
            );
            require(
                msg.sender == existingSwap.responderAddress,
                'Only responder is allowed to complete a private swap'
            );
            require(
                existingSwap.status.equal('PENDING'),
                'Swap is not pending'
            );
            require(
                swapStatus.equal('COMPLETED') || swapStatus.equal('REJECTED'),
                'Invalid swap status'
            );

            existingSwap.status = swapStatus;
            if (existingSwap.status.equal('REJECTED')) {
                emit SwapCompleted(
                    tradeId,
                    existingSwap.initiatorAddress,
                    existingSwap.responderAddress,
                    'REJECTED'
                );
                return;
            }

            for (uint256 i = 0; i < existingSwap.initiatorAssets.length; i++) {
                _transferAssets(
                    existingSwap.initiatorAddress,
                    existingSwap.responderAddress,
                    existingSwap.initiatorAssets[i].assetAddress,
                    existingSwap.initiatorAssets[i].value
                );
            }

            for (uint256 i = 0; i < existingSwap.responderAssets.length; i++) {
                _transferAssets(
                    existingSwap.responderAddress,
                    existingSwap.initiatorAddress,
                    existingSwap.responderAssets[i].assetAddress,
                    existingSwap.responderAssets[i].value
                );
            }

            existingSwap.responderApprove = true;

            emit SwapCompleted(
                tradeId,
                existingSwap.initiatorAddress,
                existingSwap.responderAddress,
                'COMPLETED'
            );
        }
    }

    function cancelSwap(
        string calldata swapId,
        string calldata cancelType
    ) public {
        if (cancelType.equal('SWAP')) {
            Swap storage existingSwap = swaps[swapId];
            require(
                bytes(existingSwap.swapId).length > 0,
                'A swap with this id does not exist'
            );
            require(
                existingSwap.status.equal('PENDING'),
                'Swap is not pending'
            );
            require(
                msg.sender == existingSwap.initiatorAddress,
                'Only initiator can cancel the swap'
            );

            existingSwap.status = 'CANCELED';

            // If it's an open market swap, reject all proposals
            if (existingSwap.swapType.equal('OPEN')) {
                for (uint256 i = 0; i < existingSwap.proposalIds.length; i++) {
                    proposals[existingSwap.proposalIds[i]].status = 'REJECTED';
                }
            }

            emit SwapCanceled(swapId, msg.sender);
        } else if (cancelType.equal('PROPOSAL')) {
            Swap storage existingProposal = proposals[swapId];
            require(
                bytes(existingProposal.swapId).length > 0,
                'A proposal with this id does not exist'
            );
            require(
                existingProposal.status.equal('PENDING'),
                'Proposal is not pending'
            );
            require(
                msg.sender == existingProposal.initiatorAddress,
                'Only initiator can cancel the proposal'
            );

            existingProposal.status = 'CANCELED';
            emit SwapCanceled(swapId, msg.sender);
        }
    }

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
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, 'Price feed returned invalid value');

        uint256 ethPriceInUsd = uint256(price); // Price feed is already in 8 decimals
        uint256 amountInUsd = platformFeeAmount * 10 ** 8; // Convert USD to same decimals as price feed

        return (amountInUsd * 10 ** 18) / ethPriceInUsd;
    }
}
