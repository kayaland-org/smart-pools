const weth='0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const IWETH = artifacts.require('./interfaces/weth/IWETH');
const UniswapV2ExpandLibrary=artifacts.require('./libraries/UniswapV2ExpandLibrary');
const UniswapV2ExpandLibraryMock=artifacts.require('./mocks/UniswapV2ExpandLibraryMock');
const SushiswapV2ExpandLibrary=artifacts.require('./libraries/SushiswapV2ExpandLibrary');
const SushiswapV2ExpandLibraryMock=artifacts.require('./mocks/SushiswapV2ExpandLibraryMock');

async function swapExactOutByUniSwap(toToken,receive,amountOut){
    let uniswapV2ExpandLibraryInstance= await UniswapV2ExpandLibrary.new();
    await UniswapV2ExpandLibraryMock.link('UniswapV2ExpandLibrary',uniswapV2ExpandLibraryInstance.address);
    let uniswapV2ExpandLibraryMockInstance= await UniswapV2ExpandLibraryMock.new();
    let wethIn= await uniswapV2ExpandLibraryMockInstance.getAmountIn(weth,toToken,amountOut);
    let iweth=await IWETH.at(weth);
    await iweth.deposit({value:wethIn});
    await iweth.transfer(uniswapV2ExpandLibraryMockInstance.address,wethIn);
    await uniswapV2ExpandLibraryMockInstance.swap(receive,weth,toToken,wethIn,amountOut);
}

async function swapExactInByUniSwap(toToken,receive,wethIn){
    let uniswapV2ExpandLibraryInstance= await UniswapV2ExpandLibrary.new();
    await UniswapV2ExpandLibraryMock.link('UniswapV2ExpandLibrary',uniswapV2ExpandLibraryInstance.address);
    let uniswapV2ExpandLibraryMockInstance= await UniswapV2ExpandLibraryMock.new();
    let amountOut= await  uniswapV2ExpandLibraryMockInstance.getAmountOut(weth,toToken,wethIn);
    let iweth=await IWETH.at(weth);
    await iweth.deposit({value:wethIn});
    await iweth.transfer(uniswapV2ExpandLibraryMockInstance.address,wethIn);
    await uniswapV2ExpandLibraryMockInstance.swap(receive,weth,toToken,wethIn,amountOut);
}
async function swapExactOutBySushiSwap(toToken,receive,amountOut){
    let sushiswapV2ExpandLibraryInstance= await SushiswapV2ExpandLibrary.new();
    await SushiswapV2ExpandLibraryMock.link('SushiswapV2ExpandLibrary',sushiswapV2ExpandLibraryInstance.address);
    let sushiswapV2ExpandLibraryMockInstance= await SushiswapV2ExpandLibraryMock.new();
    let wethIn= await sushiswapV2ExpandLibraryMockInstance.getAmountIn(weth,toToken,amountOut);
    let iweth=await IWETH.at(weth);
    await iweth.deposit({value:wethIn});
    await iweth.transfer(sushiswapV2ExpandLibraryMockInstance.address,wethIn);
    await sushiswapV2ExpandLibraryMockInstance.swap(receive,weth,toToken,wethIn,amountOut);
}

async function swapExactInBySushiSwap(toToken,receive,wethIn){
    let sushiswapV2ExpandLibraryInstance= await SushiswapV2ExpandLibrary.new();
    await SushiswapV2ExpandLibraryMock.link('SushiswapV2ExpandLibrary',sushiswapV2ExpandLibraryInstance.address);
    let sushiswapV2ExpandLibraryMockInstance= await SushiswapV2ExpandLibraryMock.new();
    let amountOut= await  sushiswapV2ExpandLibraryMockInstance.getAmountOut(weth,toToken,wethIn);
    let iweth=await IWETH.at(weth);
    await iweth.deposit({value:wethIn});
    await iweth.transfer(sushiswapV2ExpandLibraryMockInstance.address,wethIn);
    await sushiswapV2ExpandLibraryMockInstance.swap(receive,weth,toToken,wethIn,amountOut);
}
module.exports = {
    swapExactOutByUniSwap,
    swapExactInByUniSwap,
    swapExactOutBySushiSwap,
    swapExactInBySushiSwap
};







