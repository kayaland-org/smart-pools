// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import '../interfaces/uniswap-v2/IUniswapV2Pair.sol';

library UniswapV2ExpandLibrary{
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address constant internal factory=address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0,address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    function pairFor(address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

    function getReserves(address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function quote(uint amountA,uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    function getAmountIn(address inputToken,address outputToken,uint256 amountOut)internal view returns(uint256 amountIn){
        (uint reserveIn, uint reserveOut) = getReserves(inputToken, outputToken);
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    function getAmountOut(address inputToken,address outputToken,uint256 amountIn)internal view returns(uint256 amountOut){
        (uint reserveIn, uint reserveOut) = getReserves(inputToken, outputToken);
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function getAmountsOut(uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            amounts[i + 1] = getAmountOut(path[i], path[i + 1],amounts[i]);
        }
    }

    function getAmountsIn(uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            amounts[i - 1] = getAmountIn(path[i - 1], path[i],amounts[i]);
        }
    }

    function calcLiquidityToTokens(address tokenA,address tokenB,uint256 liquidity) internal view returns (uint256 amountA, uint256 amountB) {
        if(liquidity==0){
            return (0,0);
        }
        address pair=pairFor(tokenA,tokenB);
        uint256 balanceA = IERC20(tokenA).balanceOf(address(pair));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(pair));
        uint256 totalSupply=IERC20(pair).totalSupply();
        amountA = liquidity.mul(balanceA).div(totalSupply);
        amountB = liquidity.mul(balanceB).div(totalSupply);
        return(amountA,amountB);
    }

    function tokens(address _pair)internal view returns(address,address){
        IUniswapV2Pair pair=IUniswapV2Pair(_pair);
        return (pair.token0(),pair.token1());
    }

    function liquidityBalance(address _pair,address _owner)internal view returns(uint256){
        return IUniswapV2Pair(_pair).balanceOf(_owner);
    }

    function calcLiquiditySwapToToken(address _pair,address _target,address bridgeToken,uint256 liquidity) internal view returns (uint256) {
        if(liquidity==0){
            return 0;
        }
        IUniswapV2Pair pair=IUniswapV2Pair(_pair);
        (address tokenA,address tokenB)=(pair.token0(),pair.token1());
        (uint256 amountA,uint256 amountB)=calcLiquidityToTokens(tokenA,tokenB,liquidity);
        if(tokenA!=bridgeToken&&tokenA!=_target){
            amountA=getAmountOut(tokenA,bridgeToken,amountA);
        }
        if(tokenB!=bridgeToken&&tokenB!=_target){
            amountB=getAmountOut(tokenB,bridgeToken,amountB);
        }
        uint256 tokenAOut=getAmountOut(bridgeToken,_target,amountA);
        uint256 tokenBToOut=getAmountOut(bridgeToken,_target,amountB);
        return tokenAOut.add(tokenBToOut);
    }

    function swap(address to,address inputToken,address outputToken,uint256 amountIn,uint256 amountOut) internal{
        IUniswapV2Pair pair=IUniswapV2Pair(pairFor(inputToken,outputToken));
        IERC20(inputToken).safeTransfer(address(pair), amountIn);
        (address token0,) = sortTokens(inputToken, outputToken);
        (uint amount0Out, uint amount1Out) = inputToken == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
        pair.swap(amount0Out,amount1Out, to, new bytes(0));
    }

    function swapExactIn(address to,address inputToken,address outputToken, uint256 amountIn) internal returns(uint256 amountOut){
        amountOut=amountIn;
        if (amountIn > 0 && inputToken != outputToken) {
            amountOut = getAmountOut(inputToken, outputToken, amountIn);
            swap(to, inputToken, outputToken, amountIn, amountOut);
        }
    }

    function swapExactOut(address to,address inputToken,address outputToken,uint256 amountOut) internal returns(uint256 amountIn){
        amountIn=amountOut;
        if (amountOut > 0 && inputToken != outputToken) {
            amountIn = getAmountIn(inputToken, outputToken, amountOut);
            swap(to, inputToken, outputToken, amountIn, amountOut);
        }
    }

}
