pragma solidity ^0.6.8;

interface IPriceOracle {
    function getAssetPrice(address _asset) external view returns (uint256);
}
