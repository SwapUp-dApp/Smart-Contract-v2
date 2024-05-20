const SwapUp = artifacts.require('SwapUp');
const MockERC20 = artifacts.require('MockERC20'); // Ensure you have a MockERC20 contract.
const TestNFT = artifacts.require('TestNFT');


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

    it("Swap up contract deployment", async () => {
        assert.notEqual(contract.address, null);
    });

    it("Basic token transfer", async () => {
        const tx = await contract.transferTokens(sender, recipient, token.address, tokenAmount, { from: sender });
        assert.equal(tx.receipt.status, true);
    });

    it("NFT mint ID exists", async () => {
        const nextNftIndex = await nft.nextTokenId();

        assert(nextNftIndex.toNumber() > 0, "NFT did not mint")
    })

    it("Comission setter and getter", async () => {
        const platformFeeAmount = await contract.platformFeeAmount();

        assert.equal(platformFeeAmount, 1, 'Incorrect initial platform fee');

        await contract.setPlatformFeeAmount(10);

        const platformFeeAmountUpd = await contract.platformFeeAmount();

        assert.equal(platformFeeAmountUpd.toNumber(), 10, 'Incorrect updated platform fee');

        await contract.setPlatformFeeAmount(1);
    })

    // SWAP Sender's 1st NFT into RECPIENT 1st NFT (0 -> 4 | 4 -> 0)
    it("Swap single NFT between user A and user B", async () => {
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

    it("Swap multiple NFTs between user A and user B", async () => {
        await nft.setApprovalForAll(contract.address, true, { from: sender });

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

    it("Swap single NFT from user A to user B | and crypto currency from user B to user A", async () => {
        await nft.setApprovalForAll(contract.address, true, { from: recipient });

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

        const recipientBalance = await token.balanceOf(recipient);
        const senderBalance = await token.balanceOf(sender);
        const treasuryWalletBalance = await token.balanceOf(accounts[5]);

        assert.equal(recipientBalance, '19800000000000000000', 'recipient balance after swap is incorrect')
        assert.equal(senderBalance, '990000000000000000000', 'sender balance after swap is incorrect')
        assert.equal(treasuryWalletBalance, '200000000000000000', 'treasury wallet balance after swap is incorrect')

        const ownerOf1NFTUpd = await nft.ownerOf(0);

        assert.equal(ownerOf1NFTUpd, sender, 'invalid owner of 1st NFT after transfer');
    });

    it("Swap 10 NFT from user A to user B | and crypto currency from user B to user A", async () => {
        const userA = accounts[3];
        const userB = accounts[4];
        const treasuryWallet = accounts[5];

        // mint 20 NFTS per user A with IDS: 8-27 including
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);
        await nft.mintTo(userA);


        await nft.setApprovalForAll(contract.address, true, { from: userA });
        await nft.setApprovalForAll(contract.address, true, { from: userB });

        const ownerOf8NFT = await nft.ownerOf(8);
        const ownerOf27NFT = await nft.ownerOf(27);

        assert.equal(ownerOf8NFT, userA, 'invalid owner of NFT with ID 8');
        assert.equal(ownerOf27NFT, userA, 'invalid owner of NFT with ID 27');

        await token.mint(userB, '1000000000000000000000');
        await token.approve(contract.address, '1000000000000000000000', { from: userB });

        const balance = await token.balanceOf(userB);

        assert.equal(balance.toString(), '1000000000000000000000', 'Incorrect balance value after minting token for sender adress');

        const nftAssets = [8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27].map(n => ({ assetAddress: nft.address, value: n }));
        // const nftAssetsB = [28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,].map(n => ({ assetAddress: nft.address, value: n }));
        const currencyAssets = [1,2,3,4,5].map(() => ({ assetAddress: token.address, value: '1000000000000000000' }));

        const userABalance0 = await token.balanceOf(userA);
        
        assert.equal(userABalance0.toString(), "0", "the user A balance is already exists");

        const tx = await contract.approveAndSwap('testID-5', userB, nftAssets, currencyAssets, 'PRIVATE', { from: userA });

        assert.equal(tx.receipt.status, true, 'status of transaction is false');


        const swapTx = await contract.approveAndSwap('testID-5', userB, nftAssets, currencyAssets, 'PRIVATE', { from: userB });

        assert.equal(swapTx.receipt.status, true, 'status of swap tx is false');

        const ownerOf8NFTUpd = await nft.ownerOf(8);
        const ownerOf27NFTUpd = await nft.ownerOf(27);

        assert.equal(ownerOf8NFTUpd, userB, 'invalid owner of NFT with ID 8');
        assert.equal(ownerOf27NFTUpd, userB, 'invalid owner of NFT with ID 27');

        const userABalanceValue = await token.balanceOf(userA);
        const treasuryWalletBalance = await token.balanceOf(treasuryWallet);
        const userBBalance = await token.balanceOf(userB);
        
        assert.equal(userABalanceValue.toString(), "4950000000000000000", "the user A balance is invalid");
        assert.equal(treasuryWalletBalance.toString(), "250000000000000000", "Treasury wallet balance is invalid");
        assert.equal(userBBalance.toString(), "995000000000000000000", "Treasury wallet balance is invalid");
    });
});