// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import '../libraries/CurveSwapLibrary.sol';
pragma experimental ABIEncoderV2;
contract  CurveSwapLibraryMock{


    function tokenInfo(uint256 tokenId)public view returns(SynthSwap.TokenInfo memory){
        return CurveSwapLibrary.tokenInfo(tokenId);
    }

    function getSwapIntoAmountOut(address inputToken,address outputToken,uint256 amountIn)public view returns(uint256){
        return CurveSwapLibrary.getSwapIntoAmountOut(inputToken,outputToken,amountIn);
    }

    function getSwapFromAmountOut(address inputToken,address outputToken,uint256 amountIn)public view returns(uint256){
        return CurveSwapLibrary.getSwapFromAmountOut(inputToken,outputToken,amountIn);
    }

    function swapInto(address inputToken,address outputToken,uint256 amountIn) public returns(uint256){
        return CurveSwapLibrary.swapInto(inputToken,outputToken,amountIn,address(this));
    }

    function swapInto(address inputToken,address outputToken,uint256 amountIn,uint256 tokenId) public returns(uint256){
        return CurveSwapLibrary.swapInto(inputToken,outputToken,amountIn,address(this),tokenId);
    }

    function swapFrom(uint256 tokenId,address inputToken,address outputToken,uint256 amountIn) public returns(uint256){
        return CurveSwapLibrary.swapFrom(tokenId,inputToken,outputToken,amountIn,address(this));
    }

}
