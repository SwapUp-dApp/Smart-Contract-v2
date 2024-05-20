const SwapUp = artifacts.require('SwapUp.sol');

module.exports = function (deployer, network, accounts) {
    deployer.deploy(SwapUp, accounts[0], accounts[5], 1, accounts[6], 1, 2)
}
