const {ether,constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const balancerFactory='0x9424B1412450D0f8Fc2255FAf6046b98213B76Bd';
const weth='0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const wbtc='0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';
const renbtc='0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D';

const tokens=[wbtc,renbtc];
const amounts=[5096947,1274136];
const weights=[new ether('40'),new ether('10')];

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/IERC20');
const IWETH = artifacts.require('./interfaces/weth/IWETH');
const IBFactory = artifacts.require('./interfaces/balancer/IBFactory');
const SmartPool = artifacts.require('./fund/BalLiquiditySmartPool');
const UniswapV2ExpandLibrary=artifacts.require('./libraries/UniswapV2ExpandLibrary');
const UniswapV2ExpandLibraryMock=artifacts.require('./mocks/UniswapV2ExpandLibraryMock');

const name='KF BTC Fund';
const symbol='KFBTC';
const initialSupply=new ether('1000');

contract('BalLiquiditySmartPool', (accounts) => {

    let smartPoolInstance;
    let bPool;

    before(async () => {
        //create lib mock
        let uniswapV2ExpandLibraryInstance= await UniswapV2ExpandLibrary.new();
        await UniswapV2ExpandLibraryMock.link('UniswapV2ExpandLibrary',uniswapV2ExpandLibraryInstance.address);
        this.uniswapV2ExpandLibraryMockInstance=await UniswapV2ExpandLibraryMock.new();
        let IBFactoryInstance=await IBFactory.at(balancerFactory);
        let receipt=await IBFactoryInstance.newBPool();
        bPool=receipt.receipt.rawLogs[1].address;
    });

    describe('init', async () => {
        it('Call Initialising with invalid bPool address should fail', async () => {
            smartPoolInstance = await SmartPool.new();
            await expectRevert(smartPoolInstance.init(constants.ZERO_ADDRESS,name,symbol,initialSupply),
                'BalLiquiditySmartPool.init: bPool cannot be 0x00....000',
            );
        });

        it("Call Initialising with zero supply should fail", async () => {
            smartPoolInstance = await SmartPool.new();
            await expectRevert(smartPoolInstance.init(bPool, name, symbol,0),'BalLiquiditySmartPool.init: initialSupply can not zero');
        });

        it("Call Initialising with 1000 supply should work", async () => {
            smartPoolInstance = await SmartPool.new();
            let receipt=await smartPoolInstance.init(bPool, name, symbol,initialSupply);
            await expectEvent(receipt,'PoolJoined',{sender:accounts[0],to:accounts[0],amount:initialSupply});
        });

        it("Call Token symbol should be correct", async () => {
            const _name = await smartPoolInstance.name();
            expect(_name).to.eq(name);
        });

        it("Call Token name should be correct", async () => {
            const _symbol = await smartPoolInstance.symbol();
            expect(_symbol).to.eq(symbol);
        });

        it("Call Initial supply should be correct", async () => {
            const _initialSupply = await smartPoolInstance.totalSupply();
            expect(_initialSupply.toString()).to.eq(initialSupply.toString());
        });

        it("Call Controller should be correctly set", async () => {
            const controller = await smartPoolInstance.getController();
            expect(controller).to.eq(accounts[0]);
        });

        it("Call Public swap setter should be correctly set", async () => {
            const publicSwapSetter = await smartPoolInstance.getPublicSwapSetter();
            expect(publicSwapSetter).to.eq(accounts[0]);
        });

        it("Call Token binder should be correctly set", async () => {
            const tokenBinder = await smartPoolInstance.getTokenBinder();
            expect(tokenBinder).to.eq(accounts[0]);
        });

        it("Call bPool should be correctly set", async () => {
            const _bPool = await smartPoolInstance.getBPool();
            expect(_bPool).to.eq(bPool);
        });

        // it("Call Tokens should be correctly set", async () => {
        //     const actualTokens = await smartPoolInstance.getTokens();
        //     expect(actualTokens[0]).to.eql(tokens[0]);
        //     expect(actualTokens[1]).to.eql(tokens[1]);
        // });

        // it("Call calcTokensForAmount should work", async () => {
        //     const amountAndTokens = await smartPoolInstance.calcTokensForAmount(new ether('1'));
        //     expect(amountAndTokens[0]).to.eql(tokens[0]);
        //     expect(amountAndTokens[1]).to.eql(amounts[1]);
        // });

        it("Call init when already initialized should fail", async () => {
            await expectRevert(smartPoolInstance.init(bPool, name, symbol, new ether('1')),'BalLiquiditySmartPool.init: already initialised');
        });
    });


});
