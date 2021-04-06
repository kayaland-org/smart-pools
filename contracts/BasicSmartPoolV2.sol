// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/utils/Strings.sol";
import "./storage/SmartPoolStorage.sol";
import "./libraries/MathExpandLibrary.sol";
import "./GovIdentity.sol";
import "./KToken.sol";
pragma experimental ABIEncoderV2;
abstract contract BasicSmartPoolV2 is KToken,GovIdentity{

  using MathExpandLibrary for uint256;

  event ControllerChanged(address indexed previousController, address indexed newController);
  event ChargeFee(SmartPoolStorage.FeeType ft,uint256 outstandingFee);
  event CapChanged(address indexed setter, uint256 oldCap, uint256 newCap);
  event FeeChanged(address indexed setter, uint256 oldRatio, uint256 oldDenominator, uint256 newRatio, uint256 newDenominator);

  modifier onlyController() {
    require(msg.sender == getController(), "BasicSmartPoolV2.onlyController: not controller");
    _;
  }

  modifier withinCap() {
    _;
    require(totalSupply() <= getCap(), "BasicSmartPoolV2.withinCap: Cap limit reached");
  }

  function _init(string memory name,string memory symbol,uint8 decimals) internal override {
    super._init(name,symbol,decimals);
    _build();
  }

  function updateName(string memory name,string memory symbol)external onlyGovernance{
     super._init(name,symbol,decimals());
  }

  function getCap() public view returns (uint256){
    return SmartPoolStorage.load().cap;
  }

  function setCap(uint256 cap) external onlyGovernance {
    emit CapChanged(msg.sender, getCap(), cap);
    SmartPoolStorage.load().cap= cap;
  }

  function getController() public view returns (address){
    return SmartPoolStorage.load().controller;
  }

  function setController(address controller) public onlyGovernance {
    emit ControllerChanged(getController(), controller);
    SmartPoolStorage.load().controller= controller;
  }

  function setFee(SmartPoolStorage.FeeType ft,uint256 ratio,uint256 denominator,uint256 minLine)public onlyGovernance{
    require(ratio<=denominator,"BasicSmartPoolV2.setFee: ratio<=denominator");
    SmartPoolStorage.Fee storage fee=SmartPoolStorage.load().fees[ft];
    fee.ratio=ratio;
    fee.denominator=denominator;
    fee.minLine=minLine;
    fee.lastTimestamp=block.timestamp;
    emit FeeChanged(msg.sender, fee.ratio,fee.denominator, ratio,denominator);
  }

  function _updateAvgNet(address investor,uint256 newShare,uint256 newNet)internal{
    uint256 oldShare=balanceOf(investor);
    uint256 oldNet=SmartPoolStorage.load().nets[investor];
    uint256 total=oldShare.add(newShare);
    if(total!=0){
      uint256 nextNet=oldNet.mul(oldShare).add(newNet.mul(newShare)).div(total);
      SmartPoolStorage.load().nets[investor]=nextNet;
    }
  }

  function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
    uint256 newNet=SmartPoolStorage.load().nets[sender];
    _updateAvgNet(recipient,amount,newNet);
    super._transfer(sender,recipient,amount);
    if(balanceOf(sender)==0){
      SmartPoolStorage.load().nets[sender]=0;
    }
  }

  function _mint(address recipient, uint256 amount,uint256 newNet) internal virtual {
    _updateAvgNet(recipient,amount,newNet);
    _mint(recipient,amount);
  }

  function _burn(address account, uint256 amount) internal virtual override{
    super._burn(account,amount);
    if(balanceOf(account)==0){
      SmartPoolStorage.load().nets[account]=0;
    }
  }

  function getJoinFeeRatio() public view returns (SmartPoolStorage.Fee memory){
    return SmartPoolStorage.load().fees[SmartPoolStorage.FeeType.JOIN_FEE];
  }

  function getExitFeeRatio() public view returns (SmartPoolStorage.Fee memory){
    return SmartPoolStorage.load().fees[SmartPoolStorage.FeeType.EXIT_FEE];
  }

  function getFee(SmartPoolStorage.FeeType ft) public view returns (SmartPoolStorage.Fee memory){
    return SmartPoolStorage.load().fees[ft];
  }

  function getNet(address investor)public view returns(uint256){
    return SmartPoolStorage.load().nets[investor];
  }

  function calcJoinAndExitFee(SmartPoolStorage.FeeType ft,uint256 amount)public view returns(uint256){
    if(amount==0){
      return amount;
    }
    SmartPoolStorage.Fee memory fee=SmartPoolStorage.load().fees[ft];
    uint256 denominator=fee.denominator==0?1000:fee.denominator;
    uint256 amountRatio=amount.div(denominator);
    return amountRatio.mul(fee.ratio);
  }

  function calcManagementFee(uint256 amount)public view returns(uint256){
    SmartPoolStorage.Fee memory fee=SmartPoolStorage.load().fees[SmartPoolStorage.FeeType.MANAGEMENT_FEE];
    uint256 denominator=fee.denominator==0?1000:fee.denominator;
    if(fee.lastTimestamp==0){
      return 0;
    }else{
      uint256 diff=block.timestamp.sub(fee.lastTimestamp);
      return amount.mul(diff).mul(fee.ratio).div(denominator*365.25 days);
    }
  }

  function calcPerformanceFee(address target,uint256 newNet)public view returns(uint256){
    uint256 balance=balanceOf(target);
    uint256 oldNet=SmartPoolStorage.load().nets[target];
    uint256 diff=newNet>oldNet?newNet.sub(oldNet):0;
    SmartPoolStorage.Fee memory fee=SmartPoolStorage.load().fees[SmartPoolStorage.FeeType.PERFORMANCE_FEE];
    uint256 denominator=fee.denominator==0?1000:fee.denominator;
    uint256 cash=diff.mul(balance).mul(fee.ratio).div(denominator);
    return cash.div(newNet);
  }


  function _chargeJoinAndExitFee(SmartPoolStorage.FeeType ft,uint256 shares)internal returns(uint256){
    SmartPoolStorage.Fee storage fee=SmartPoolStorage.load().fees[ft];
    uint256 payFee=calcJoinAndExitFee(ft,shares);
    if(payFee >fee.minLine) {
      if(ft==SmartPoolStorage.FeeType.JOIN_FEE){
        _mint(getRewards(),payFee,calcKfToToken(1e18));
      }else if(ft==SmartPoolStorage.FeeType.EXIT_FEE){
        _transfer(msg.sender,getRewards(),payFee);
      }
    }
    return payFee;
  }

  function _chargeOutstandingManagementFee()internal returns(uint256){
    SmartPoolStorage.Fee storage fee=SmartPoolStorage.load().fees[SmartPoolStorage.FeeType.MANAGEMENT_FEE];
    uint256 outstandingFee = calcManagementFee(totalSupply());
    if (outstandingFee > fee.minLine) {
      _mint(getRewards(),outstandingFee,0);
      fee.lastTimestamp=block.timestamp;
      emit ChargeFee(SmartPoolStorage.FeeType.MANAGEMENT_FEE,outstandingFee);
    }
    return outstandingFee;
  }

  function _chargeOutstandingPerformanceFee(address target)internal returns(uint256){
    uint256 netValue=calcKfToToken(1e18);
    SmartPoolStorage.Fee storage fee=SmartPoolStorage.load().fees[SmartPoolStorage.FeeType.PERFORMANCE_FEE];
    uint256 outstandingFee = calcPerformanceFee(target,netValue);
    if (outstandingFee > fee.minLine) {
      _transfer(target,getRewards(),outstandingFee);
      fee.lastTimestamp=block.timestamp;
      SmartPoolStorage.load().nets[target]=netValue;
      emit ChargeFee(SmartPoolStorage.FeeType.PERFORMANCE_FEE,outstandingFee);
    }
    return outstandingFee;
  }

  function chargeOutstandingManagementFee()public onlyGovernance{
      _chargeOutstandingManagementFee();
  }

  function chargeOutstandingPerformanceFee(address target)public onlyGovernance{
    _chargeOutstandingPerformanceFee(target);
  }

  function calcKfToToken(uint256)public virtual view returns(uint256);

}
