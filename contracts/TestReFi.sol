pragma solidity ^0.6.8;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import {ReFi} from "./ReFi.sol";

contract TestReFi is ReFi {
    function getUniswapPair(address token0, address token1)
        external
        view
        returns (IUniswapV2Pair)
    {
        return _getUniswapPair(token0, token1);
    }
}
