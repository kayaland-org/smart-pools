// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import '../libraries/SushiswapV2ExpandLibrary.sol';
contract SushiswapV2ExpandLibraryMock {

    function getReserves(address tokenA, address tokenB) public view returns (uint,uint) {
        return SushiswapV2ExpandLibrary.getReserves(tokenA,tokenB);
    }

    function getAmountIn(address inputToken,address outputToken,uint256 amountOut)public view returns(uint256){
       return SushiswapV2ExpandLibrary.getAmountIn(inputToken,outputToken,amountOut);
    }

    function getAmountOut(address inputToken,address outputToken,uint256 amountIn)public view returns(uint256){
        return SushiswapV2ExpandLibrary.getAmountOut(inputToken,outputToken,amountIn);
    }

    function swap(address to,address inputToken,address outputToken,uint256 amountIn,uint256 amountOut) public{
        SushiswapV2ExpandLibrary.swap(to,inputToken,outputToken,amountIn,amountOut);
    }


}
