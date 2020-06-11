const { expect } = require("chai");
const { constants, utils } = require("ethers");
const { createFixtureLoader } = require("ethereum-waffle");
const { deployMockContract } = require("@ethereum-waffle/mock-contract");

const { refiFixture } = require("./fixtures");

const UniswapV2Router01 = require("@uniswap/v2-periphery/build/UniswapV2Router01.json");
const LendingPoolAddressesProvider = require("../artifacts/ILendingPoolAddressesProvider.json");
const LendingPool = require("../artifacts/ILendingPool.json");
const PriceOracle = require("../artifacts/IPriceOracle.json");

describe("ReFi", () => {
  const provider = waffle.provider;
  const [wallet] = provider.getWallets();
  const loadFixture = createFixtureLoader(provider, [wallet]);

  let refi;

  beforeEach(async () => {
    ({ refi } = await loadFixture(refiFixture));
  });

  describe("Aave functions", () => {
    const daiAddr = utils.getAddress("0x6b175474e89094c44da98b954eedeac495271d0f");
    const wethAddr = utils.getAddress("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");

    let lendingPool;
    let priceOracle
    let provider;

    beforeEach(async () => {
      lendingPool = await deployMockContract(wallet, LendingPool.abi);
      priceOracle = await deployMockContract(wallet, PriceOracle.abi);
      provider = await deployMockContract(wallet, LendingPoolAddressesProvider.abi);
      await provider.mock.getLendingPool.returns(lendingPool.address);
      await provider.mock.getLendingPoolCore.returns(constants.AddressZero);
      await provider.mock.getPriceOracle.returns(priceOracle.address);

      await refi.setAaveContracts(provider.address);
    });

    describe("_getAaveBorrowBalance", () => {
      const borrowBalance = utils.parseEther("1");
      beforeEach(async () => {
        await lendingPool
          .mock
          .getUserReserveData
          .returns(0, borrowBalance, 0, 0, 0, 0, 0, 0, 0, 0);
      });

      it("should get the borrow balance of a user for a reserve", async () => {
        expect(await refi.getAaveBorrowBalance(daiAddr, wallet.address)).to.eq(borrowBalance);
      });
    });

    describe("_getAaveEquivalentBorrowBalance", () => {
      beforeEach(async () => {
        await priceOracle.mock.getAssetPrice.withArgs(daiAddr).returns(utils.parseEther("1"));
        await priceOracle.mock.getAssetPrice.withArgs(wethAddr).returns(utils.parseEther("200"));
      });

      it("should get the equivalent borrow balance of another reserve", async () => {
        const currentBorrowBalance = utils.parseEther("200");
        const equivalentBalance = await refi.getAaveEquivalentBorrowBalance(
          daiAddr,
          wethAddr,
          currentBorrowBalance
        );

        expect(equivalentBalance).to.eq(utils.parseEther("1"));
      });
    });
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