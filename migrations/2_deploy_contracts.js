const TestNFT = artifacts.require('TestNFT');

module.exports = function (deployer, network, accounts) {
    const ownerAddress = accounts[0]; // Assuming the deployer's address is the owner
    deployer.deploy(TestNFT, ownerAddress);
}