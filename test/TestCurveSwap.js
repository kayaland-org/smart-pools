var sd = require('silly-datetime');
const TokenHelper = require( "../scripts/TokenHelper" );
const EvmHelper = require( "../scripts/EvmHelper" );

const buyAddr='0xdAC17F958D2ee523a2206206994597C13D831ec7';

const synthAddr='0xfE18be6b3Bd88A2D2A7f928d00292E7a9963CfC6';
const toTokenAddr='0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20');

const CurveSwapLibrary = artifacts.require('./libraries/CurveSwapLibrary');
const CurveSwapLibraryMock = artifacts.require('./mocks/CurveSwapLibraryMock');


contract('CurveSwapLibraryMock', (accounts) => {

    let curveSwapLibraryMockInstance;
    let synthToken;
    let butToken;
    let toToken;
    let synthSymbol;
    let toTokenSymbol;

    before(async () => {
        butToken=await IERC20.at(buyAddr);
        let curveSwapLibraryInstance = await CurveSwapLibrary.new();
        await CurveSwapLibraryMock.link('CurveSwapLibrary', curveSwapLibraryInstance.address);
        curveSwapLibraryMockInstance = await CurveSwapLibraryMock.new();

        synthToken=await IERC20.at(synthAddr);
        toToken=await IERC20.at(toTokenAddr);
        synthSymbol=await synthToken.symbol();
        toTokenSymbol=await toToken.symbol();
    });

    describe('USDT swap to token', async () => {

        it('Call swap into synth should work', async () => {
            // await EvmHelper.increaseBlockTime(370000);
            const intoAmount=10000000000;
            await TokenHelper.swapExactOutByUniSwap(buyAddr,curveSwapLibraryMockInstance.address,intoAmount);
            let preIntoAmount=await curveSwapLibraryMockInstance.getSwapIntoAmountOut(buyAddr,synthAddr,intoAmount);
            let swapIntoRecipe=await curveSwapLibraryMockInstance.swapInto(buyAddr,synthAddr,intoAmount);
            let intoTokenId=swapIntoRecipe.receipt.rawLogs[swapIntoRecipe.receipt.rawLogs.length-1].topics[1];
            console.log("["+sd.format(new Date(), 'YYYY-MM-DD HH:mm:ss')+"]Input USDT:"+intoAmount+",Estimate "+synthSymbol+" Output:"+preIntoAmount+",Output NFT:"+intoTokenId);
            let tokenInfo=await curveSwapLibraryMockInstance.tokenInfo(intoTokenId);
            let intoAmountOut=tokenInfo[2];
            console.log("["+sd.format(new Date(), 'YYYY-MM-DD HH:mm:ss')+"]Input NFT:"+intoTokenId+",Actual Synth Balance:"+intoAmountOut+",Max Settlement Time:"+tokenInfo[3]);
            assert.notEqual(intoAmountOut,0,"withdraw fail of synth is zero");
            await EvmHelper.increaseBlockTime(600000);
            let preFromAmount=await curveSwapLibraryMockInstance.getSwapFromAmountOut(synthAddr,toTokenAddr,intoAmountOut);
            let swapFromRecipe=await curveSwapLibraryMockInstance.swapFrom(intoTokenId,synthAddr,toTokenAddr,intoAmountOut);
            let toTokenBal=await toToken.balanceOf(curveSwapLibraryMockInstance.address);
            let fromTokenId=swapFromRecipe.receipt.rawLogs[swapFromRecipe.receipt.rawLogs.length-1].topics[1];
            console.log("["+sd.format(new Date(), 'YYYY-MM-DD HH:mm:ss')+"]Input NFT:"+intoTokenId+",Estimate "+toTokenSymbol+" Output:"+intoAmountOut+",Actual "+toTokenSymbol+" Output:"+toTokenBal);
        });
    });
});
