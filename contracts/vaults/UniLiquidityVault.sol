// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../interfaces/uniswap-v2/IUniswapV2Router02.sol";
import "../interfaces/uniswap-v2/IUniswapV2Factory.sol";
import "../libraries/UniswapV2ExpandLibrary.sol";

import "../BasicSmartPool.sol";
import "../libraries/MathExpandLibrary.sol";
import "../libraries/ERC20Helper.sol";

contract UniLiquidityVault is BasicSmartPool{

  using MathExpandLibrary for uint256;

  IUniswapV2Router02 constant public route=IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public pair;

  address public tokenA;
  address public tokenB;

  address constant public USDT=address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
  address constant public WETH=address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  uint256 constant public MAX_USDT_FEE=200000000;

  bool private isInit=false;

  bool public isExtractFee=false;

  event WithdrawFee(address indexed to,uint256 amount);
  event RemoveLiquidity(address indexed from,uint256 liquidity);
  event PoolJoined(address indexed sender,address indexed to, uint256 amount);
  event PoolExited(address indexed sender,address indexed from, uint256 amount);
  event Invest(address indexed sender,uint256 total);

  function init(
    address _tokenA,
    address _tokenB,
    string memory _name,
    string memory _symbol)
  public{
    require(!isInit, "UniLiquidityVault.init: already initialised");
    isInit=true;
    super._init(_name,_symbol,6);
    tokenA=_tokenA;
    tokenB=_tokenB;
    pair=UniswapV2ExpandLibrary.pairFor(tokenA,tokenB);
    ERC20Helper.safeApprove(address(pair),address(route),uint256(-1));
  }

  function joinPool(uint256 amount) external {
    IERC20 usdt=IERC20(USDT);
    require(usdt.balanceOf(msg.sender)>=amount&&amount>0,"UniLiquidityVault.joinPool: Insufficient balance");
    uint256 fee=_calcJoinFee(amount);
    uint256 joinAmount=amount.sub(fee);
    uint256 shares=calcUsdtToKf(joinAmount);
    usdt.safeTransferFrom(msg.sender, address(this), joinAmount);
    if(_joinFeeRatio.ratio>0){
      usdt.safeTransferFrom(msg.sender, _controller, fee);
    }
    _mint(msg.sender,shares);
    emit PoolJoined(msg.sender,msg.sender,shares);
  }

  function exitPool(uint256 amount) external{
    require(balanceOf(msg.sender)>=amount&&amount>0,"UniLiquidityVault.exitPool: Insufficient balance");
    uint256 usdtAmount = calcKfToUsdt(amount);
    // Check cash balance
    IERC20 usdt=IERC20(USDT);
    uint256 cashBal = usdt.balanceOf(address(this));
    if (cashBal < usdtAmount) {
      uint256 diff = usdtAmount.sub(cashBal);
      uint256 liquidity= calcLiquidityDesiredByRomove(diff);
      (uint256 amountA,uint256 amountB)=_removeLiquidity(liquidity);
      _swapToToken(amountA,amountB);
      usdtAmount=usdt.balanceOf(address(this));
    }
    uint256 fee=_calcExitFee(usdtAmount);
    uint256 exitAmount=usdtAmount.sub(fee);

    usdt.safeTransfer(msg.sender,exitAmount);
    if(_exitFeeRatio.ratio>0){
      usdt.safeTransfer(_controller,fee);
    }
    _burn(msg.sender,amount);
    emit PoolExited(msg.sender,msg.sender,amount);
  }

  function removeAll() external onlyController denyReentry{
    uint256 liquidity=lpBal();
    _removeLiquidity(liquidity);
    _swapToToken(IERC20(tokenA).balanceOf(address(this)),IERC20(tokenB).balanceOf(address(this)));
  }

  function withdrawFee(uint256 amount)external onlyController denyReentry{
    require(amount<=MAX_USDT_FEE,"UniLiquidityVault.withdrawFee: Must be less than 200 usdt");
    require(isExtractFee,"UniLiquidityVault.withdrawFee: Already extracted");
    uint256 totalBal=IERC20(USDT).balanceOf(address(this));
    require(amount<=totalBal,"UniLiquidityVault.withdrawFee: Insufficient balance");
    IERC20(USDT).safeTransfer(_controller,amount);
    isExtractFee=false;
    emit WithdrawFee(_controller,amount);
  }

  function invest()external onlyController denyReentry{
    uint256 usdtAmount=IERC20(USDT).balanceOf(address(this));
    require(usdtAmount>0,'UniLiquidityVault.invest: Must be greater than 0 usdt');
    UniswapV2ExpandLibrary.swapExactIn(address(this),USDT,WETH,usdtAmount);

    uint256 liquidityDesired=calcLiquidityDesiredByAdd(IERC20(WETH).balanceOf(address(this)));
    (uint256 amountA,uint256 amountB)=calcSwapBeforeDesiredAmount(liquidityDesired);
    UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,tokenA,amountA);
    UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,tokenB,amountB);
    (amountA,amountB)=(IERC20(tokenA).balanceOf(address(this)),IERC20(tokenB).balanceOf(address(this)));
    ERC20Helper.safeApprove(tokenA,address(route),amountA);
    ERC20Helper.safeApprove(tokenB,address(route),amountB);
    (,,liquidityDesired)=route.addLiquidity(tokenA,tokenB,amountA,amountB,0,0,address(this),block.timestamp);
    _swapToToken(IERC20(tokenA).balanceOf(address(this)),IERC20(tokenB).balanceOf(address(this)));
    isExtractFee=true;
    emit Invest(msg.sender,usdtAmount);
  }


  function calcKfToUsdt(uint256 amount) public view returns(uint256){
    if(totalSupply()==0){
      return amount;
    }else{
      return (totalValue().mul(amount)).div(totalSupply());
    }
  }

  function calcUsdtToKf(uint256 amount) public view returns(uint256){
    uint256 shares=0;
    if(totalSupply()==0){
      shares=amount;
    }else{
      shares=amount.mul(totalSupply()).div(totalValue());
    }
    return shares;
  }

  function calcLiquidityDesiredByAdd(uint256 amount) public view returns(uint256){
    uint256 balance0 = IERC20(tokenA).balanceOf(pair);
    uint256 totalSupply=IERC20(pair).totalSupply();
    uint256 totalSupply2=totalSupply.mul(totalSupply);
    uint256 x=uint256(1000).mul(amount).mul(totalSupply2);
    uint256 y=uint256(997).mul(balance0);
    uint256 n=((totalSupply2.add(x.div(y))).sqrt().sub(totalSupply)).mul(997).div(1000);
    return n;
  }

  function calcLiquidityDesiredByRomove(uint256 amount)public view returns(uint256){
    uint256 lpBal=lpBal();
    uint256 lpValue=lpValue();
    if(lpBal==0){
      return 0;
    }else{
      return lpBal.bdiv(lpValue).bmul(amount);
    }
  }

  function calcSwapAfterDesiredAmount(uint256 liquidityDesired) public view returns (uint256,uint256) {
    uint256 balance0 = IERC20(tokenA).balanceOf(pair);
    uint256 balance1 = IERC20(tokenB).balanceOf(pair);
    uint256 totalSupply=IERC20(pair).totalSupply();
    uint256 liquidityDesiredBal0=liquidityDesired.mul(balance0);
    uint256 liquidityDesiredBal1=liquidityDesired.mul(balance1);
    uint256 liquidityDesiredPower=liquidityDesired.mul(liquidityDesired);
    uint256 totalSupplyPower=totalSupply.mul(totalSupply);
    if(tokenA==WETH){
      uint256 addAmount=liquidityDesiredPower.mul(balance0).mul(1000).div(997);
      uint256 amountA=totalSupply.mul(liquidityDesiredBal0).add(addAmount).div(totalSupplyPower);
      uint256 amountB=liquidityDesiredBal1.div(totalSupply.add(liquidityDesired));
      return (amountA,amountB);
    }else if(tokenB==WETH){
      uint256 amountA=liquidityDesiredBal0.div(totalSupply.add(liquidityDesired));
      uint256 addAmount=liquidityDesiredPower.mul(balance1).mul(1000).div(997);
      uint256 amountB=totalSupply.mul(liquidityDesiredBal1).add(addAmount).div(totalSupplyPower);
      return (amountA,amountB);
    }else{
      return calcSwapBeforeDesiredAmount(liquidityDesired);
    }
  }

  function calcSwapBeforeDesiredAmount(uint256 liquidity) public view returns (uint256 amountA, uint256 amountB) {
    if(liquidity==0){
      return (0,0);
    }
    uint256 balance0 = IERC20(tokenA).balanceOf(address(pair));
    uint256 balance1 = IERC20(tokenB).balanceOf(address(pair));
    uint256 totalSupply=IERC20(pair).totalSupply();
    amountA = liquidity.mul(balance0).div(totalSupply);
    amountB = liquidity.mul(balance1).div(totalSupply);
    return(amountA,amountB);
  }

  function totalValue()public view returns(uint256){
    return IERC20(USDT).balanceOf(address(this)).add(lpValue());
  }

  function lpBal()public view returns(uint256){
    return IERC20(pair).balanceOf(address(this));
  }

  function lpValue()public view returns(uint256){
    uint256 liquidity=lpBal();
    if(liquidity==0){
      return 0;
    }
    (uint256 amountA,uint256 amountB)=calcSwapBeforeDesiredAmount(liquidity);
    if(tokenA!=WETH&&tokenA!=USDT){
      amountA=UniswapV2ExpandLibrary.getAmountOut(tokenA,WETH,amountA);
    }
    if(tokenB!=WETH&&tokenB!=USDT){
      amountB=UniswapV2ExpandLibrary.getAmountOut(tokenB,WETH,amountB);
    }
    uint256 tokenAToUsdt=UniswapV2ExpandLibrary.getAmountOut(WETH,USDT,amountA);
    uint256 tokenBToUsdt=UniswapV2ExpandLibrary.getAmountOut(WETH,USDT,amountB);
    return tokenAToUsdt.add(tokenBToUsdt);
  }

  function _removeLiquidity(uint256 liquidity) internal returns(uint256,uint256){
    (uint256 amountA,uint256 amountB)=calcSwapBeforeDesiredAmount(liquidity);
    if(liquidity>0){
      (amountA,amountB)=route.removeLiquidity(tokenA,tokenB,liquidity,amountA,amountB,address(this),block.timestamp);
      emit RemoveLiquidity(msg.sender,liquidity);
    }
    return (amountA,amountB);
  }


  function _swapToToken(uint256 tokenAIn,uint256 tokenBIn)internal{
    if(tokenA!=WETH&&tokenA!=USDT){
      UniswapV2ExpandLibrary.swapExactIn(address(this),tokenA,WETH,tokenAIn);
    }
    if(tokenB!=WETH&&tokenB!=USDT){
      UniswapV2ExpandLibrary.swapExactIn(address(this),tokenB,WETH,tokenBIn);
    }
    UniswapV2ExpandLibrary.swapExactIn(address(this),WETH,USDT,IERC20(WETH).balanceOf(address(this)));
  }
}