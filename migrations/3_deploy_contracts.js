const MockERC20 = artifacts.require('MockERC20.sol');

module.exports = function (deployer) {
    deployer.deploy(MockERC20, '10000000000000000000000')
}