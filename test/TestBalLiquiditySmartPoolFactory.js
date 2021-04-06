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
const SmartPoolFactory = artifacts.require('./fund/BalLiquiditySmartPoolFactory');
const ProxyPausable = artifacts.require('./other/ProxyPausable');
const UniswapV2ExpandLibrary=artifacts.require('./libraries/UniswapV2ExpandLibrary');
const UniswapV2ExpandLibraryMock=artifacts.require('./mocks/UniswapV2ExpandLibraryMock');

const name='KF BTC Fund';
const symbol='KFBTC';
const initialSupply=new ether('1000');

contract('BalLiquiditySmartPoolFactory', (accounts) => {

    before(async () => {
        //create lib mock
        let uniswapV2ExpandLibraryInstance= await UniswapV2ExpandLibrary.new();
        await UniswapV2ExpandLibraryMock.link('UniswapV2ExpandLibrary',uniswapV2ExpandLibraryInstance.address);
        this.uniswapV2ExpandLibraryMockInstance=await UniswapV2ExpandLibraryMock.new();
    })

    it('Init factory should work',async()=>{
        //init pool and approve tokens
        let smartPoolFactoryInstance = await SmartPoolFactory.new();
        await smartPoolFactoryInstance.init(balancerFactory);
        let impl=await smartPoolFactoryInstance.smartPoolImplementation();
        assert.notEqual(impl,constants.ZERO_ADDRESS,'init factory failure');
    });

    it('Create smart pool should work ', async () => {
        let wbtcIn= await this.uniswapV2ExpandLibraryMockInstance.getAmountIn(weth,wbtc,amounts[0]);
        let renbtcIn= await this.uniswapV2ExpandLibraryMockInstance.getAmountIn(weth,renbtc,amounts[1]);
        let totalIn=wbtcIn.add(renbtcIn);
        assert.notEqual(totalIn.valueOf(), 0, "TotalAmountIn must be > 0");
        let iweth=await IWETH.at(weth);
        await iweth.deposit({value:totalIn});
        //buyer token
        await iweth.transfer(this.uniswapV2ExpandLibraryMockInstance.address,wbtcIn);
        await this.uniswapV2ExpandLibraryMockInstance.swap(accounts[0],weth,wbtc,wbtcIn,amounts[0]);
        await iweth.transfer(this.uniswapV2ExpandLibraryMockInstance.address,renbtcIn);
        await this.uniswapV2ExpandLibraryMockInstance.swap(accounts[0],weth,renbtc,renbtcIn,amounts[1]);

        //init pool and approve tokens
        let smartPoolFactoryInstance = await SmartPoolFactory.new();
        await smartPoolFactoryInstance.init(balancerFactory);
        let iwbtc=await IERC20.at(wbtc);
        await iwbtc.approve(smartPoolFactoryInstance.address,wbtcIn);
        let irenbtc=await IERC20.at(renbtc);
        await irenbtc.approve(smartPoolFactoryInstance.address,renbtcIn);
        // create pool
        let smartPool=await smartPoolFactoryInstance.newProxiedSmartPool(
            name,symbol,initialSupply,tokens,amounts,weights,initialSupply
        );
        let poolAddress=smartPool.logs[0].args.poolAddress;
        let isPool=await smartPoolFactoryInstance.isPool(poolAddress);
        assert.isTrue(isPool,'Create smart pool fail');
    });
});
