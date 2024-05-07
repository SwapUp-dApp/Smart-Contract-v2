const SwapUp = artifacts.require('SwapUp');
const MockERC20 = artifacts.require('MockERC20'); // Ensure you have a MockERC20 contract.

contract("test block", (accounts) => {
    let contract;
    let token;
    const sender = accounts[1]; // Using a different account as sender
    const recipient = accounts[2];
    const tokenAmount = web3.utils.toBN(10000000);

    before(async () => {
        contract = await SwapUp.deployed();
        token = await MockERC20.deployed();

        // Setup: allocate tokens to sender
        await token.mint(sender, tokenAmount);

        // Setup: approve the SwapUp contract to spend tokens on behalf of sender
        // await token.approve(contract.address, tokenAmount, {from: sender});
    });

    it("deploys", async () => {
        assert.notEqual(contract.address, null);
    });

    it("test transaction", async () => {
        const isTransactionSuccess = await contract.transferTokens(sender, recipient, token.address, tokenAmount, {from: sender});
        assert.equal(isTransactionSuccess.receipt.status, true);
    });
});