const { expect } = require("chai");
const { utils } = require("ethers");
const { createFixtureLoader } = require("ethereum-waffle");
const { deployMockContract } = require("@ethereum-waffle/mock-contract");

const { refiFixture } = require("./fixtures");

const UniswapV2Router01 = require("@uniswap/v2-periphery/build/UniswapV2Router01.json");

describe("ReFi", () => {
  const provider = waffle.provider;
  const [wallet] = provider.getWallets();
  const loadFixture = createFixtureLoader(provider, [wallet]);

  let refi;

  beforeEach(async () => {
    ({ refi } = await loadFixture(refiFixture));
  });

  describe("_getUniswapPair", () => {
    const factory = utils.getAddress("0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f");
    const daiAddr = utils.getAddress("0x6b175474e89094c44da98b954eedeac495271d0f");
    const wethAddr = utils.getAddress("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
    const pairAddr = utils.getAddress("0xa478c2975ab1ea89e8196811f51a7b7ade33eb11");

    let uniswapRouter;

    beforeEach(async () => {
      uniswapRouter = await deployMockContract(wallet, UniswapV2Router01.abi);
      await uniswapRouter.mock.factory.returns(factory);
      await refi.setUniswapRouter(uniswapRouter.address);
    });

    it("should return the correct pair when the tokens are in order", async () => {
      expect(await refi.getUniswapPair(daiAddr, wethAddr)).to.eq(pairAddr);
    });

    it("should return the incorrect pair when the tokens are not in order", async () => {
      expect(await refi.getUniswapPair(wethAddr, daiAddr)).to.not.eq(pairAddr);
    });
  });
});
