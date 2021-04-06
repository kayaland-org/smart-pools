// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../interfaces/curve/SynthSwap.sol";
import "../interfaces/curve/ICurveFi.sol";
import "./ERC20Helper.sol";
library CurveSwapLibrary{

    SynthSwap constant internal synthSwap=SynthSwap(0x58A3c68e2D3aAf316239c003779F71aCb870Ee47);
//    address constant public curve_seth_pool=address(0xc5424B857f758E906013F3555Dad202e4bdB4567);
//    address constant public seth=address(0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb);

    function tokenInfo(uint256 tokenId)internal view returns(SynthSwap.TokenInfo memory){
        return synthSwap.token_info(tokenId);
    }

    function getSwapIntoAmountOut(address inputToken,address outputToken,uint256 amountIn)internal view returns(uint256){
        return synthSwap.get_swap_into_synth_amount(inputToken,outputToken,amountIn);
    }

    function getSwapFromAmountOut(address inputToken,address outputToken,uint256 amountIn)internal view returns(uint256){
        return synthSwap.get_swap_from_synth_amount(inputToken,outputToken,amountIn);
    }

    function swapInto(address inputToken,address outputToken,uint256 amountIn,address to) internal returns(uint256){
        uint256 amountOut=getSwapIntoAmountOut(inputToken,outputToken,amountIn);
        ERC20Helper.safeApprove(inputToken,address(synthSwap),amountIn);
        return synthSwap.swap_into_synth(inputToken,outputToken,amountIn,amountOut,to);
    }

    function swapInto(address inputToken,address outputToken,uint256 amountIn,address to,uint256 tokenId) internal returns(uint256){
        uint256 amountOut=getSwapIntoAmountOut(inputToken,outputToken,amountIn);
        ERC20Helper.safeApprove(inputToken,address(synthSwap),amountIn);
        return synthSwap.swap_into_synth(inputToken,outputToken,amountIn,amountOut,to,tokenId);
    }

    function swapFrom(uint256 tokenId,address inputToken,address outputToken,uint256 amountIn,address to) internal returns(uint256){
        uint256 amountOut=getSwapFromAmountOut(inputToken,outputToken,amountIn);
        ERC20Helper.safeApprove(inputToken,address(synthSwap),amountIn);
        return synthSwap.swap_from_synth(tokenId,outputToken,amountIn,amountOut,to);
    }

    function swapByPool(address pool,address from,int128 i,int128 j, uint256 amountIn)internal returns(uint256){
        ERC20Helper.safeApprove(from,pool,amountIn);
        return ICurveFi(pool).exchange(i, j, amountIn, 0);
    }

    function withdraw(uint256 tokenId, uint256 amountOut)internal{
        synthSwap.withdraw(tokenId,amountOut);
    }
}
