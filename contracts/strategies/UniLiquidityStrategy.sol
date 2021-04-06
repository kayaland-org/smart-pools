// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/uniswap-v2/IUniswapV2Router02.sol";
import "../interfaces/kaya/ISmartPool.sol";
import "../interfaces/kaya/IController.sol";
import "../libraries/UniswapV2ExpandLibrary.sol";
import "../libraries/MathExpandLibrary.sol";
import "../libraries/ERC20Helper.sol";
import "../GovIdentity.sol";

contract UniLiquidityStrategy is GovIdentity {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using MathExpandLibrary for uint256;

    uint256 constant public INIT_NUM=100;
    uint256 constant public INIT_NUM_VALUE=INIT_NUM*(1e18);

    address public tokenA;
    address public tokenB;
    address public pair;

    IController public controller;
    IUniswapV2Router02 constant public route=IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address constant public WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    event RemoveLiquidity(address indexed from,uint256 liquidity);

    constructor(
        address _controller,
        address _tokenA,
        address _tokenB)
    public {
        controller = IController(_controller);
        tokenA=_tokenA;
        tokenB=_tokenB;
    }

    function _clearWeth() internal {
        uint256 amountIn = IERC20(WETH).balanceOf(address(this));
        (address _vault,address _token) = vaultInfo();
        UniswapV2ExpandLibrary.swapExactIn(address(this),WETH,_token,amountIn);
        IERC20(_token).safeTransfer(_vault, IERC20(_token).balanceOf(address(this)));
    }

    function _removeLiquidity(uint256 liquidity) internal returns(uint256 amountA,uint256 amountB){
        if(liquidity>0){
            (amountA,amountB)=UniswapV2ExpandLibrary.calcLiquidityToTokens(tokenA,tokenB,liquidity);
            (amountA,amountB)=route.removeLiquidity(tokenA,tokenB,liquidity,amountA,amountB,address(this),block.timestamp);
            emit RemoveLiquidity(msg.sender,liquidity);
        }
    }

    function vaultInfo() internal view returns (address, address){
        address _vault = controller.vaults(address(this));
        address _token = ISmartPool(_vault).token();
        return (_vault, _token);
    }

    function init() external {
        require(pair == address(0), 'Strategy.init: already initialised');
        require(msg.sender == address(controller), 'Strategy.init: !controller');
        pair=UniswapV2ExpandLibrary.pairFor(tokenA,tokenB);
        approveTokens();
    }

    function getTokens()public view returns(address[] memory ts){
        ts=new address[](2);
        ts[0]=tokenA;
        ts[1]=tokenB;
    }

    function getWeights()public pure returns(uint256[] memory ws){
        ws=new uint256[](2);
        ws[0]=50e18;
        ws[1]=50e18;
    }

    function approveTokens() public {
        require(pair != address(0), 'Strategy.approveTokens: not initialised');
        ERC20Helper.safeApprove(pair,address(route),uint256(-1));
        address[] memory _tokens=getTokens();
        for(uint256 i=0;i<_tokens.length;i++){
            ERC20Helper.safeApprove(_tokens[i],address(route),uint256(-1));
        }
    }

    function deposit(uint256 _amount) external {
        require(msg.sender == address(controller), 'Strategy.init: !controller');
        require(_amount > 0, 'Strategy.deposit: token balance is zero');
        (,address _vaultToken) = vaultInfo();
        IERC20 tokenContract = IERC20(_vaultToken);
        require(tokenContract.balanceOf(msg.sender) >= _amount, 'Strategy.deposit: Insufficient balance');
        tokenContract.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 hasWethTotal = UniswapV2ExpandLibrary.swapExactIn(address(this),_vaultToken,WETH,_amount);
        uint256 liquidityExpect=calcLiquidityByTokenIn(hasWethTotal);
        (uint256 amountA,uint256 amountB)=UniswapV2ExpandLibrary.calcLiquidityToTokens(tokenA,tokenB,liquidityExpect);
        UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,tokenA,amountA);
        UniswapV2ExpandLibrary.swapExactOut(address(this),WETH,tokenB,amountB);
        IERC20 tokenAContract = IERC20(tokenA);
        IERC20 tokenBContract = IERC20(tokenB);
        (amountA,amountB)=(tokenAContract.balanceOf(address(this)),tokenBContract.balanceOf(address(this)));
        (,,liquidityExpect)=route.addLiquidity(tokenA,tokenB,amountA,amountB,0,0,address(this),block.timestamp);
        UniswapV2ExpandLibrary.swapExactIn(address(this),tokenA,WETH,tokenAContract.balanceOf(address(this)));
        UniswapV2ExpandLibrary.swapExactIn(address(this),tokenB,WETH,tokenBContract.balanceOf(address(this)));
        _clearWeth();
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == address(controller), 'Strategy.withdraw: !controller');
        require(_amount > 0, 'Strategy.withdraw: Must be greater than 0 amount');
        require(_amount <= assets(), 'Strategy.withdraw: Must be less than assets');
        uint256 liquidity= calcLiquidityByTokenOut(_amount);
        (uint256 amountA,uint256 amountB)=_removeLiquidity(liquidity);
        UniswapV2ExpandLibrary.swapExactIn(address(this),tokenA,WETH,amountA);
        UniswapV2ExpandLibrary.swapExactIn(address(this),tokenB,WETH,amountB);
        _clearWeth();
    }

    function withdrawOfUnderlying(address _to,uint256 _amount)external{
        require(msg.sender == address(controller), 'Strategy.withdrawOfUnderlying: !controller');
        require(_amount > 0, 'Strategy.withdrawOfUnderlying: Must be greater than 0 amount');
        require(_amount <= assets(), 'Strategy.withdrawOfUnderlying: Must be less than assets');
        uint256 liquidity= calcLiquidityByTokenOut(_amount);
        (uint256 amountA,uint256 amountB)=_removeLiquidity(liquidity);
        IERC20(tokenA).safeTransfer(_to,amountA);
        IERC20(tokenB).safeTransfer(_to,amountB);
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
        uint256 liquidity=liquidityBalance();
        _removeLiquidity(liquidity);
        UniswapV2ExpandLibrary.swapExactIn(address(this),tokenA,WETH,IERC20(tokenA).balanceOf(address(this)));
        UniswapV2ExpandLibrary.swapExactIn(address(this),tokenB,WETH,IERC20(tokenB).balanceOf(address(this)));
        _clearWeth();
    }

    function calcLiquidityByTokenOut(uint256 amount)public view returns(uint256){
        uint256 lp=liquidityBalance();
        uint256 assets=assets();
        if(lp==0){
            return 0;
        }else{
            return lp.bdiv(assets).bmul(amount);
        }
    }

    function calcLiquidityByTokenIn(uint256 amount)public view returns(uint256){
        uint256 balance0 = IERC20(WETH).balanceOf(pair);
        uint256 totalSupply=IERC20(pair).totalSupply();
        uint256 totalSupply2=totalSupply.mul(totalSupply);
        uint256 x=uint256(1000).mul(amount).mul(totalSupply2);
        uint256 y=uint256(997).mul(balance0);
        uint256 n=((totalSupply2.add(x.div(y))).sqrt().sub(totalSupply)).mul(997).div(1000);
        return n;
    }

    function extractableUnderlyingNumber(uint256 _amount)public view returns(uint256[] memory tokenNumbers){
        uint256 liquidity= calcLiquidityByTokenOut(_amount);
        (uint256 amountA,uint256 amountB)=UniswapV2ExpandLibrary.calcLiquidityToTokens(tokenA,tokenB,liquidity);
        tokenNumbers=new uint256[](2);
        tokenNumbers[0]=amountA;
        tokenNumbers[1]=amountB;
    }

    function assets() public view returns (uint256){
        uint256 liquidity=liquidityBalance();
        if(liquidity==0){
            return 0;
        }
        (,address _token) = vaultInfo();
        return UniswapV2ExpandLibrary.calcLiquiditySwapToToken(pair,_token,WETH,liquidity);
    }

    function available() public view returns (uint256){
        return assets();
    }

    function liquidityBalance()public view returns(uint256){
        return UniswapV2ExpandLibrary.liquidityBalance(pair,address(this));
    }
}
