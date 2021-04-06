// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../BasicSmartPool.sol";
import "../interfaces/IFundPool.sol";
import "../interfaces/balancer/IBPool.sol";
import "../libraries/MathExpandLibrary.sol";

contract BalLiquiditySmartPool is BasicSmartPool,IFundPool{

  using MathExpandLibrary for uint256;

  IBPool private _bPool;
  address private _publicSwapSetter;
  address private _tokenBinder;

  event LOG_JOIN(address indexed caller, address indexed tokenIn, uint256 tokenAmountIn);
  event LOG_EXIT(address indexed caller, address indexed tokenOut, uint256 tokenAmountOut);
  event PublicSwapSetterChanged(address indexed previousSetter, address indexed newSetter);
  event TokenBinderChanged(address indexed previousTokenBinder, address indexed newTokenBinder);
  event PublicSwapSet(address indexed setter, bool indexed value);
  event SwapFeeSet(address indexed setter, uint256 newFee);

  modifier ready() {
    require(address(_bPool) != address(0), "BalLiquiditySmartPool.ready: not ready");
    _;
  }

  modifier onlyPublicSwapSetter() {
    require(msg.sender == _publicSwapSetter, "BalLiquiditySmartPool.onlyPublicSwapSetter: not public swap setter");
    _;
  }

  modifier onlyTokenBinder() {
    require(msg.sender == _tokenBinder, "BalLiquiditySmartPool.onlyTokenBinder: not token binder");
    _;
  }

  function init(
    address bPool,
    string calldata name,
    string calldata symbol,
    uint256 initialSupply
  ) external {
    require(address(_bPool) == address(0), "BalLiquiditySmartPool.init: already initialised");
    require(bPool != address(0), "BalLiquiditySmartPool.init: bPool cannot be 0x00....000");
    require(initialSupply != 0, "BalLiquiditySmartPool.init: initialSupply can not zero");
    super._init(name,symbol,18);
    _bPool = IBPool(bPool);
    _publicSwapSetter = msg.sender;
    _tokenBinder = msg.sender;
    _mint(msg.sender,initialSupply);
    emit PoolJoined(msg.sender,msg.sender, initialSupply);
  }


  function setPublicSwapSetter(address newPublicSwapSetter) external onlyController denyReentry {
    emit PublicSwapSetterChanged(_publicSwapSetter, newPublicSwapSetter);
    _publicSwapSetter = newPublicSwapSetter;
  }

  function getPublicSwapSetter() external view returns (address) {
    return _publicSwapSetter;
  }

  function setTokenBinder(address newTokenBinder) external onlyController denyReentry {
    emit TokenBinderChanged(_tokenBinder, newTokenBinder);
    _tokenBinder = newTokenBinder;
  }

  function getTokenBinder() external view returns (address) {
    return _tokenBinder;
  }
  function setPublicSwap(bool isPublic) external onlyPublicSwapSetter denyReentry {
    emit PublicSwapSet(msg.sender, isPublic);
    _bPool.setPublicSwap(isPublic);
  }

  function isPublicSwap() external view returns (bool) {
    return _bPool.isPublicSwap();
  }

  function setSwapFee(uint256 swapFee) external onlyController denyReentry {
    emit SwapFeeSet(msg.sender, swapFee);
    _bPool.setSwapFee(swapFee);
  }


  function getSwapFee() external view returns (uint256) {
    return _bPool.getSwapFee();
  }

  function getBPool() external view returns (address) {
    return address(_bPool);
  }

  function getTokens() public override view returns (address[] memory){
    return _bPool.getCurrentTokens();
  }

  function getTokenWeight(address token) public override view returns(uint256 weight){
    weight=_bPool.getDenormalizedWeight(token);
    return weight;
  }

  function calcTokensForAmount(uint256 amount,uint8 direction) external override view returns (address[] memory tokens, uint256[] memory amounts){
    if(direction==1){
      amount=amount.sub(_calcExitFee(amount));
    }
    tokens = _bPool.getCurrentTokens();
    amounts = new uint256[](tokens.length);
    uint256 ratio = amount.bdiv(totalSupply());
    for (uint256 i = 0; i < tokens.length; i++) {
      address token = tokens[i];
      uint256 bal = _bPool.getBalance(token);
      uint256 _amount = ratio.bmul(bal);
      amounts[i] = _amount;
    }
  }

  function approveTokens() public override denyReentry {
    address[] memory tokens = getTokens();
    for (uint256 i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).approve(address(_bPool), uint256(-1));
    }
    emit TokensApproved(address(this),address(_bPool),uint256(-1));
  }

  function joinPool(address to,uint256 amount) external override ready withinCap denyReentry{
    uint256 poolTotal = totalSupply();
    uint256 ratio = amount.bdiv(poolTotal);
    require(ratio != 0,"ratio is 0");
    address[] memory tokens = _bPool.getCurrentTokens();

    for (uint256 i = 0; i < tokens.length; i++) {
      address token = tokens[i];
      uint256 bal = _bPool.getBalance(token);
      uint256 tokenAmountIn = ratio.bmul(bal);
      emit LOG_JOIN(msg.sender, token, tokenAmountIn);
      uint256 tokenWeight = getTokenWeight(token);
      require(
        IERC20(token).balanceOf(address(this))>=tokenAmountIn, "BalLiquiditySmartPool.joinPool: tokenAmountIn exceeds balance"
      );
      _bPool.rebind(token, bal.add(tokenAmountIn), tokenWeight);
    }
    uint256 fee=_calcJoinFee(amount);
    if(_joinFeeRatio.ratio>0){
      _mint(_controller,fee);
    }
    uint256 joinAmount=amount.sub(fee);
    _mint(msg.sender,joinAmount);
    emit PoolJoined(msg.sender,to, amount);
  }

  function exitPool(address from,uint256 amount) external override ready denyReentry{
    require(balanceOf(msg.sender)>=amount,"BalLiquiditySmartPool.exitPool: KToken Insufficient amount");
    uint256 poolTotal = totalSupply();

    uint256 fee=_calcExitFee(amount);
    if(_exitFeeRatio.ratio>0){
      transferFrom(msg.sender,_controller,fee);
    }
    uint256 exitAmount=amount.sub(fee);
    _burn(msg.sender,exitAmount);
    uint256 ratio = exitAmount.bdiv(poolTotal);
    require(ratio != 0,"ratio is 0");
    address[] memory tokens = _bPool.getCurrentTokens();
    for (uint256 i = 0; i < tokens.length; i++) {
      address token = tokens[i];
      uint256 bal = _bPool.getBalance(token);
      uint256 tokenAmountOut = ratio.bmul(bal);
      emit LOG_EXIT(msg.sender, token, tokenAmountOut);
      uint256 tokenWeight = getTokenWeight(token);
      _bPool.rebind(token, bal.sub(tokenAmountOut), tokenWeight);
      require(
        IERC20(token).transfer(msg.sender, tokenAmountOut),
        "BalLiquiditySmartPool.exitPool: transfer failed"
      );
    }
    emit PoolExited(msg.sender,from, exitAmount);
  }

  function bind(
    address tokenAddress,
    uint256 balance,
    uint256 denorm
  ) external onlyTokenBinder denyReentry {
    IERC20 token = IERC20(tokenAddress);
    require(
      token.transferFrom(msg.sender, address(this), balance),
      "BalLiquiditySmartPool.bind: transferFrom failed"
    );
    token.approve(address(_bPool), uint256(-1));
    _bPool.bind(tokenAddress, balance, denorm);
  }

  function rebind(
    address tokenAddress,
    uint256 balance,
    uint256 denorm
  ) external onlyTokenBinder denyReentry {
    IERC20 token = IERC20(tokenAddress);
    _bPool.gulp(tokenAddress);

    uint256 oldBalance = token.balanceOf(address(_bPool));
    if (balance > oldBalance) {
      require(
        token.transferFrom(msg.sender, address(this), balance.sub(oldBalance)),
        "BalLiquiditySmartPool.rebind: transferFrom failed"
      );
      token.approve(address(_bPool), uint256(-1));
    }
    _bPool.rebind(tokenAddress, balance, denorm);
    uint256 tokenBalance = token.balanceOf(address(this));
    if (tokenBalance > 0) {
      require(token.transfer(msg.sender, tokenBalance), "BalLiquiditySmartPool.rebind: transfer failed");
    }
  }

  function unbind(address tokenAddress) external onlyTokenBinder denyReentry {
    IERC20 token = IERC20(tokenAddress);
    _bPool.unbind(tokenAddress);

    uint256 tokenBalance = token.balanceOf(address(this));
    if (tokenBalance > 0) {
      require(token.transfer(msg.sender, tokenBalance), "BalLiquiditySmartPool.unbind: transfer failed");
    }
  }
}
