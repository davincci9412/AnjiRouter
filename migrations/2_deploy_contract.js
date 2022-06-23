const AnjiRouter = artifacts.require('AnjiRouter');

const factoryAddress = "0xb7926c0430afb07aa7defde6da862ae0bde767bc";
const WBNBAddress = "0xae13d989dac2f0debff460ac112a837c89baa7cd";
const BUSDAddress = "0x78867bbeef44f2326bf8ddd1941a4439382ef2a7";
// const pancakeRouter = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3";

// const factoryAddress = "0xca143ce32fe78f1f7019d7d551a6402fc5350c73";
// const WBNBAddress = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";

module.exports = function (deployer, network) {
  deployer.then(async () => {
    if (network == 'testnet' || network == 'bsc') {
      const router = await deployer.deploy(AnjiRouter, factoryAddress, WBNBAddress, BUSDAddress);
      console.log('==router: ', router.address);
    }
  });
};
