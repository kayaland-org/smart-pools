// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libraries/ERC20Helper.sol";
import "./interfaces/kaya/IStrategy.sol";
import "./interfaces/kaya/ISmartPool.sol";
import "./GovIdentity.sol";

contract Controller is GovIdentity{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public maxWithdrawFee=200;

    mapping(address => address) public vaults;
    mapping(address => address) public strategies;
    mapping(address => uint256) public maxFee;
    mapping(address => bool) public withdrawFeeStatus;
    mapping(address => bool) public inRegister;

    event Invest(address indexed vault,uint256 amount);
    event WithdrawFee(address indexed to,uint256 amount);

    function withdrawMinnerFee(address _vault,uint256 _amount)external onlyStrategistOrGovernance{
        require(maxFee[_vault]>0,'Controller.withdrawMinnerFee: max fee == 0');
        ISmartPool pool=ISmartPool(_vault);
        address token=pool.token();
        uint256 decimals=ERC20(token).decimals();
        uint256 _maxWithdrawFee=maxFee[_vault].mul(10**decimals);
        require(_amount<=_maxWithdrawFee,"Controller.withdrawMinnerFee: Must be less than max fee");
        require(withdrawFeeStatus[_vault],"Controller.withdrawMinnerFee: Already extracted");
        pool.transferCash(msg.sender,_amount);
        withdrawFeeStatus[_vault]=false;
        emit WithdrawFee(msg.sender,_amount);
    }

    function register(address _contract,bool value) external onlyStrategistOrGovernance{
        inRegister[_contract]=value;
    }

    function bindVault(address _vault, address _strategy,uint256 _amount,uint256 _maxFee) external onlyStrategistOrGovernance{
        require(inRegister[_strategy],'Controller.bindVault: _strategy is not registered');
        address _current = strategies[_vault];
        if (_current != address(0)) {
            IStrategy(_current).withdrawAll();
        }
        vaults[_strategy] = _vault;
        withdrawFeeStatus[_vault]=true;
        maxFee[_vault]=_maxFee;
        strategies[_vault]=_strategy;
        ISmartPool pool=ISmartPool(_vault);
        IERC20 token=IERC20(pool.token());
        if(_amount>0){
            token.safeTransferFrom(msg.sender,address(this),_amount);
            ERC20Helper.safeApprove(address(token),_strategy,_amount);
        }
        IStrategy(_strategy).init();
        uint256 balance=token.balanceOf(address(this));
        if(balance>0){
            token.safeTransfer(msg.sender,balance);
        }
    }

    function invest(address _vault, uint256 _amount) external {
        address _strategy = strategies[_vault];
        require(_strategy!=address(0),'Controller.invest: vault is not binding strategy');
        ISmartPool pool=ISmartPool(_vault);
        pool.transferCash(address(this),_amount);
        IERC20 token=IERC20(pool.token());
        ERC20Helper.safeApprove(address(token),_strategy,_amount);
        IStrategy(_strategy).deposit(_amount);
        withdrawFeeStatus[_vault]=true;
        emit Invest(_vault,_amount);
    }

    function exec(
        address _strategy,
        bool _useToken,
        uint256 _useAmount,
        string memory _signature,
        bytes memory _data)
    external onlyStrategistOrGovernance{
        if(_useToken){
            address _vault = vaults[_strategy];
            require(_vault!=address(0),'Controller.exec: strategy is not binding vault');
            ISmartPool pool=ISmartPool(_vault);
            pool.transferCash(address(this),_useAmount);
            ERC20Helper.safeApprove(pool.token(),_strategy,_useAmount);
        }
        bytes memory callData;
        if (bytes(_signature).length == 0) {
            callData = _data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(_signature))), _data);
        }
        (bool success, ) = _strategy.call{value:0}(callData);
        require(success, "Controller::exec: Transaction execution reverted");
    }

    function harvest(uint256 _amount) external{
        require(strategies[msg.sender]!=address(0), "Controller.harvest: sender is not vault");
        IStrategy(strategies[msg.sender]).withdraw(_amount);
    }

    function harvestAll(address _vault) external onlyStrategistOrGovernance{
        require(strategies[_vault]!=address(0), "Controller.harvestAll: vault is not binding strategy");
        IStrategy(strategies[_vault]).withdrawAll();
    }

    function harvestOfUnderlying(address to,uint256 _amount)external{
        require(strategies[msg.sender]!=address(0), "Controller.harvestOfUnderlying: sender is not vault");
        IStrategy(strategies[msg.sender]).withdrawOfUnderlying(to,_amount);
    }

    function assets() external view returns (uint256) {
        require(strategies[msg.sender]!=address(0), "Controller.assets: sender is not vault");
        return IStrategy(strategies[msg.sender]).assets();
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) public onlyStrategistOrGovernance{
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function inCaseStrategyTokenGetStuck(address _strategy, address _token) public onlyStrategistOrGovernance{
        IStrategy(_strategy).withdraw(_token);
    }

}