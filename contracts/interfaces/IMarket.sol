// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IMarket {

    function getAmountOut(address fromToken, address toToken,uint amountIn) external view returns (uint amountOut);

    function getAmountIn(address fromToken, address toToken,uint amountOut) external view returns (uint amountIn);

    function getAmountsOut(uint amountIn,address[] calldata path) external view returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut,address[] calldata path) external view returns (uint[] memory amounts);

    function swap(address fromToken,uint amountIn,address toToken,uint amountOut,address to) external;

    function bestSwap(uint amountIn,uint amountOut,address to,address[] calldata path) external;


}
