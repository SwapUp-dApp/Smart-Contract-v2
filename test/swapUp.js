const SwapUp = artifacts.require('SwapUp.sol');

contract('Test', () => {
    it('Should update data', async () => {
        const storage = await SwapUp.new();

        await storage.updateData(10);

        const data = await storage.readData();

        assert(data.toString() === '10')
    })
})
