pragma solidity ^0.6.8;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {FixedPoint} from "@uniswap/lib/contracts/libraries/FixedPoint.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {
    IUniswapV2Router01
} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

import {ILendingPoolAddressesProvider} from "./aave-protocol/ILendingPoolAddressesProvider.sol";
import {ILendingPool} from "./aave-protocol/ILendingPool.sol";
import {IPriceOracle} from "./aave-protocol/IPriceOracle.sol";

contract ReFi is Ownable {
    //----------------------------------------
    // Type definitions
    //----------------------------------------

    using FixedPoint for *;
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    enum Protocol { Aave }

    struct AaveContracts {
        ILendingPoolAddressesProvider provider;
        ILendingPool lendingPool;
        address lendingPoolCore;
        IPriceOracle priceOracle;
    }

    //----------------------------------------
    // State variables
    //----------------------------------------

    uint112 private constant _MAX_UINT112 = uint112(-1);

    // Used by `_aaveRepay` and should be used as a constant
    // Cannot be declared constant because it is a non-value type
    FixedPoint.uq112x112 private _AAVE_REPAY_EPSILON; // solhint-disable-line var-name-mixedcase

    IUniswapV2Router01 private _uniswapRouter;
    AaveContracts private _aaveContracts;

    //----------------------------------------
    // Constructor
    //----------------------------------------

    constructor() public {
        // Set to 5%
        _AAVE_REPAY_EPSILON = FixedPoint.fraction(1, 20);
    }

    //----------------------------------------
    // External functions
    //----------------------------------------

    /**
     * @notice Set the Uniswap v2 router periphery contract
     * @param uniswapRouter The router contract
     */
    function setUniswapRouter(IUniswapV2Router01 uniswapRouter) external onlyOwner {
        _uniswapRouter = uniswapRouter;
    }

    /**
     * @notice Set the Aave contracts from the Aave `LendingPoolAddressesProvider` provider
     * @param provider The Aave `LendingPoolAddressesProvider`
     */
    function setAaveContracts(ILendingPoolAddressesProvider provider)
        external
        onlyOwner
        nonReentrant
    {
        _aaveContracts = AaveContracts(
            provider,
            ILendingPool(provider.getLendingPool()),
            provider.getLendingPoolCore(),
            IPriceOracle(provider.getPriceOracle())
        );
    }

    //----------------------------------------
    // Internal functions
    //----------------------------------------

    /**
     * @notice Borrow tokens from a protocol
     * @param protocol The protocol to use
     * @param token The token to borrow
     * @param amount The amount of token to borrow
     */
    function _borrow(Protocol protocol, address token, uint amount) internal {
        if (protocol == Protocol.Aave) {
            _aaveBorrow(token, amount);
        } else { // solhint-disable-line no-empty-blocks
            // revert
        }
    }

    /**
     * @notice Repay Aave loan on behalf of sender
     * @param sender The Aave loanee
     * @param reserve The Aave reserve to repay
     * @param currentBorrowBalance The current balance that needs to be repaid
     */
    function _aaveRepay(address sender, address reserve, uint currentBorrowBalance) internal {
        require(currentBorrowBalance <= _MAX_UINT112, "ReFi/overflow");

        // Repaying slightly higher than the borrowed amount is recommended by Aave
        // https://docs.aave.com/developers/developing-on-aave/the-protocol/lendingpool#repay
        uint amount = currentBorrowBalance
            .add(_AAVE_REPAY_EPSILON.mul(uint112(currentBorrowBalance)).decode144());

        IERC20(reserve).safeApprove(_aaveContracts.lendingPoolCore, amount);

        _aaveContracts.lendingPool.repay(reserve, amount, payable(sender));
    }

    /**
     * @notice Borrow an amount of tokens from Aave
     * @notice Assumes enough collateral to borrow the specified amount
     * @param reserve The reserve to borrow from
     * @param amount The amount of tokens to borrow
     */
    function _aaveBorrow(
        address reserve,
        uint amount
    ) internal {
        _aaveContracts.lendingPool.borrow(reserve, amount, 2, 0);
    }

    //----------------------------------------
    // Internal views
    //----------------------------------------

    /**
     * @notice Get the current token borrow balance for a user on a protocol
     * @param protocol The protocol to use
     * @param token The token borrowed
     * @param user The user
     * @return balance The borrow balance
     */
    function _getBorrowBalance(Protocol protocol, address token, address user)
        internal
        view
        returns (uint balance)
    {
        if (protocol == Protocol.Aave) {
            balance = _getAaveBorrowBalance(token, user);
        } else { // solhint-disable-line no-empty-blocks
            // revert
        }
    }

    /**
     * @notice Get the equivalent borrow balance for another token on a protocol
     * @param protocol The protocol to use
     * @param fromToken The token with the current balance
     * @param toToken The token to get an equivalent balance for
     * @param fromBalance The borrow balance of `fromToken`
     * @return toBalance The equivalent borrow balance
     */
    function _getEquivalentBorrowBalance(
        Protocol protocol,
        address fromToken,
        address toToken,
        uint fromBalance
    )
        internal
        view
        returns (uint toBalance)
    {
        if (protocol == Protocol.Aave) {
            toBalance = _getAaveEquivalentBorrowBalance(fromToken, toToken, fromBalance);
        } else { // solhint-disable-line no-empty-blocks
            // revert
        }
    }

    /**
     * @notice Get the current borrow balance of a reserve for a user on Aave
     * @param reserve The Aave reserve
     * @param user The user
     * @return The borrow balance
     */
    function _getAaveBorrowBalance(address reserve, address user)
        internal
        view
        returns (uint)
    {
        (, uint currentBorrowBalance, , , , , , , ,) =
            _aaveContracts.lendingPool.getUserReserveData(reserve, user);
        require(currentBorrowBalance <= _MAX_UINT112, "ReFi/overflow");

        return currentBorrowBalance;
    }

    /**
     * @notice Get the equivalent borrow balance for another Aave reserve
     * @param fromReserve The reserve with the current balance
     * @param toReserve The reserve to get an equivalent balance for
     * @param currentBorrowBalance The borrow balance of `fromReserve`
     * @return The equivalent borrow balance
     */
    function _getAaveEquivalentBorrowBalance(
        address fromReserve,
        address toReserve,
        uint currentBorrowBalance
    )
        internal
        view
        returns (uint)
    {
        uint fromAssetPrice = _aaveContracts.priceOracle.getAssetPrice(fromReserve);
        require(fromAssetPrice <= _MAX_UINT112, "ReFi/overflow");

        uint toAssetPrice = _aaveContracts.priceOracle.getAssetPrice(toReserve);
        require(toAssetPrice <= _MAX_UINT112, "ReFi/overflow");

        uint toBorrowBalance = FixedPoint.encode(uint112(currentBorrowBalance))
            .div(uint112(toAssetPrice))
            .mul(uint112(fromAssetPrice))
            .decode144();

        return toBorrowBalance;
    }

    /**
     * @notice Get the Uniswap pair for two sorted tokens
     * @param token0 The first token in the pair
     * @param token1 The second token in the pair
     * @return The Uniswap pair
     */
    function _getUniswapPair(address token0, address token1)
        internal
        view
        returns (IUniswapV2Pair)
    {
        return IUniswapV2Pair(address(uint(keccak256(abi.encodePacked(
            hex"ff",
            _uniswapRouter.factory(),
            keccak256(abi.encodePacked(token0, token1)),
            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"
        )))));
    }
}
