// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/kaya/ISmartPool.sol";
import "../interfaces/kaya/IController.sol";
import "../interfaces/balancer/IBPool.sol";
import "../interfaces/balancer/IBFactory.sol";
import "../libraries/UniswapV2ExpandLibrary.sol";
import "../libraries/MathExpandLibrary.sol";
import "../libraries/ERC20Helper.sol";
import "../GovIdentity.sol";

contract BalLiquidityStrategy is ERC20, GovIdentity {

    using SafeERC20 for IERC20;
    using Address for address;
    using MathExpandLibrary for uint256;

    uint256 constant public INIT_NUM=1;
    uint256 constant public INIT_NUM_VALUE=INIT_NUM*(1e18);

    uint256[] public weights;
    uint256[] public amounts;
    address[] public tokens;

    IController public controller;
    IBPool public bPool;

    address constant public WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant public bFactory = address(0x9424B1412450D0f8Fc2255FAf6046b98213B76Bd);

    constructor(
        address _controller,
        address[] memory _tokens,
        uint256[] memory _weights,
        uint256[] memory _amounts)
    public
    ERC20('Share Token', 'ST'){
        require(_tokens.length == _weights.length && _weights.length == _amounts.length, 'Strategy: Parameter error');
        tokens = _tokens;
        weights = _weights;
        amounts = _amounts;
        controller = IController(_controller);
    }

    function getTokens()public view returns(address[] memory){
       return tokens;
    }

    function getWeights()public view returns(uint256[] memory){
        return weights;
    }

    function _pullToken(address _token)internal returns(uint256 amount){
        IERC20 token = IERC20(_token);
        amount = token.balanceOf(msg.sender);
        if(amount>0){
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _clearWeth(address to,address _token) internal {
        uint256 amountIn = IERC20(WETH).balanceOf(address(this));
        UniswapV2ExpandLibrary.swapExactIn(address(this),WETH,_token,amountIn);
        IERC20(_token).safeTransfer(to, IERC20(_token).balanceOf(address(this)));
    }

    function _syncTokens()internal{
        tokens=bPool.getCurrentTokens();
        uint256 totalSupply = totalSupply();
        for(uint256 i=0;i<tokens.length;i++){
            weights[i]=bPool.getDenormalizedWeight(tokens[i]);
            uint256 tbal = IERC20(tokens[i]).balanceOf(address(bPool));
            uint256 initAmount = tbal.bdiv(totalSupply).mul(INIT_NUM);
            amounts[i]=initAmount;
        }
    }

    function _vaultInfo() internal view returns (address, address){
        address _vault = controller.vaults(address(this));
        address _token = ISmartPool(_vault).token();
        return (_vault, _token);
    }

    function _estimateShareCount(uint256 wethAmount,uint256 direction) internal view returns (uint256 preShareCount, uint256[] memory oneShareAmounts){
        uint256 totalSupply = totalSupply().sub(INIT_NUM_VALUE);
        oneShareAmounts=new uint256[](tokens.length);
        uint256 oneShareWethAmount=0;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 oneShareAmount;
            if (totalSupply == 0) {
                oneShareAmount = amounts[i];
            } else {
                uint256 tbal = IERC20(tokens[i]).balanceOf(address(bPool));
                oneShareAmount = tbal.bdiv(totalSupply);
            }
            oneShareAmounts[i] = oneShareAmount;
            if (tokens[i] != WETH) {
                if(direction==0){
                    oneShareAmount=UniswapV2ExpandLibrary.getAmountIn(WETH,tokens[i], oneShareAmount);
                }else{
                    oneShareAmount=UniswapV2ExpandLibrary.getAmountOut(tokens[i], WETH, oneShareAmount);
                }
            }
            oneShareWethAmount = oneShareWethAmount.add(oneShareAmount);
        }
         preShareCount=wethAmount.div(oneShareWethAmount);
    }

    function _estimateShareCountByWithdraw(uint256 _amount)internal view returns(uint256,uint256[] memory){
        (,address _vaultToken) = _vaultInfo();
        uint256 needWeth = _amount;
        if (WETH != _vaultToken) {
            needWeth = UniswapV2ExpandLibrary.getAmountIn(WETH, _vaultToken, _amount);
        }
        return _estimateShareCount(needWeth,1);
    }

    function newBPool()external {
      require(msg.sender == address(controller), 'Strategy.newBPool: !controller');
      require(address(bPool) == address(0), 'Strategy.newBPool: already initialised');
      bPool = IBPool(IBFactory(bFactory).newBPool());
    }

    function init() external {
        require(msg.sender == address(controller), 'Strategy.init: !controller');
        require(address(bPool) != address(0), 'Strategy.init: not newBPool');
        require(totalSupply() == 0, 'Strategy.init: already initialised');
        (,address _vaultToken) = _vaultInfo();
        uint256 amountIn=_pullToken(_vaultToken);
        UniswapV2ExpandLibrary.swapExactIn(address(this),_vaultToken,WETH,amountIn);
        for (uint256 i = 0; i < tokens.length; i++) {
            UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,tokens[i],amounts[i]);
            //Approve the balancer pool
            ERC20Helper.safeApprove(tokens[i],address(bPool), uint256(-1));
            // Bind tokens
            bPool.bind(tokens[i], amounts[i], weights[i]);
        }
        _clearWeth(msg.sender,_vaultToken);
        _mint(address(this), INIT_NUM_VALUE);
    }

    function approveTokens() public {
        require(address(bPool) != address(0), 'Strategy.approveTokens: not initialised');
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Helper.safeApprove(tokens[i],address(bPool), uint256(-1));
        }
    }

    function bind(address _token, uint256 _amount, uint256 _weight) external {
        require(msg.sender == address(controller), 'Strategy.bind: !controller');
        require(address(bPool) != address(0), 'Strategy.bind: not initialised');
        require(!bPool.isBound(_token), 'Strategy.bind: the token is bound');
        (address _vault,address _vaultToken) = _vaultInfo();
        uint256 amountIn= _pullToken(_vaultToken);
        UniswapV2ExpandLibrary.swapExactIn(address(this),_vaultToken,WETH,amountIn);
        UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,_token,_amount);
        ERC20Helper.safeApprove(_token,address(bPool), uint256(-1));
        // Bind tokens
        bPool.bind(_token, _amount, _weight);
        _syncTokens();
        _clearWeth(_vault,_vaultToken);
    }

    function rebind(address _token, uint256 _amount, uint256 _weight) external {
        require(msg.sender == address(controller), 'Strategy.rebind: !controller');
        require(address(bPool) != address(0), 'Strategy.rebind: not initialised');
        require(bPool.isBound(_token), 'Strategy.bind: the token is bound');
        (address _vault,address _vaultToken) = _vaultInfo();
        uint256 amountIn= _pullToken(_vaultToken);
        UniswapV2ExpandLibrary.swapExactIn(address(this),_vaultToken,WETH,amountIn);
        IERC20 token = IERC20(_token);
        bPool.gulp(_token);
        uint256 oldBalance = token.balanceOf(address(bPool));
        if (_amount > oldBalance) {
            UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,_token,_amount.sub(oldBalance));
            ERC20Helper.safeApprove(_token,address(bPool), uint256(-1));
        }
        bPool.rebind(_token, _amount, _weight);
        _syncTokens();
        amountIn = token.balanceOf(address(this));
        UniswapV2ExpandLibrary.swapExactIn(address(this),_token,WETH,amountIn);
        _clearWeth(_vault,_vaultToken);
    }

    function unbind(address _token) external {
        require(msg.sender == address(controller), 'Strategy.unbind: !controller');
        require(address(bPool) != address(0), 'Strategy.unbind: not initialised');
        IERC20 token = IERC20(_token);
        bPool.unbind(_token);
        _syncTokens();
        uint256 amountIn = token.balanceOf(address(this));
        UniswapV2ExpandLibrary.swapExactIn(address(this),_token,WETH,amountIn);
        (address _vault,address _vaultToken) = _vaultInfo();
        _clearWeth(_vault,_vaultToken);
    }

    function deposit(uint256 _amount) external {
        require(msg.sender == address(controller), 'Strategy.deposit: !controller');
        (address _vault,address _vaultToken) = _vaultInfo();
        require(_amount > 0, 'Strategy.deposit: token balance is zero');
        IERC20 tokenContract = IERC20(_vaultToken);
        require(tokenContract.balanceOf(msg.sender) >= _amount, 'Strategy.deposit: Insufficient balance');
        tokenContract.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 hasWethTotal = UniswapV2ExpandLibrary.swapExactIn(address(this),_vaultToken,WETH,_amount);
        (uint256 preShareCount,uint256[] memory oneShareAmounts) = _estimateShareCount(hasWethTotal,0);
        require(preShareCount > 0, 'Strategy.deposit: Must be greater than 0 amount by pre share Count ');
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amountOut = oneShareAmounts[i].mul(preShareCount);
            UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,tokens[i],amountOut);
            uint256 tbal = IERC20(tokens[i]).balanceOf(address(bPool));
            bPool.rebind(tokens[i], tbal.add(amountOut), weights[i]);
        }
        _mint(address(this), preShareCount.mul(1e18));
        _clearWeth(_vault,_vaultToken);
    }

    function _pullUnderlying(uint256 _amount) internal returns(uint256 burnAmount,uint256[] memory amountIns){
        require(msg.sender == address(controller), 'Strategy.pullUnderlying: !controller');
        require(_amount > 0, 'Strategy.pullUnderlying: Must be greater than 0 amount');
        require(_amount <= assets(), 'Strategy.pullUnderlying: Must be less than assets');
        (uint256 preShareCount,uint256[] memory oneShareAmounts) = _estimateShareCountByWithdraw(_amount);
        require(preShareCount>0,'Strategy.pullUnderlying: Must be greater than 0 preShareCount');
        burnAmount=preShareCount.mul(1e18);
        require(totalSupply().sub(burnAmount) >= INIT_NUM_VALUE, 'Strategy.pullUnderlying: Must be greater than the number of initializations');
        amountIns=new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token=IERC20(tokens[i]);
            uint256 tbal = token.balanceOf(address(bPool));
            uint256 amountIn = oneShareAmounts[i].mul(preShareCount);
            bPool.rebind(tokens[i], tbal.sub(amountIn), weights[i]);
            amountIns[i]=amountIn;
        }
    }

    function withdraw(uint256 _amount) external {
        (uint256 burnAmount,uint256[] memory amountIns)=_pullUnderlying(_amount);
        for (uint256 i = 0; i < tokens.length; i++) {
            UniswapV2ExpandLibrary.swapExactIn(address(this),tokens[i],WETH,amountIns[i]);
        }
        _burn(address(this), burnAmount);
        (address _vault,address _vaultToken) = _vaultInfo();
        _clearWeth(_vault,_vaultToken);
    }

    function withdrawOfUnderlying(address to,uint256 _amount)external{
        (uint256 burnAmount,uint256[] memory amountIns)=_pullUnderlying(_amount);
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(to,amountIns[i]);
        }
        _burn(address(this), burnAmount);
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
        require(totalSupply() > INIT_NUM_VALUE, 'Strategy.withdrawAll: Must be greater than the number of initializations');
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amountOut = amounts[i];
            IERC20 token=IERC20(tokens[i]);
            require(token.balanceOf(address(bPool))>=amountOut,'Strategy.withdrawAll: token balance < amountOut');
            bPool.rebind(tokens[i],amountOut,bPool.getDenormalizedWeight(tokens[i]));
            uint256 amountIn = token.balanceOf(address(this));
            UniswapV2ExpandLibrary.swapExactIn(address(this),tokens[i],WETH,amountIn);
        }
        _burn(address(this), totalSupply().sub(INIT_NUM_VALUE));
        (address _vault,address _vaultToken) = _vaultInfo();
        _clearWeth(_vault,_vaultToken);
    }

    function extractableUnderlyingNumber(uint256 _amount)public view returns(uint256[] memory tokenNumbers){
        (uint256 preShareCount,uint256[] memory oneShareAmounts) = _estimateShareCountByWithdraw(_amount);
        if(preShareCount>0){
            tokenNumbers=new uint256[](oneShareAmounts.length);
            for (uint256 i = 0; i < oneShareAmounts.length; i++) {
                tokenNumbers[i]=oneShareAmounts[i].mul(preShareCount);
            }
        }
    }

    function assets() public view returns (uint256){
        uint256 amountWethOut;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amountIn = IERC20(tokens[i]).balanceOf(address(bPool)).sub(amounts[i]);
            if(amountIn>0){
                if (tokens[i] == WETH) {
                    amountWethOut = amountWethOut.add(amountIn);
                } else {
                    amountWethOut = amountWethOut.add(UniswapV2ExpandLibrary.getAmountOut(tokens[i], WETH, amountIn));
                }
            }
        }
        (,address _token) = _vaultInfo();
        if (amountWethOut > 0) {
            return UniswapV2ExpandLibrary.getAmountOut(WETH, _token, amountWethOut);
        } else {
            return 0;
        }
    }

    function available() public view returns (uint256){
        return assets();
    }
}
