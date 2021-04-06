// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import '../libraries/UniswapV2ExpandLibrary.sol';
contract UniswapV2ExpandLibraryMock {

    function pairFor(address tokenA, address tokenB) public pure returns (address){
        return UniswapV2ExpandLibrary.pairFor(tokenA,tokenB);
    }

    function getReserves(address tokenA, address tokenB) public view returns (uint,uint) {
        return UniswapV2ExpandLibrary.getReserves(tokenA,tokenB);
    }

    function getAmountIn(address inputToken,address outputToken,uint256 amountOut)public view returns(uint256){
       return UniswapV2ExpandLibrary.getAmountIn(inputToken,outputToken,amountOut);
    }

    function getAmountOut(address inputToken,address outputToken,uint256 amountIn)public view returns(uint256){
        return UniswapV2ExpandLibrary.getAmountOut(inputToken,outputToken,amountIn);
    }

    function swap(address to,address inputToken,address outputToken,uint256 amountIn,uint256 amountOut) public{
        UniswapV2ExpandLibrary.swap(to,inputToken,outputToken,amountIn,amountOut);
    }


}
