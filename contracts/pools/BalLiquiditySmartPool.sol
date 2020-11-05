// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "./BasicSmartPool.sol";
import "../interfaces/balancer/IBPool.sol";
import "../other/BMath.sol";

contract BalLiquiditySmartPool is BasicSmartPool{

  using BMath for uint256;

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

  function _getTokens() internal override view returns (address[] memory){
    return _bPool.getCurrentTokens();
  }
  function getTokenWeight(address token) public override view returns(uint256 weight){
    weight=_bPool.getDenormalizedWeight(token);
    return weight;
  }
  function calcTokensForAmount(uint256 amount) external override view returns (address[] memory tokens, uint256[] memory amounts){
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
    address[] memory tokens = _getTokens();
    for (uint256 i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).approve(address(_bPool), uint256(-1));
    }
    emit TokensApproved(msg.sender,address(_bPool),uint256(-1));
  }

  function _joinPool(uint256 amount) internal override ready{
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
    uint256 amountRatio=amount.div(_joinFeeRatio.denominator);
    uint256 userAmount=amountRatio.mul(_joinFeeRatio.denominator-_joinFeeRatio.ratio);
    if(_joinFeeRatio.ratio>0){
      _mint(_controller,amount.sub(userAmount));
    }
    _mint(msg.sender,userAmount);
  }

  function _exitPool(uint256 amount) internal override ready{
    uint256 poolTotal = totalSupply();
    uint256 ratio = amount.bdiv(poolTotal);
    require(ratio != 0,"ratio is 0");
    require(balanceOf(msg.sender)>=amount,"BalLiquiditySmartPool.exitPool: Insufficient amount");
    uint256 amountRatio=amount.div(_exitFeeRatio.denominator);
    uint256 exitAmount=amountRatio.mul(_exitFeeRatio.denominator-_exitFeeRatio.ratio);
    if(_exitFeeRatio.ratio>0){
      transferFrom(msg.sender,_controller,amount.sub(exitAmount));
    }
    transferFrom(msg.sender,address(this),exitAmount);
    _burn(address(this),exitAmount);
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
  }

  function _contains(address _needle, address[] memory _haystack) internal pure returns (bool) {
    for (uint256 i = 0; i < _haystack.length; i++) {
      if (_haystack[i] == _needle) {
        return true;
      }
    }
    return false;
  }

  function bind(
    address tokenAddress,
    uint256 balance,
    uint256 denorm
  ) external onlyTokenBinder denyReentry {
    IERC20 token = IERC20(tokenAddress);
    require(
      token.transferFrom(msg.sender, address(_bPool), balance),
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
        token.transferFrom(msg.sender, address(_bPool), balance.sub(oldBalance)),
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
