const SwapUp = artifacts.require('SwapUp');
const MockERC20 = artifacts.require('MockERC20'); // Ensure you have a MockERC20 contract.
const TestNFT = artifacts.require('TestNFT');

contract("test block", (accounts) => {
    let contract;
    let token;
    let nft;
    const sender = accounts[1]; // Using a different account as sender
    const recipient = accounts[2];
    const tokenAmount = web3.utils.toBN(10000000);

    before(async () => {
        contract = await SwapUp.deployed();
        token = await MockERC20.deployed();
        nft = await TestNFT.deployed();

        // Setup: allocate tokens to sender
        await token.mint(sender, tokenAmount);

        // Setup: approve the SwapUp contract to spend tokens on behalf of sender
        await token.approve(contract.address, tokenAmount, {from: sender});
    });

    it("deploys", async () => {
        assert.notEqual(contract.address, null);
    });

    it("test token transfer", async () => {
        const isTransactionSuccess = await contract.transferTokens(sender, recipient, token.address, tokenAmount, {from: sender});
        assert.equal(isTransactionSuccess.receipt.status, true);
    });

    // it("nft swap - test transaction", async () => {

    //     const txn = await debug(contract.transferNFT(sender, recipient, nft.address, 0, { from: sender }));

    //     assert.equal(txn.receipt.status, true);
    // })
});