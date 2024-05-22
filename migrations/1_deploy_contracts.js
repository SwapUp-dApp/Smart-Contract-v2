const SwapUp = artifacts.require('SwapUp.sol');
const MockChainLinkFeed = artifacts.require('MockChainLinkFeed.sol');

module.exports = function (deployer, network, accounts) {
  if (network === 'test') {
    return deployer.deploy(MockChainLinkFeed).then(() => {
      return deployer.deploy(
        SwapUp,
        accounts[0],
        accounts[5],
        1,
        1,
        2,
        MockChainLinkFeed.address,
      );
    });
  } else {
    let owner,
      treasuryWallet,
      platformFeeAmount,
      currencyFeeAmount,
      currencyFeeAmountWithSubdomen,
      priceFeedAddress;

    switch (network) {
      case 'baseSepoliaTestnet':
        owner = accounts[0];
        treasuryWallet = '0xd2F84D63FE2762B18B8d6058Bc6A31113989068B';
        platformFeeAmount = 1;
        currencyFeeAmount = 1;
        currencyFeeAmountWithSubdomen = 2;
        priceFeedAddress = '0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1';
        break;
      case 'sepoliaTestnet':
        owner = accounts[0];
        treasuryWallet = '0xd2F84D63FE2762B18B8d6058Bc6A31113989068B';
        platformFeeAmount = 1;
        currencyFeeAmount = 1;
        currencyFeeAmountWithSubdomen = 2;
        priceFeedAddress = '0x694AA1769357215DE4FAC081bf1f309aDC325306';
        break;
      case 'polygonAmoyTestnet':
        owner = accounts[0];
        treasuryWallet = '0xd2F84D63FE2762B18B8d6058Bc6A31113989068B';
        platformFeeAmount = 1;
        currencyFeeAmount = 1;
        currencyFeeAmountWithSubdomen = 2;
        priceFeedAddress = '0xF0d50568e3A7e8259E16663972b11910F89BD8e7';
        break;
      default:
        owner = accounts[0];
        treasuryWallet = accounts[4];
        platformFeeAmount = 1;
        currencyFeeAmount = 1;
        currencyFeeAmountWithSubdomen = 2;
        priceFeedAddress = 'price feed';
        break;
    }

    deployer.deploy(
      SwapUp,
      owner,
      treasuryWallet,
      platformFeeAmount,
      currencyFeeAmount,
      currencyFeeAmountWithSubdomen,
      priceFeedAddress,
    );
  }
};
