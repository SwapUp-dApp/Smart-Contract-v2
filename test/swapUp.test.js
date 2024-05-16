const SwapUp = artifacts.require('SwapUp');
const MockERC20 = artifacts.require('MockERC20'); // Ensure you have a MockERC20 contract.
const TestNFT = artifacts.require('TestNFT');
const { expectRevert } = require('@openzeppelin/test-helpers');


contract("test block", (accounts) => {
    let contract;
    let token;
    let nft;
    const sender = accounts[1]; // Using a different account as sender
    const recipient = accounts[2];
    const tokenAmount = '10000000000000000000';

    before(async () => {
        contract = await SwapUp.deployed();
        token = await MockERC20.deployed();
        nft = await TestNFT.deployed();

        // Setup: allocate tokens to sender
        await token.mint(sender, tokenAmount);

        // INITIAL NFT IDs per sender: 0-3, per recipient: 4-7.
        await nft.mintTo(sender);
        await nft.mintTo(sender);
        await nft.mintTo(sender);
        await nft.mintTo(sender);

        await nft.mintTo(recipient);
        await nft.mintTo(recipient);
        await nft.mintTo(recipient);
        await nft.mintTo(recipient);

        // Setup: approve the SwapUp contract to spend tokens on behalf of sender
        await token.approve(contract.address, tokenAmount, {from: sender});

        await nft.setApprovalForAll(contract.address, true);

    });

    it("deploys", async () => {
        assert.notEqual(contract.address, null);
    });

    it("test token transfer", async () => {
        const isTransactionSuccess = await contract.transferTokens(sender, recipient, token.address, tokenAmount, {from: sender});
        assert.equal(isTransactionSuccess.receipt.status, true);
    });

    it("test nft is minted", async () => {
        const nextNftIndex = await nft.nextTokenId();

        assert(nextNftIndex.toNumber() > 0, "NFT did not mint")
    })

    // SWAP Sender's 1st NFT into RECPIENT 1st NFT (0 -> 4 | 4 -> 0)
    it("swap single NFT between user A and user B", async () => {
        await nft.approve(contract.address, 0, { from: sender });
        await nft.approve(contract.address, 4, { from: recipient });

        const ownerOf1NFT = await nft.ownerOf(0);
        const ownerOf5NFT = await nft.ownerOf(4);

        assert.equal(ownerOf1NFT, sender, 'invalid owner of 1st NFT');
        assert.equal(ownerOf5NFT, recipient, 'invalid owner of 2nd NFT');

        const tx = await contract.approveAndSwap('testID-1', recipient, [{ assetAddress: nft.address, value: 0 }], [{ assetAddress: nft.address, value: 4}], 'PRIVATE', { from: sender });

        assert.equal(tx.receipt.status, true, 'status of transaction is false');

        const swapTx = await contract.approveAndSwap('testID-1', recipient, [{ assetAddress: nft.address, value: 0 }], [{ assetAddress: nft.address, value: 4}], 'PRIVATE', { from: recipient });

        assert.equal(swapTx.receipt.status, true, 'status of swap tx is false');

        const ownerOf1NFTUpd = await nft.ownerOf(0);
        const ownerOf5NFTUpd = await nft.ownerOf(4);

        assert.equal(ownerOf1NFTUpd, recipient, 'invalid owner of 1st NFT after transfer');
        assert.equal(ownerOf5NFTUpd, sender, 'invalid owner of 2nd NFT after transfer');
    });

    it("swap multiple NFTs between user A and user B", async () => {
        await nft.approve(contract.address, 1, { from: sender });
        await nft.approve(contract.address, 2, { from: sender });
        await nft.approve(contract.address, 5, { from: recipient });
        await nft.approve(contract.address, 6, { from: recipient });

        const ownerOf2NFT = await nft.ownerOf(1);
        const ownerOf3NFT = await nft.ownerOf(2);
        const ownerOf6NFT = await nft.ownerOf(5);
        const ownerOf7NFT = await nft.ownerOf(6);

        assert.equal(ownerOf2NFT, sender, 'invalid owner of 2nd NFT');
        assert.equal(ownerOf3NFT, sender, 'invalid owner of 2nd NFT');
        assert.equal(ownerOf6NFT, recipient, 'invalid owner of 1st NFT');
        assert.equal(ownerOf7NFT, recipient, 'invalid owner of 2nd NFT');

        const tx = await contract.approveAndSwap('testID-2', sender, [{ assetAddress: nft.address, value: 0 }, { assetAddress: nft.address, value: 2 }], [{ assetAddress: nft.address, value: 1}, { assetAddress: nft.address, value: 3 }], 'PRIVATE', { from: recipient });

        assert.equal(tx.receipt.status, true, 'status of transaction is false');

        const swapTx = await contract.approveAndSwap('testID-', sender, [{ assetAddress: nft.address, value: 0 }, { assetAddress: nft.address, value: 2 }], [{ assetAddress: nft.address, value: 1}, { assetAddress: nft.address, value: 3 }], 'PRIVATE', { from: sender });

        assert.equal(swapTx.receipt.status, true, 'status of swap tx is false');

        const ownerOf2NFTUpd = await nft.ownerOf(1);
        const ownerOf3NFTUpd = await nft.ownerOf(2);
        const ownerOf6NFTUpd = await nft.ownerOf(5);
        const ownerOf7NFTUpd = await nft.ownerOf(6);

        assert.equal(ownerOf2NFTUpd, sender, 'invalid owner of 2nd NFT');
        assert.equal(ownerOf3NFTUpd, sender, 'invalid owner of 2nd NFT');
        assert.equal(ownerOf6NFTUpd, recipient, 'invalid owner of 1st NFT');
        assert.equal(ownerOf7NFTUpd, recipient, 'invalid owner of 2nd NFT');
    });

    it("swap single NFT from user A to user B | and crypto currency from user B to user A", async () => {
        await nft.approve(contract.address, 0, { from: recipient });

        const ownerOf1NFT = await nft.ownerOf(0);

        await token.mint(sender, '1000000000000000000000');
        await token.approve(contract.address, '1000000000000000000000', { from: sender });

        const balance = await token.balanceOf(sender);

        assert.equal(ownerOf1NFT, recipient, 'invalid owner of 1st NFT');
        assert.equal(balance.toString(), '1000000000000000000000', 'Incorrect balance value after minting token for sender adress');

        const tx = await contract.approveAndSwap('testID-4', sender, [{ assetAddress: nft.address, value: 0 }], [{ assetAddress: token.address, value: '10000000000000000000'}], 'PRIVATE', { from: recipient });

        assert.equal(tx.receipt.status, true, 'status of transaction is false');


        const swapTx = await contract.approveAndSwap('testID-4', sender, [{ assetAddress: nft.address, value: 0 }], [{ assetAddress: token.address, value: '10000000000000000000'}], 'PRIVATE', { from: sender });

        assert.equal(swapTx.receipt.status, true, 'status of swap tx is false');

        const ownerOf1NFTUpd = await nft.ownerOf(0);

        assert.equal(ownerOf1NFTUpd, sender, 'invalid owner of 1st NFT after transfer');
    });
});