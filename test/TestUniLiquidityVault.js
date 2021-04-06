const {ether,constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const weth='0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const wbtc='0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';
const usdt='0xdAC17F958D2ee523a2206206994597C13D831ec7';

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/IERC20');
const IWETH = artifacts.require('./interfaces/weth/IWETH');
const UniswapV2ExpandLibrary=artifacts.require('./libraries/UniswapV2ExpandLibrary');
const UniswapV2ExpandLibraryMock=artifacts.require('./mocks/UniswapV2ExpandLibraryMock');
const SmartPool = artifacts.require('./vaults/UniLiquidityVault');

const name = 'KF BTC-ETH Fund';
const symbol = 'KFBET';

contract('UniLiquidityVault', (accounts) => {

    let smartPoolInstance;

    before(async () => {
        let uniswapV2ExpandLibraryInstance= await UniswapV2ExpandLibrary.new();
        await UniswapV2ExpandLibraryMock.link('UniswapV2ExpandLibrary',uniswapV2ExpandLibraryInstance.address);
        this.uniswapV2ExpandLibraryMockInstance=await UniswapV2ExpandLibraryMock.new();
        await SmartPool.link('UniswapV2ExpandLibrary',uniswapV2ExpandLibraryInstance.address);
    });
    describe('init', async () => {
        it('Call init with is Init = false  should work', async () => {
            smartPoolInstance = await SmartPool.new();
            await smartPoolInstance.init(weth,wbtc,name,symbol);
            let nameValue=await smartPoolInstance.name();
            assert.equal(nameValue,name,'init fail');
        });
        it('Call init with is Init = true  should fail', async () => {
            await expectRevert(smartPoolInstance.init(weth,wbtc,name,symbol),
                'UniLiquidityVault.init: already initialised');
        });
    });
    describe('calc', async () => {
        it('Call calcKfToUsdt kf total with zero should work', async () => {
            let smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            let kfInput=1000000;
            let usdtAmount=await smartPoolInstance.calcKfToUsdt(kfInput);
            assert.equal(kfInput,usdtAmount,'calcKfToUsdt fail');
        });
        it('Call calcUsdtToKf usdt total with zero should work', async () => {
            let smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            let usdtAmount=1000000;
            let kfInput=await smartPoolInstance.calcUsdtToKf(usdtAmount);
            assert.equal(kfInput,usdtAmount,'calcUsdtToKf fail');
        });
        it('Call calcLiquidityDesiredByAdd with 1 ether should work', async () => {
            let smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            let lp=await smartPoolInstance.calcLiquidityDesiredByAdd(new ether('1'));
            assert.notEqual(lp,0,'calcLiquidityDesiredByAdd calc to value: '+lp);
        });
    });

    describe('joinPool', async () => {
        it('Call joinPool usdt with insufficient balance should fail', async () => {
            smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            let iusdt=await IERC20.at(usdt);
            let usdtBal=await iusdt.balanceOf(accounts[0]);
            await expectRevert(smartPoolInstance.joinPool(usdtBal.add(new ether('1'))),
                'UniLiquidityVault.joinPool: Insufficient balance',
            );
        });

        it('Call joinPool usdt with 1 usdt should work', async () => {
            smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            let usdtAmount=10000000;
            let wethIn= await  this.uniswapV2ExpandLibraryMockInstance.getAmountIn(weth,usdt,usdtAmount);
            let iweth=await IWETH.at(weth);
            await iweth.deposit({value:wethIn});
            //buyer usdt token
            await iweth.transfer(this.uniswapV2ExpandLibraryMockInstance.address,wethIn);
            await this.uniswapV2ExpandLibraryMockInstance.swap(accounts[0],weth,usdt,wethIn,usdtAmount);
            let iusdt=await IERC20.at(usdt);
            await iusdt.approve(smartPoolInstance.address,await iusdt.balanceOf(accounts[0]));
            await smartPoolInstance.joinPool(usdtAmount);
            let kTokenBal=await smartPoolInstance.balanceOf(accounts[0]);
            assert.equal(kTokenBal,usdtAmount,'kToken fail');
            let usdtBal=await iusdt.balanceOf(smartPoolInstance.address);
            assert.equal(usdtBal,usdtAmount,'usdtBal fail');
        });
    });

    describe('exitPool', async () => {
        it('Call exitPool usdt with insufficient balance should fail', async () => {
            let ktoken=await IERC20.at(smartPoolInstance.address);
            let kTokenBal=await ktoken.balanceOf(accounts[0]);
            await expectRevert(smartPoolInstance.exitPool(kTokenBal.add(new ether('1'))),
                'UniLiquidityVault.exitPool: Insufficient balance',
            );
        });

        it('Call exitPool usdt with zero balance should fail', async () => {
            await expectRevert(smartPoolInstance.exitPool(0),
                'UniLiquidityVault.exitPool: Insufficient balance',
            );
        });

        it('Call exitPool usdt with ktoken should work', async () => {
            let amount=1000000;
            let iusdt=await IERC20.at(usdt);
            let beforeUsdtBal=await iusdt.balanceOf(smartPoolInstance.address);
            await smartPoolInstance.exitPool(amount);
            let afterUsdtBal=await iusdt.balanceOf(smartPoolInstance.address);
            assert.equal(beforeUsdtBal==afterUsdtBal
                ||beforeUsdtBal-afterUsdtBal==amount,true,'exitPool calc fail');
        });

    });

    describe('invest', async () => {

        it('Call invest with usdt balance==0 should fail', async () => {
            let smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            await expectRevert(smartPoolInstance.invest(),
                'UniLiquidityVault.invest: Must be greater than 0 usdt');
            // await expectRevert(smartPoolInstance.invest(),
            //     'UniLiquidityVault.invest: Must be less than balance');
        });
        it('Call invest with usdt balance >0 should fail', async () => {
            let iusdt=await IERC20.at(usdt);
            // let usdtBal=await iusdt.balanceOf(kVaultInstance.address);
            await smartPoolInstance.invest();
            let lpBal=await smartPoolInstance.lpBal();
            assert.notEqual(lpBal.toString(),'0','invest lp update fail');
            let isExtractFee=await smartPoolInstance.isExtractFee();
            assert.equal(isExtractFee,true,'invest isExtractFee update fail');
            let iweth=await IERC20.at(weth);
            let iwbtc=await IERC20.at(wbtc);
            let wethBal=await iweth.balanceOf(smartPoolInstance.address);
            let wbtcBal=await iwbtc.balanceOf(smartPoolInstance.address);
            assert.equal(wethBal==0&&wbtcBal==0,true,'invest clear token fail');
        });
    });

    describe('removeAll', async () => {
        it('Call removeAll usdt with lp >0 should work', async () => {
            await smartPoolInstance.removeAll();
            let lpBal=await smartPoolInstance.lpBal();
            assert.equal(lpBal,0,'lpBal not equal 0 ');
        });
    });

    describe('withdrawFee', async () => {
        it('Call withdrawFee with amount > MAX_USDT_FEE should fail', async () => {
            let smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            await expectRevert(smartPoolInstance.withdrawFee(200000001),
                'UniLiquidityVault.withdrawFee: Must be less than 200 usdt');
        });

        it('Call withdrawFee with isExtractFee=false should fail', async () => {
            let smartPoolInstance = await SmartPool.new();
            smartPoolInstance.init(weth,wbtc,name,symbol);
            await expectRevert(smartPoolInstance.withdrawFee(1),
                'UniLiquidityVault.withdrawFee: Already extracted');
        });
        it('Call withdrawFee with amount > total usdt balance should fail', async () => {
            let iusdt=await IERC20.at(usdt);
            let usdtBal=await iusdt.balanceOf(smartPoolInstance.address);
            await expectRevert(smartPoolInstance.withdrawFee(usdtBal.add(usdtBal)),
                'UniLiquidityVault.withdrawFee: Insufficient balance');
        });
        it('Call withdrawFee with amount <= total usdt balance should work', async () => {
            let iusdt=await IERC20.at(usdt);
            let usdtBal=await iusdt.balanceOf(smartPoolInstance.address);
            await smartPoolInstance.withdrawFee(usdtBal);
        });
    });
});
