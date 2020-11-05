// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "../interfaces/ISmartPool.sol";
import "../other/ReentryProtection.sol";
import "../KFToken.sol";
pragma experimental ABIEncoderV2;

abstract contract BasicSmartPool is KFToken, ISmartPool,ReentryProtection{

  address internal _controller;

  uint256 internal _cap;

  struct Fee{
    uint256 ratio;
    uint256 denominator;
  }

  Fee internal _joinFeeRatio=Fee({ratio:0,denominator:1});
  Fee internal _exitFeeRatio=Fee({ratio:0,denominator:1});

  event ControllerChanged(address indexed previousController, address indexed newController);
  event JoinFeeRatioChanged(address indexed setter, uint256 oldRatio, uint256 oldDenominator,uint256 newRatio, uint256 newDenominator);
  event ExitFeeRatioChanged(address indexed setter, uint256 oldRatio, uint256 oldDenominator,uint256 newRatio, uint256 newDenominator);
  event CapChanged(address indexed setter, uint256 oldCap, uint256 newCap);
  event PoolJoined(address indexed sender,address indexed from, uint256 amount);
  event PoolExited(address indexed sender,address indexed from, uint256 amount);
  event TokensApproved(address indexed sender,address indexed to, uint256 amount);

  modifier onlyController() {
    require(msg.sender == _controller, "BasicSmartPool.onlyController: not controller");
    _;
  }
  modifier withinCap() {
    _;
    require(totalSupply() <= _cap, "BasicSmartPool.withinCap: Cap limit reached");
  }

  function _init(string memory name,string memory symbol,uint8 decimals) internal override {
    super._init(name,symbol,decimals);
    emit ControllerChanged(_controller, msg.sender);
    _controller = msg.sender;
  }

  function getController() external override view returns (address){
    return _controller;
  }

  function setController(address controller) external onlyController denyReentry {
    emit ControllerChanged(_controller, controller);
    _controller= controller;
  }

  function getJoinFeeRatio() external override view returns (uint256,uint256){
    return (_joinFeeRatio.ratio,_joinFeeRatio.denominator);
  }

  function setJoinFeeRatio(uint256 ratio,uint256 denominator) external onlyController denyReentry {
    require(ratio>=0&&denominator>0&&ratio<=denominator,"BasicSmartPool.setJoinFeeRatio: joinFeeRatio must be >=0 and denominator>0 and ratio<=denominator");
    emit JoinFeeRatioChanged(msg.sender, _joinFeeRatio.ratio,_joinFeeRatio.denominator, ratio,denominator);
    _joinFeeRatio = Fee({
      ratio:ratio,
      denominator:denominator
    });
  }

  function getExitFeeRatio() external override view returns (uint256,uint256){
    return (_exitFeeRatio.ratio,_exitFeeRatio.denominator);
  }

  function setExitFeeRatio(uint256 ratio,uint256 denominator) external onlyController denyReentry {
    require(ratio>=0&&denominator>0&&ratio<=denominator,"BasicSmartPoolsetExitFeeRatio: exitFeeRatio must be >=0 and denominator>0 and ratio<=denominator");
    emit ExitFeeRatioChanged(msg.sender, _exitFeeRatio.ratio,_exitFeeRatio.denominator, ratio,denominator);
    _exitFeeRatio = Fee({
      ratio:ratio,
      denominator:denominator
    });
  }

  function setCap(uint256 cap) external onlyController denyReentry {
    emit CapChanged(msg.sender, _cap, cap);
    _cap = cap;
  }

  function getCap() external view returns (uint256) {
    return _cap;
  }

  function approveTokens() public virtual denyReentry{

  }

  function getTokens() external override view returns (address[] memory){
    return _getTokens();
  }

  function _getTokens()internal  virtual view returns (address[] memory tokens){

  }
  function getTokenWeight(address token) public virtual view returns(uint256 weight){

  }
  function joinPool(address user,uint256 amount) external override withinCap denyReentry{
    _joinPool(amount);
    emit PoolJoined(msg.sender,user, amount);
  }

  function exitPool(address user,uint256 amount) external override denyReentry{
    _exitPool(amount);
    emit PoolExited(msg.sender,user, amount);
  }

  function _joinPool(uint256 amount) internal virtual{

  }

  function _exitPool(uint256 amount) internal virtual{

  }
}
