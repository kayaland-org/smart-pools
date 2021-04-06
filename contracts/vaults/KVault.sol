// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/kaya/IController.sol";
import "../BasicSmartPoolV2.sol";
pragma experimental ABIEncoderV2;
contract KVault is BasicSmartPoolV2{

  using SafeERC20 for IERC20;

  address public token;

  event PoolJoined(address indexed sender,address indexed to, uint256 amount);
  event PoolExited(address indexed sender,address indexed from, uint256 amount);

  function init(string memory _name,string memory _symbol,address _token) public {
    require(token == address(0), "KVault.init: already initialised");
    require(_token != address(0), "KVault.init: _token cannot be 0x00....000");
    super._init(_name,_symbol,ERC20(_token).decimals());
    token=_token;
  }

  function joinPool(uint256 amount) public {
    IERC20 tokenContract=IERC20(token);
    address investor=msg.sender;
    require(amount<=tokenContract.balanceOf(investor)&&amount>0,"KVault.joinPool: Insufficient balance");
    uint256 shares=calcTokenToKf(amount);
    //add charge management fee
    _chargeOutstandingManagementFee();
    //charge join fee
    uint256 fee=_chargeJoinAndExitFee(SmartPoolStorage.FeeType.JOIN_FEE,shares);
    _mint(investor,shares.sub(fee),calcKfToToken(1e18));
    tokenContract.safeTransferFrom(investor, address(this), amount);
    emit PoolJoined(investor,investor,shares);
  }

  function exitPool(uint256 amount) external{
    address investor=msg.sender;
    require(balanceOf(investor)>=amount&&amount>0,"KVault.exitPool: Insufficient balance");
    //charge exit fee
    uint256 fee=_chargeJoinAndExitFee(SmartPoolStorage.FeeType.EXIT_FEE,amount);
    uint256 exitAmount=amount.sub(fee);
    uint256 tokenAmount = calcKfToToken(exitAmount);
    //charge performance fee
    _chargeOutstandingPerformanceFee(investor);
    //charge management fee
    _chargeOutstandingManagementFee();
    // Check cash balance
    IERC20 tokenContract=IERC20(token);
    uint256 cashBal = tokenContract.balanceOf(address(this));
    if (cashBal < tokenAmount) {
      uint256 diff = tokenAmount.sub(cashBal);
      IController(getController()).harvest(diff);
      tokenAmount=tokenContract.balanceOf(address(this));
    }
    tokenContract.safeTransfer(investor,tokenAmount);
    _burn(investor,exitAmount);
    emit PoolExited(investor,investor,exitAmount);
  }

  function exitPoolOfUnderlying(uint256 amount)external{
    address investor=msg.sender;
    require(balanceOf(investor)>=amount&&amount>0,"KVault.exitPoolOfUnderlying: Insufficient balance");
    uint256 fee=calcJoinAndExitFee(SmartPoolStorage.FeeType.EXIT_FEE,amount);
    uint256 exitAmount=amount.sub(fee);
    uint256 tokenAmount = calcKfToToken(exitAmount);
    //charge performance fee
    _chargeOutstandingPerformanceFee(investor);
    //charge management fee
    _chargeOutstandingManagementFee();
    IController(getController()).harvestOfUnderlying(investor,tokenAmount);
    _burn(investor,exitAmount);
    emit PoolExited(investor,investor,exitAmount);
  }

  function transferCash(address to,uint256 amount)external onlyController{
    require(amount>0,'KVault.transferCash: Must be greater than 0 amount');
    uint256 available = IERC20(token).balanceOf(address(this));
    require(amount<=available,'KVault.transferCash: Must be less than balance');
    IERC20(token).safeTransfer(to, amount);
  }

  function calcKfToToken(uint256 amount) public override view returns(uint256){
    if(totalSupply()==0){
      return amount;
    }else{
      return (assets().mul(amount)).div(totalSupply());
    }
  }

  function calcTokenToKf(uint256 amount) public view returns(uint256){
    uint256 shares=0;
    if(totalSupply()==0){
      shares=amount;
    }else{
      shares=amount.mul(totalSupply()).div(assets());
    }
    return shares;
  }

  function assets()public view returns(uint256){
    return IERC20(token).balanceOf(address(this)).add(IController(getController()).assets());
  }

}
