const {ether} = require('@openzeppelin/test-helpers');
const TokenHelper = require("../scripts/TokenHelper");

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/IERC20');
const Controller = artifacts.require('./Controller');
const KVault = artifacts.require('./vaults/KVault');
const BalLiquidityStrategy = artifacts.require('./strategies/BalLiquidityStrategy');
const ProxyPausable=artifacts.require('./other/ProxyPausable');


const tokens = ['0x514910771AF9Ca656af840dff83E8264EcF986CA', '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984'
    , '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9', '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2',
    '0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828', '0xc00e94Cb662C3520282E6f5717214004A7f26888',
    '0xc944E90C64B2c07662A292be6244BDf05Cda44a7', '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e'];

const weights = [new ether('5'), new ether('9'), new ether('9.5'), new ether('9')
    , new ether('5'), new ether('6.5'), new ether('3'), new ether('3')];

const amounts = [new ether('0.400000'), new ether('0.785340'), new ether('0.051419'), new ether('1.118012')
    , new ether('0.488043'), new ether('0.031218'), new ether('3.636364'), new ether('0.000185')];

const vaultToken = '0xdAC17F958D2ee523a2206206994597C13D831ec7';

const name = 'KF DeFi Pioneer Fund';
const symbol = 'KFDFPF';
const initNumber = 200000000;

module.exports = async function(deployer,network,accounts) {
    // let controller;
    // await deployer.deploy(Controller).then(function (instance) {
    //     controller=instance;
    // });
    // let governance=await controller.getGovernance();
    // let kVaultInstance;
    // await deployer.deploy(KVault).then(function (instance) {
    //     kVaultInstance=instance;
    // });
    // let balLiquidityStrategyInstance;
    // await deployer.deploy(BalLiquidityStrategy,controller.address, tokens, weights, amounts).then(function (instance) {
    //     balLiquidityStrategyInstance=instance;
    // });
    // let tokenContract = await IERC20.at(vaultToken);
    // await TokenHelper.swapExactOut(vaultToken, governance, initNumber);
    // await tokenContract.approve(controller.address, initNumber);
    // let proxyPausableInstance=await deployer.deploy(ProxyPausable);
    // await proxyPausableInstance.setImplementation(kVaultInstance.address);
    // await proxyPausableInstance.setPauzer(governance);
    // await proxyPausableInstance.setProxyOwner(governance);
    // let proxy=await KVault.at(proxyPausableInstance.address);
    // await proxy.init(name,symbol,vaultToken);
    // await proxy.setFee(0,0,1000,0);
    // await proxy.setFee(1,2,1000,0);
    // await proxy.setFee(2,2,100,0);
    // await proxy.setController(controller.address);
    // await controller.register(balLiquidityStrategyInstance.address,true);
    // let signature='newBPool()';
    // let data=web3.eth.abi.encodeParameters([],[]);
    // await controller.exec(balLiquidityStrategyInstance.address,false,0,signature,data);
    // await controller.bindVault(proxy.address,balLiquidityStrategyInstance.address,initNumber,200);
    // console.log(symbol+":"+proxy.address);
};
