const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { assert } = require('chai');

const AnjiRouter = artifacts.require('AnjiRouter');
const MockBUSD = artifacts.require('MockBUSD');
const MockSAFU = artifacts.require('MockSAFU');

const minter = "0xc81377f9435011848cbA29892365d1CEE71a54d4";
const factoryAddress= "0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc";
const WBNBAddress = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";

contract('AnjiRouter', ([]) => {

  it('swapExactTokensForTokensSupportingFeeOnTransferTokens', async () => {
    const mockBusd = await MockBUSD.deployed();
    const mockSafu = await MockSAFU.deployed();
    
    const router = await AnjiRouter.deployed();

    mockBusd.approve(router.address, "1000000000000000000000000000000");
    mockSafu.approve(router.address, "1000000000000000000000000000000");

    router.addLiquidity(
      mockBusd.address,
      mockSafu.address,
      "10000000000000000000000",
      "1000000000000000000000000",
      "0",
      "0",
      minter,
      Math.floor(Date.now().getTime() / 1000) + 60 * 10
    );

    const deadline = `0x${(Math.floor(new Date().getTime() / 1000) + 400).toString(16)}`
    const result = await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        "100000000000000000000",
        "0",
        [mockBusd.address, mockSafu.address],
        minter,
        deadline,
        { from: minter }
    );

    console.log(result);
    assert.equal(factoryAddress, router.factory());
  });

});
