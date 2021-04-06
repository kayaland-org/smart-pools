// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./other/ReentryProtection.sol";
import "./KToken.sol";
abstract contract BasicSmartPool is KToken,ReentryProtection{

  using SafeERC20 for IERC20;

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
    _joinFeeRatio = Fee({
      ratio:0,
      denominator:1000
    });
    _exitFeeRatio = Fee({
      ratio:0,
      denominator:1000
    });
  }

  function updateName(string memory name,string memory symbol,uint8 decimals)external onlyController denyReentry{
     super._init(name,symbol,decimals);
  }
  function getController() external view returns (address){
    return _controller;
  }

  function setController(address controller) external onlyController denyReentry {
    emit ControllerChanged(_controller, controller);
    _controller= controller;
  }

  function getJoinFeeRatio() external view returns (uint256,uint256){
    return (_joinFeeRatio.ratio,_joinFeeRatio.denominator);
  }

  function setJoinFeeRatio(uint256 ratio,uint256 denominator) external onlyController denyReentry {
    require(ratio<=denominator,
      "BasicSmartPool.setJoinFeeRatio: joinFeeRatio must be >=0 and denominator>0 and ratio<=denominator");
    emit JoinFeeRatioChanged(msg.sender, _joinFeeRatio.ratio,_joinFeeRatio.denominator, ratio,denominator);
    _joinFeeRatio = Fee({
      ratio:ratio,
      denominator:denominator
    });
  }

  function getExitFeeRatio() external view returns (uint256,uint256){
    return (_exitFeeRatio.ratio,_exitFeeRatio.denominator);
  }

  function setExitFeeRatio(uint256 ratio,uint256 denominator) external onlyController denyReentry {
    require(ratio<=denominator,
      "BasicSmartPoolsetExitFeeRatio: exitFeeRatio must be >=0 and denominator>0 and ratio<=denominator");
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

  function _calcJoinFee(uint256 amount)internal view returns(uint256){
    uint256 amountRatio=amount.div(_joinFeeRatio.denominator);
    return amountRatio.mul(_joinFeeRatio.ratio);
  }

  function _calcExitFee(uint256 amount)internal view returns(uint256){
    uint256 amountRatio=amount.div(_exitFeeRatio.denominator);
    return amountRatio.mul(_exitFeeRatio.ratio);
  }

}
