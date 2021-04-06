
const Controller = artifacts.require('./Controller');
const KVault = artifacts.require('./vaults/KVault');
const UniDynamicLiquidityStrategy = artifacts.require('./strategies/UniDynamicLiquidityStrategy');
const ProxyPausable=artifacts.require('./other/ProxyPausable');

const vaultToken = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
const WETH='0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const WBTC='0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';
const UNI='0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984';
const tokens=[vaultToken,WETH,WBTC,UNI];

const name = 'KF Uniswap Liquidity Fund';
const symbol = 'KFUNLF';

module.exports = async function(deployer,network,accounts) {
    let controller;
    await deployer.deploy(Controller).then(function (instance) {
        controller=instance;
    });
    let governance=await controller.getGovernance();
    let kVaultInstance;
    await deployer.deploy(KVault).then(function (instance) {
        kVaultInstance=instance;
    });
    let uniDynamicLiquidityStrategy;
    await deployer.deploy(UniDynamicLiquidityStrategy,controller.address).then(function (instance) {
        uniDynamicLiquidityStrategy=instance;
    });
    await uniDynamicLiquidityStrategy.setUnderlyingTokens(tokens);

    let proxyPausableInstance=await deployer.deploy(ProxyPausable);
    await proxyPausableInstance.setImplementation(kVaultInstance.address);
    await proxyPausableInstance.setPauzer(governance);
    await proxyPausableInstance.setProxyOwner(governance);
    let proxy=await KVault.at(proxyPausableInstance.address);
    await proxy.init(name,symbol,vaultToken);
    await proxy.setFee(0,0,1000,0);
    await proxy.setFee(1,2,1000,0);
    await proxy.setFee(2,2,100,0);
    await proxy.setFee(3,20,100,100e6);
    await proxy.setController(controller.address);
    await controller.register(uniDynamicLiquidityStrategy.address,true);
    await controller.bindVault(proxy.address,uniDynamicLiquidityStrategy.address,0,200);
    console.log(symbol+":"+proxy.address);
};
