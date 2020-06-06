pragma solidity ^0.6.8;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {FixedPoint} from "@uniswap/lib/contracts/libraries/FixedPoint.sol";

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

    function _aaveRepay(AaveContracts memory aaveContracts, address reserve) internal {
        (, uint currentBorrowBalance, , , , , , , ,) =
            aaveContracts.lendingPool.getUserReserveData(reserve, msg.sender);

        require(currentBorrowBalance <= _MAX_UINT112, "ReFi/overflow");

        // Repaying slightly higher than the borrowed amount is recommended by Aave
        // https://docs.aave.com/developers/developing-on-aave/the-protocol/lendingpool#repay
        uint amount = currentBorrowBalance
            .add(_AAVE_REPAY_EPSILON.mul(uint112(currentBorrowBalance)).decode144());

        IERC20(reserve).safeApprove(aaveContracts.lendingPoolCore, amount);

        aaveContracts.lendingPool.repay(reserve, amount, msg.sender);
    }
}
