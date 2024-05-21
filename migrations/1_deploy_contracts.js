const SwapUp = artifacts.require('SwapUp.sol');
const MockChainLinkFeed = artifacts.require('MockChainLinkFeed.sol');

module.exports = function (deployer, network, accounts) {
    deployer.deploy(MockChainLinkFeed).then(() => {
        return deployer.deploy(SwapUp, accounts[0], accounts[5], 1, 1, 2, MockChainLinkFeed.address);
    })
}

// module.exports = function (deployer, network, accounts) {
//     deployer.deploy(SwapUp, '0xd2F84D63FE2762B18B8d6058Bc6A31113989068B', '0x0Cc6B9c297E3A1696146Fc8dafD94CDC1384834E', 1, 1, 2, '0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1');
// }
