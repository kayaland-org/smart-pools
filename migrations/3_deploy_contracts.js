const UniLiquidityVault=artifacts.require('./vaults/UniLiquidityVault');
const ProxyPausable=artifacts.require('./other/ProxyPausable');

const weth='0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const wbtc='0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';

const name = 'KF BTC-ETH Fund';
const symbol = 'KFBET';

module.exports = async function(deployer,network,accounts) {
    // let uniLiquidityVaultInstance;
    // await deployer.deploy(UniLiquidityVault).then(function (instance) {
    //     uniLiquidityVaultInstance=instance;
    // });
    // let proxyPausableInstance=await deployer.deploy(ProxyPausable);
    // await proxyPausableInstance.setImplementation(uniLiquidityVaultInstance.address);
    // await proxyPausableInstance.setPauzer(accounts[0]);
    // await proxyPausableInstance.setProxyOwner(accounts[0]);
    // let proxy=await UniLiquidityVault.at(proxyPausableInstance.address);
    // await proxy.init(weth,wbtc,name,symbol);
    // await proxy.setJoinFeeRatio(1,1000);
    // await proxy.setExitFeeRatio(2,1000);
    // console.log(symbol+":"+proxyPausableInstance.address);
};
