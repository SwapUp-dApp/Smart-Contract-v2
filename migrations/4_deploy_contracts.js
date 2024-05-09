const TestNFT1155 = artifacts.require("TestNFT1155");

module.exports = function(deployer, network, accounts) {
    const ownerAddress = accounts[0]; // Assuming the deployer's address is the owner
    const baseMetadataURI = "https://api.example.com/token/";
    deployer.deploy(TestNFT1155, baseMetadataURI, ownerAddress);
};