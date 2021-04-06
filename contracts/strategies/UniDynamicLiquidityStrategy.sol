// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/weth/IWETH.sol";
import "../interfaces/uniswap-v2/IUniswapV2Router02.sol";
import "../interfaces/kaya/ISmartPool.sol";
import "../interfaces/kaya/IController.sol";

import "../libraries/CurveSwapLibrary.sol";
import "../libraries/UniswapV2ExpandLibrary.sol";
import "../libraries/MathExpandLibrary.sol";
import "../libraries/EnumerableExpandSet.sol";
import "../libraries/ERC20Helper.sol";
import "../GovIdentity.sol";
pragma experimental ABIEncoderV2;

contract UniDynamicLiquidityStrategy is GovIdentity {

    using SafeERC20 for IERC20;
    using MathExpandLibrary for uint256;
    using SafeMath for uint256;
    using EnumerableExpandSet for EnumerableExpandSet.AddressSet;

    uint256 P=1e6;

    IController public controller;
    IUniswapV2Router02 constant public route=IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant public WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    EnumerableExpandSet.AddressSet private _tokens;
    EnumerableExpandSet.AddressSet private _pools;

    event AddLiquidity(address indexed from,address indexed pool,uint256 liquidity);
    event RemoveLiquidity(address indexed from,address indexed pool,uint256 liquidity);

    constructor(address _controller)
    public {
        controller = IController(_controller);
    }

    modifier onlyAuthorize() {
        require(msg.sender == getGovernance()
        ||msg.sender==getStrategist()
        ||msg.sender==address(controller), "Strategy.onlyAuthorize: !authorize");
        _;
    }

    receive() external payable {

    }

    function init()external{

    }

    function _vaultInfo() internal view returns (address, address){
        address _vault = controller.vaults(address(this));
        address _token = ISmartPool(_vault).token();
        return (_vault, _token);
    }

    function pools()public view returns(address[] memory ps){
        uint256 length=_pools.length();
        ps=new address[](length);
        for(uint256 i=0;i<length;i++){
            ps[i]=_pools.at(i);
        }
    }

    function _updatePools(address _pool)internal{
        bool isNeedPool=IERC20(_pool).balanceOf(address(this))>0?true:false;
        if(!_pools.contains(_pool)&&isNeedPool){
            _pools.add(_pool);
        }else if(_pools.contains(_pool)&&!isNeedPool){
            _pools.remove(_pool);
        }
    }

    function setUnderlyingTokens(address[] memory _ts)public onlyAuthorize{
        for(uint256 i=0;i<_ts.length;i++){
            if(!_tokens.contains(_ts[i])){
                _tokens.add(_ts[i]);
            }
        }
    }

    function removeUnderlyingTokens(address[] memory _ts)public onlyAuthorize{
        for(uint256 i=0;i<_ts.length;i++){
            if(_tokens.contains(_ts[i])){
                _tokens.remove(_ts[i]);
            }
        }
    }

    function addLiquidity(address _pool,uint256 liquidityExpect,uint256 amount0,uint256 amount1)public onlyAuthorize{
        require(amount0>0&&amount1>0,'Strategy.addLiquidity: Must be greater than 0 amount');
        (address token0,address token1)=UniswapV2ExpandLibrary.tokens(_pool);
        ERC20Helper.safeApprove(token0,address(route),amount0);
        ERC20Helper.safeApprove(token1,address(route),amount1);
        (,,uint256 liquidityActual)=route.addLiquidity(token0,token1,amount0,amount1,0,0,address(this),block.timestamp);
        require(liquidityActual>=liquidityExpect,'Strategy.addLiquidity: Actual quantity is less than the expected quantity');
        _updatePools(_pool);
        emit AddLiquidity(msg.sender,_pool,liquidityActual);
    }

    function removeLiquidity(address _pool,uint256 liquidity)public onlyAuthorize{
        require(liquidity>0,'Strategy.removeLiquidity: Must be greater than 0 liquidity');
        _removeLiquidity(_pool,liquidity,address(this));
        emit RemoveLiquidity(msg.sender,_pool,liquidity);
    }

    function _removeLiquidity(address _pool,uint256 liquidity,address _to)internal returns(uint256 amount0,uint256 amount1){
        if(liquidity>0){
            ERC20Helper.safeApprove(_pool,address(route),liquidity);
            (address token0,address token1)=UniswapV2ExpandLibrary.tokens(_pool);
            (amount0,amount1)=UniswapV2ExpandLibrary.calcLiquidityToTokens(token0,token1,liquidity);
            (amount0,amount1)=route.removeLiquidity(token0,token1,liquidity,amount0,amount1,_to,block.timestamp);
            _updatePools(_pool);
        }
    }

    function swapExactInByUni(address inputToken,address outputToken, uint256 amountIn)public onlyAuthorize returns(uint256 amountOut){
        if(inputToken==WETH||outputToken==WETH){
            return UniswapV2ExpandLibrary.swapExactIn(address(this),inputToken,outputToken,amountIn);
        }else{
            uint256 wethOut=UniswapV2ExpandLibrary.swapExactIn(address(this),inputToken,WETH,amountIn);
            return UniswapV2ExpandLibrary.swapExactIn(address(this),WETH,outputToken,wethOut);
        }
    }

    function swapExactOutByUni(address inputToken,address outputToken, uint256 amountOut)public onlyAuthorize returns(uint256 amountIn){
        if(inputToken==WETH||outputToken==WETH){
            return UniswapV2ExpandLibrary.swapExactOut(address(this),inputToken,outputToken,amountOut);
        }else{
            uint256 wethIn=UniswapV2ExpandLibrary.getAmountIn(WETH,outputToken,amountOut);
            if(IERC20(WETH).balanceOf(address(this))<wethIn){
                UniswapV2ExpandLibrary.swapExactOut(address(this),inputToken,WETH,wethIn);
            }
            return UniswapV2ExpandLibrary.swapExactIn(address(this),WETH,outputToken,wethIn);
        }
    }

    function ethToWeth(uint256 amountIn)public onlyAuthorize{
        IWETH(WETH).deposit{value: amountIn}();
    }

    function swapByCurvePool(address pool,address from,int128 i,int128 j, uint256 amountIn)public onlyAuthorize{
        CurveSwapLibrary.swapByPool(pool,from,i,j,amountIn);
    }

    function withdrawByCurve(uint256 tokenId,uint256 amountOut)public onlyAuthorize{
        CurveSwapLibrary.withdraw(tokenId,amountOut);
    }

    function swapIntoByCurve(address inputToken,address outputToken, uint256 amountIn)public onlyAuthorize returns(uint256){
        return CurveSwapLibrary.swapInto(inputToken,outputToken,amountIn,address(this));
    }

    function swapIntoByCurve(address inputToken,address outputToken, uint256 amountIn,uint256 tokenId)public onlyAuthorize returns(uint256){
        return CurveSwapLibrary.swapInto(inputToken,outputToken,amountIn,address(this),tokenId);
    }

    function swapFromByCurve(uint256 tokenId,address inputToken,address outputToken, uint256 amountIn)public onlyAuthorize returns(uint256){
        return CurveSwapLibrary.swapFrom(tokenId,inputToken,outputToken,amountIn,address(this));
    }

    function tokenInfo(uint256 tokenId)public view returns(SynthSwap.TokenInfo memory){
        return CurveSwapLibrary.tokenInfo(tokenId);
    }


    function deposit(uint256 _amount) external {
        require(msg.sender == address(controller), 'Strategy.deposit: !controller');
        (,address _vaultToken) = _vaultInfo();
        require(_amount > 0, 'Strategy.deposit: token balance is zero');
        IERC20 tokenContract = IERC20(_vaultToken);
        require(tokenContract.balanceOf(msg.sender) >= _amount, 'Strategy.deposit: Insufficient balance');
        tokenContract.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == address(controller), 'Strategy.withdraw: !controller');
        require(_amount > 0, 'Strategy.withdraw: Must be greater than 0 amount');
        require(_amount <= assets(), 'Strategy.withdraw: Must be less than assets');
        (address _vault,address _vaultToken) = _vaultInfo();
        IERC20 tokenContract=IERC20(_vaultToken);
        uint256 cashAmount=tokenContract.balanceOf(address(this));
        if(cashAmount<_amount){
            uint256 diff=_amount.sub(cashAmount);
            _withdrawOfUnderlying(address(this),diff);
            uint256[] memory amounts=extractableUnderlyingNumber(diff);
            uint256 wethAmountOut;
            for(uint256 i=0;i<_tokens.length();i++){
                address token=_tokens.at(i);
                if(token==WETH){
                    wethAmountOut=wethAmountOut.add(amounts[i]);
                }else if(token!=_vaultToken&&amounts[i]>0){
                    wethAmountOut=wethAmountOut.add(UniswapV2ExpandLibrary.swapExactIn(address(this),token,WETH,amounts[i]));
                }
            }
            UniswapV2ExpandLibrary.swapExactIn(address(this),WETH,_vaultToken,wethAmountOut);
        }
        tokenContract.safeTransfer(_vault,_amount);
    }

    function withdrawOfUnderlying(address _to,uint256 _amount)external{
        require(msg.sender == address(controller), 'Strategy.withdrawOfUnderlying: !controller');
        require(_amount > 0, 'Strategy.withdrawOfUnderlying: Must be greater than 0 amount');
        require(_amount <= assets(), 'Strategy.withdrawOfUnderlying: Must be less than assets');
        _withdrawOfUnderlying(_to,_amount);
    }

    function _withdrawOfUnderlying(address _to,uint256 _amount)internal{
        (,address _vaultToken) = _vaultInfo();
        uint256 assets=assets();
        for(uint256 i=_pools.length();i>0;i--){
            address pool=_pools.at(i.sub(1));
            uint256 liquidityBalance=UniswapV2ExpandLibrary.liquidityBalance(pool,address(this));
            uint256 liquidityValue=UniswapV2ExpandLibrary.calcLiquiditySwapToToken(pool,_vaultToken,WETH,liquidityBalance);
            uint256 needAmount=liquidityValue.mul(P).mul(_amount).div(assets).div(P);
            uint256 liquidity=liquidityBalance.bdiv(assets).bmul(needAmount);
            _removeLiquidity(pool,liquidity,_to);
        }
    }

    function withdraw(address _token) external returns (uint256 balance){
        require(msg.sender == address(controller), 'Strategy.withdraw: !controller');
        IERC20 token=IERC20(_token);
        balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(address(controller), balance);
        }
    }

    function withdrawAll() external {
        require(msg.sender == address(controller), 'Strategy.withdrawAll: !controller');
        for(uint256 i=_pools.length();i>0;i--){
            address pool=_pools.at(i.sub(1));
            uint256 liquidity=UniswapV2ExpandLibrary.liquidityBalance(pool,address(this));
            _removeLiquidity(pool,liquidity,address(this));
        }
        (address _vault,address _vaultToken) = _vaultInfo();
        for(uint256 j=0;j<_tokens.length();j++){
            address token=_tokens.at(j);
            uint256 bal=IERC20(token).balanceOf(address(this));
            if(token!=_vaultToken&&token!=WETH&&bal>0){
               UniswapV2ExpandLibrary.swapExactIn(address(this),token,WETH,bal);
            }
        }
        uint256 amountIn = IERC20(WETH).balanceOf(address(this));
        UniswapV2ExpandLibrary.swapExactIn(address(this),WETH,_vaultToken,amountIn);
        IERC20 vaultToken=IERC20(_vaultToken);
        vaultToken.safeTransfer(_vault, vaultToken.balanceOf(address(this)));
    }

    function extractableUnderlyingNumber(uint256 _amount)public view returns(uint256[] memory tokenNumbers){
        (,address _vaultToken) = _vaultInfo();
        uint256 assets=assets();
        tokenNumbers=new uint256[](_tokens.length());
        uint256[] memory tokenTotalNumbers=getTokenNumbers();
        for(uint256 i=0;i<_tokens.length();i++){
            if(tokenTotalNumbers[i]>0){
                address token=_tokens.at(i);
                uint256 ta=tokenValueByIn(token,_vaultToken,tokenTotalNumbers[i]);
                uint256 needVaultAmount=ta.mul(P).mul(_amount).div(assets).div(P);
                tokenNumbers[i]=tokenValueByOut(token,_vaultToken,needVaultAmount);
            }
        }
    }

    function getTokenNumbers()public view returns(uint256[] memory amounts){
        amounts=new uint256[](_tokens.length());
        for(uint256 i=_pools.length();i>0;i--){
            address pool=_pools.at(i.sub(1));
            (address token0,address token1)=UniswapV2ExpandLibrary.tokens(pool);
            (uint256 amount0,uint256 amount1)=liquidityTokenOut(pool);
            uint256 token0Index= _tokens.indexs(token0).sub(1);
            uint256 token1Index= _tokens.indexs(token1).sub(1);
            amounts[token0Index]=amount0.add(amounts[token0Index]);
            amounts[token1Index]=amount1.add(amounts[token1Index]);
        }
        for(uint256 i=0;i<_tokens.length();i++){
            amounts[i]=amounts[i].add(IERC20(_tokens.at(i)).balanceOf(address(this)));
        }
    }

    function getTokens()public view returns(address[] memory ts){
        uint256 length=_tokens.length();
        ts=new address[](length);
        for(uint256 i=0;i<length;i++){
            ts[i]=_tokens.at(i);
        }
    }

    function getWeights()public view returns(uint256[] memory ws){
        uint256 assets=assets();
        (,address _vaultToken) = _vaultInfo();
        ws=new uint256[](_tokens.length());
        uint256[] memory tokenNumbers=getTokenNumbers();
        for(uint256 i=0;i<_tokens.length();i++){
            uint256 ta=tokenValueByIn(_tokens.at(i),_vaultToken,tokenNumbers[i]);
            if(assets!=0){
                ws[i]=ta.mul(1e20).div(assets);
            }
        }
    }

    function assets() public view returns (uint256){
        (,address _vaultToken) = _vaultInfo();
        uint256 total=0;
        for(uint256 i=_pools.length();i>0;i--){
            address pool=_pools.at(i.sub(1));
            uint256 liquidity=UniswapV2ExpandLibrary.liquidityBalance(pool,address(this));
            uint256 liquidityValue=UniswapV2ExpandLibrary.calcLiquiditySwapToToken(pool,_vaultToken,WETH,liquidity);
            total=total.add(liquidityValue);
        }
        total=total.add(available());
        return total;
    }

    function available() public view returns (uint256){
        (,address _vaultToken) = _vaultInfo();
        uint256 total=0;
        uint256 wethBal=0;
        for(uint256 i=0;i<_tokens.length();i++){
            address token=_tokens.at(i);
            uint256 bal=IERC20(token).balanceOf(address(this));
            if(token==WETH){
                wethBal=wethBal.add(bal);
            }else if(token!=_vaultToken&&bal>0){
                wethBal=wethBal.add(UniswapV2ExpandLibrary.getAmountOut(token,WETH,bal));
            }
        }
        if(wethBal>0){
            total=total.add(UniswapV2ExpandLibrary.getAmountOut(WETH,_vaultToken,wethBal));
        }
        total=total.add(IERC20(_vaultToken).balanceOf(address(this)));
        return total;
    }

    function tokenValueByIn(address _fromToken,address _toToken,uint256 _amount)public view returns (uint256){
        if(_amount==0)return _amount;
        if(_fromToken==_toToken){
            return _amount;
        }else if(_fromToken==WETH){
            return UniswapV2ExpandLibrary.getAmountOut(_fromToken,_toToken,_amount);
        }else{
            uint256 wethAmount=UniswapV2ExpandLibrary.getAmountOut(_fromToken,WETH,_amount);
            return UniswapV2ExpandLibrary.getAmountOut(WETH,_toToken,wethAmount);
        }
    }
    function tokenValueByOut(address _fromToken,address _toToken,uint256 _amount)public view returns (uint256){
        if(_amount==0)return _amount;
        if(_fromToken==_toToken){
            return _amount;
        }else if(_fromToken==WETH){
            return UniswapV2ExpandLibrary.getAmountIn(_fromToken,_toToken,_amount);
        }else{
            uint256 wethOut=UniswapV2ExpandLibrary.getAmountIn(_fromToken,WETH,_amount);
            return UniswapV2ExpandLibrary.getAmountIn(_fromToken,WETH,wethOut);
        }
    }


    function liquidityTokenOut(address _pool) public view returns (uint256,uint256){
        (address token0,address token1)=UniswapV2ExpandLibrary.tokens(_pool);
        uint256 liquidity=UniswapV2ExpandLibrary.liquidityBalance(_pool,address(this));
        return UniswapV2ExpandLibrary.calcLiquidityToTokens(token0,token1,liquidity);
    }
}
