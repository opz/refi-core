const { expect } = require("chai");
const { constants, utils } = require("ethers");
const { createFixtureLoader } = require("ethereum-waffle");
const { deployMockContract } = require("@ethereum-waffle/mock-contract");

const { refiFixture, mockAaveFixture } = require("./fixtures");

const UniswapV2Router01 = require("@uniswap/v2-periphery/build/UniswapV2Router01.json");

describe("ReFi", () => {
  const provider = waffle.provider;
  const [wallet] = provider.getWallets();
  const loadFixture = createFixtureLoader(provider, [wallet]);

  let refi;

  beforeEach(async () => {
    ({ refi } = await loadFixture(refiFixture));
  });

  describe("All protocol functions", () => {
    const protocolUnknown = 0;
    const protocolAave = 1;

    let daiAddr;
    let wethAddr;

    beforeEach(async () => {
      ({ daiAddr, wethAddr } = await loadFixture(mockAaveFixture(refi)));
    });

    describe("_getEquivalentBorrowBalance", () => {
      const borrowBalance = utils.parseEther("200");

      it("should get the equivalent borrow balance for Aave", async () => {
        const equivalentBorrowBalance = await refi.getEquivalentBorrowBalance(
          protocolAave,
          daiAddr,
          wethAddr,
          borrowBalance
        );
        expect(equivalentBorrowBalance).to.eq(utils.parseEther("1"));
      });

      it("should revert if passed an unknown protocol", async () => {
        const promise = refi.getEquivalentBorrowBalance(
          protocolUnknown,
          daiAddr,
          wethAddr,
          borrowBalance
        );
        await expect(promise).to.be.revertedWith("ReFi/unknown_protocol");
      });
    });
  });

  describe("Aave functions", () => {
    let daiAddr;
    let wethAddr;

    beforeEach(async () => {
      ({ daiAddr, wethAddr } = await loadFixture(mockAaveFixture(refi)));
    });

    describe("_getAaveBorrowBalance", () => {
      it("should get the borrow balance of a user for a reserve", async () => {
        const borrowBalance = utils.parseEther("1");
        expect(await refi.getAaveBorrowBalance(daiAddr, wallet.address)).to.eq(borrowBalance);
      });
    });

    describe("_getAaveEquivalentBorrowBalance", () => {
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
