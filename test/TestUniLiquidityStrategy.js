const {BN, ether, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');
const TokenHelper = require("../scripts/TokenHelper");

const weth = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const vaultToken = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
const tokenA=weth;
const tokenB='0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';


const name = 'KF BTC-ETH Fund';
const symbol = 'KFBET';

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20');
const UniswapV2ExpandLibrary = artifacts.require('./libraries/UniswapV2ExpandLibrary');
const Controller = artifacts.require('./Controller');
const KVault = artifacts.require('./vaults/KVault');
const Strategy = artifacts.require('./strategies/UniLiquidityStrategy');


contract('UniLiquidityStrategy', (accounts) => {

    let controller;
    let kVaultInstance;
    let strategyInstance;

    let tokenContract;

    let initNumber = 0;
    let MAX_FEE=200;

    before(async () => {
        let uniswapV2ExpandLibraryInstance = await UniswapV2ExpandLibrary.new();
        controller = await Controller.new();
        kVaultInstance = await KVault.new();
        await Strategy.link('UniswapV2ExpandLibrary', uniswapV2ExpandLibraryInstance.address);
        strategyInstance = await Strategy.new(controller.address, tokenA, tokenB);
        await TokenHelper.swapExactOutByUniSwap(vaultToken, accounts[0], 10000000000);
        tokenContract = await IERC20.at(vaultToken);
        await tokenContract.approve(kVaultInstance.address, 10000000000);
    });

    describe('KVault.init', async () => {
        it('Call init with token address = 0x0  should work', async () => {
            await kVaultInstance.init(name, symbol, vaultToken);
            let totalSupply = await kVaultInstance.totalSupply();
            assert.equal(totalSupply, 0, 'KVault.init fail of totalSupply');
            let tokenBal = await tokenContract.balanceOf(kVaultInstance.address);
            assert.equal(tokenBal, 0, 'KVault.init fail of token balance');
        });
        it('Call init with token address != 0x0 should fail', async () => {
            await expectRevert(kVaultInstance.init(name, symbol, vaultToken),
                'KVault.init: already initialised');
        });
    });

    describe('KVault.setFee', async () => {
        it('Call setFee with sender is not governance should fail', async () => {
            await expectRevert(kVaultInstance.setFee(0, 1,1000,0,{from:accounts[1]}),
                'GovIdentity.onlyGovernance: !governance');
        });
        it('Call setFee should work', async () => {
            await kVaultInstance.setFee(0, 0,1000,0);
            await kVaultInstance.setFee(1, 2,1000,0);
            await kVaultInstance.setFee(2, 2,100,0);
            await kVaultInstance.setFee(3, 30,100,100e6);
            let fee0=await kVaultInstance.getFee(0);
            let fee1=await kVaultInstance.getFee(1);
            let fee2=await kVaultInstance.getFee(2);
            let fee3=await kVaultInstance.getFee(3);
            assert.equal(fee0[0]==0,fee0[1]==1000,'KVault.setFee fail of fee0');
            assert.equal(fee1[0]==2,fee1[1]==1000,'KVault.setFee fail of fee1');
            assert.equal(fee2[0]==2,fee2[1]==100,'KVault.setFee fail of fee2');
            assert.equal(fee3[0]==30,fee2[1]==100,'KVault.setFee fail of fee3');
        });
    });
    describe('KVault.transferCash', async () => {
        it('Call transferCash with sender is not controller should fail', async () => {
            await expectRevert(kVaultInstance.transferCash(accounts[0], 1),
                'BasicSmartPoolV2.onlyController: not controller');
        });
    });

    describe('KVault.setController', async () => {
        it('Call setController with sender is not governance should fail', async () => {
            await expectRevert(kVaultInstance.setController(controller.address, {from: accounts[1]}),
                'GovIdentity.onlyGovernance: !governance');
        });
        it('Call setController with sender is governance should work', async () => {
            await kVaultInstance.setController(controller.address);
            let controllerAddr = await kVaultInstance.getController();
            assert.equal(controllerAddr, controller.address, 'KVault.setController fail');
        });
    });

    describe('Controller.register', async () => {
        it('Call register with unauthorized account should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.register(strategyInstance.address, true, {from: accounts[1]}),
                'GovIdentity.onlyGovernance: !governance and !strategist');
        });
        it('Call register with authorized account should work', async () => {
            await controller.register(strategyInstance.address, true);
            let value = await controller.inRegister(strategyInstance.address);
            assert.equal(value, true, 'Controller.register fail');
        });
    });

    describe('Controller.exec', async () => {
        it('Call exec with not binding vault should fail', async () => {
            let controller = await Controller.new();
            let signature='balanceOf(address)';
            let data=web3.eth.abi.encodeParameters(['address'],[accounts[0]]);
            await expectRevert(controller.exec(strategyInstance.address,true,1,signature,data),
                'Controller.exec: strategy is not binding vault');
        });
    });

    describe('Controller.bindVault', async () => {
        it('Call bindVault with unauthorized account should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.bindVault(kVaultInstance.address, strategyInstance.address, 1, 1, {from: accounts[1]}),
                'GovIdentity.onlyGovernance: !governance and !strategist');
        });

        it('Call bindVault with unregistered should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.bindVault(kVaultInstance.address, strategyInstance.address, 1, 1),
                'Controller.bindVault: _strategy is not registered');
        });

        it('Call bindVault with authorized account and registered should work', async () => {
            await tokenContract.approve(controller.address,initNumber);
            await controller.bindVault(kVaultInstance.address, strategyInstance.address, initNumber, MAX_FEE);
            let vault = await controller.vaults(strategyInstance.address);
            let strategy = await controller.strategies(kVaultInstance.address);
            let maxFee = await controller.maxFee(kVaultInstance.address);
            let withdrawFeeStatus = await controller.withdrawFeeStatus(kVaultInstance.address);
            let assets = await strategyInstance.assets();
            let sbalance=await tokenContract.balanceOf(strategy);
            let cbalance=await tokenContract.balanceOf(controller.address);
            assert.equal(sbalance, 0, 'Controller.bindVault fail of strategy balance');
            assert.equal(cbalance, 0, 'Controller.bindVault fail of controller balance');
            assert.equal(assets, 0, 'Controller.bindVault fail of assets');
            assert.equal(vault, kVaultInstance.address, 'Controller.bindVault fail of vault');
            assert.equal(strategy, strategyInstance.address, 'Controller.bindVault fail of strategy');
            assert.equal(maxFee.toString(), MAX_FEE, 'Controller.bindVault fail of maxFee');
            assert.equal(withdrawFeeStatus, true, 'Controller.bindVault fail of withdrawFeeStatus');
        });
    });

    describe('KVault.calc', async () => {
        it('Call calcKfToToken kf total with zero should work', async () => {
            let kfInput = 1000000;
            let tokenAmount = await kVaultInstance.calcKfToToken(kfInput);
            assert.notEqual(tokenAmount.valueOf(), 0, 'KVault.calcKfToToken fail');
        });
        it('Call calcTokenToKf token total with zero should work', async () => {
            let tokenAmount = 1000000;
            let kfOut = await kVaultInstance.calcTokenToKf(tokenAmount);
            assert.notEqual(kfOut.valueOf(), 0, 'KVault.calcTokenToKf fail');
        });
    });
    describe('KVault.joinPool', async () => {
        it('Call joinPool token with insufficient balance should fail', async () => {
            let tokenBal=await tokenContract.balanceOf(accounts[0]);
            await expectRevert(kVaultInstance.joinPool(tokenBal.add(new ether('1'))),
                'KVault.joinPool: Insufficient balance',
            );
        });
        it('Call joinPool token with 1 balance should work', async () => {
            let tokenAmount=1000000000;
            let kBalBefore=await kVaultInstance.balanceOf(accounts[0]);
            let totalSupplyBefore=await kVaultInstance.totalSupply();
            let tokenBalBefore=await tokenContract.balanceOf(kVaultInstance.address);
            let preShare=await kVaultInstance.calcTokenToKf(tokenAmount);
            await kVaultInstance.joinPool(tokenAmount);
            let kBalAfter=await kVaultInstance.balanceOf(accounts[0]);
            let totalSupplyAfter=await kVaultInstance.totalSupply();
            let tokenBalAfter=await tokenContract.balanceOf(kVaultInstance.address);
            assert.equal(preShare,tokenAmount,'KVault.joinPool fail of pre share 1');
            assert.equal(kBalAfter-kBalBefore,preShare,'KVault.joinPool fail of pre share 2');
            assert.equal(totalSupplyAfter-totalSupplyBefore,kBalAfter-kBalBefore,'KVault.joinPool fail of totalSupply');
            assert.equal(tokenBalAfter-tokenBalBefore,tokenAmount,'KVault.joinPool fail of token balance');
        });
    });
    describe('KVault.exitPool', async () => {
        it('Call exitPool token with insufficient balance should fail', async () => {
            let ktoken=await IERC20.at(kVaultInstance.address);
            let kTokenBal=await ktoken.balanceOf(accounts[0]);
            await expectRevert(kVaultInstance.exitPool(kTokenBal.add(new ether('1'))),
                'KVault.exitPool: Insufficient balance',
            );
        });

        it('Call exitPool token with zero balance should fail', async () => {
            await expectRevert(kVaultInstance.exitPool(0),
                'KVault.exitPool: Insufficient balance',
            );
        });

        it('Call exitPool token with ktoken should work', async () => {
            let amount=90000000;
            let kBalBefore=await kVaultInstance.balanceOf(accounts[0]);
            let tokenBalBefore=await tokenContract.balanceOf(accounts[0]);
            let fee=await kVaultInstance.calcJoinAndExitFee(1,amount);
            let mfee=await kVaultInstance.calcManagementFee(amount);
            let preToken=await kVaultInstance.calcKfToToken(amount-fee);
            await kVaultInstance.exitPool(amount);
            let kBalAfter=await kVaultInstance.balanceOf(accounts[0]);
            let tokenBalAfter=await tokenContract.balanceOf(accounts[0]);
            assert.equal(tokenBalAfter-tokenBalBefore,preToken,'KVault.exitPool fail of token balance'+preToken);
            // assert.equal(kBalBefore-kBalAfter-mfee,amount-fee,'KVault.exitPool fail of of ktoken balance');
        });
    });
    describe('Controller.invest', async () => {
        it('Call invest with unregistered should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.invest(kVaultInstance.address,1),
                'Controller.invest: vault is not binding strategy');
        });
        it('Call invest with registered should work', async () => {
            let tokenAmount=await tokenContract.balanceOf(kVaultInstance.address);
            await controller.invest(kVaultInstance.address,tokenAmount);
            let assets=await kVaultInstance.assets();
            let lp=await strategyInstance.liquidityBalance();
            assert.notEqual(lp,new BN('0'),'Controller.harvestAll fail of lp');
            assert.notEqual(assets,0,'Controller.invest fail of assets');
            let withdrawFeeStatus=await controller.withdrawFeeStatus(kVaultInstance.address);
            assert.equal(withdrawFeeStatus,true,'Controller.invest fail of withdrawFeeStatus');
            let iweth=await IERC20.at(weth);
            let wethBal=await iweth.balanceOf(strategyInstance.address);
            let tokenBal=await tokenContract.balanceOf(strategyInstance.address);
            assert.equal(wethBal,0,'Controller.invest fail of weth balance');
            assert.equal(tokenBal,0,'Controller.invest fail of token balance');
        });
    });
    describe('KVault.exitPoolOfUnderlying', async () => {
        it('Call exitPoolOfUnderlying token with insufficient balance should fail', async () => {
            let ktoken=await IERC20.at(kVaultInstance.address);
            let kTokenBal=await ktoken.balanceOf(accounts[0]);
            await expectRevert(kVaultInstance.exitPoolOfUnderlying(kTokenBal.add(new ether('1'))),
                'KVault.exitPoolOfUnderlying: Insufficient balance',
            );
        });

        it('Call exitPoolOfUnderlying token with zero balance should fail', async () => {
            await expectRevert(kVaultInstance.exitPoolOfUnderlying(0),
                'KVault.exitPoolOfUnderlying: Insufficient balance',
            );
        });

        it('Call exitPoolOfUnderlying token with ktoken should work', async () => {
            let amount=190000000;
            await kVaultInstance.exitPoolOfUnderlying(amount);
            let tokens=[tokenA,tokenB];
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                let symbol=await token.symbol();
                let bal=await token.balanceOf(accounts[0]);
                assert.notEqual(bal,0,"KVault.exitPoolOfUnderlying fail of "+symbol+" balance");
            }
        });
    });

    describe('KVault.chargeFee', async () => {

        it('Call chargeOutstandingManagementFee with sender is not governance should fail', async () => {
            await expectRevert(kVaultInstance.chargeOutstandingManagementFee({from:accounts[1]}),
                'GovIdentity.onlyGovernance: !governance');
        });

        it('Call chargeOutstandingManagementFee should work', async () => {
            let totalSupplyBefore=await kVaultInstance.totalSupply();
            let fee=await kVaultInstance.calcManagementFee(totalSupplyBefore);
            await kVaultInstance.chargeOutstandingManagementFee();
            let totalSupplyAfter=await kVaultInstance.totalSupply();
            assert.equal((totalSupplyAfter-totalSupplyBefore)>=fee,true,
                'KVault.chargeOutstandingManagementFee fail of fee');
        });

        it('Call chargeOutstandingPerformanceFee with sender is not governance should fail', async () => {
            await expectRevert(kVaultInstance.chargeOutstandingPerformanceFee(accounts[0],{from:accounts[1]}),
                'GovIdentity.onlyGovernance: !governance');
        });

        it('Call chargeOutstandingPerformanceFee should work', async () => {
            let net = await kVaultInstance.calcKfToToken(new ether('1'));
            let totalSupplyBefore=await kVaultInstance.totalSupply();
            let fee=await kVaultInstance.calcPerformanceFee(accounts[0],net);
            await kVaultInstance.chargeOutstandingPerformanceFee(accounts[0]);
            let totalSupplyAfter=await kVaultInstance.totalSupply();
            assert.equal((totalSupplyAfter-totalSupplyBefore).toString(),fee.toString(),
                'KVault.chargeOutstandingPerformanceFee fail of fee');
        });
    });


    describe('Controller.harvest', async () => {
        it('Call harvest with sender is not vault should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.harvest(1),
                'Controller.harvest: sender is not vault');
        });
        it('Call harvestAll with unauthorized account should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.harvestAll(kVaultInstance.address,{from:accounts[1]}),
                'GovIdentity.onlyGovernance: !governance and !strategist');
        });
        it('Call harvestAll with sender is not vault should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.harvestAll(kVaultInstance.address),
                'Controller.harvestAll: vault is not binding strategy');
        });
        it('Call harvestAll should work', async () => {
            await controller.harvestAll(kVaultInstance.address);
            let lp=await strategyInstance.liquidityBalance();
            assert.equal(lp,0,'Controller.harvestAll fail of lp');
            let tokens=[tokenA,tokenB];
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                let bal=await token.balanceOf(strategyInstance.address);
                assert.equal(bal,0,'Controller.harvestAll fail of token balance');
            }
            let assets=await strategyInstance.assets();
            assert.notEqual(assets,new BN('0'),'Controller.harvestAll fail of assets');
        });
    });

    describe('Controller.withdrawMinnerFee', async () => {
        it('Call withdrawMinnerFee with unbind vault should fail', async () => {
            let controller = await Controller.new();
            await expectRevert(controller.withdrawMinnerFee(kVaultInstance.address, 1),
                'Controller.withdrawMinnerFee: max fee == 0');
        });
        it('Call withdrawMinnerFee with amount > max fee should fail', async () => {
            let maxFee=await controller.maxFee(kVaultInstance.address);
            await expectRevert(controller.withdrawMinnerFee(kVaultInstance.address, maxFee.add(new ether('1'))),
                'Controller.withdrawMinnerFee: Must be less than max fee');
        });
        it('Call withdrawMinnerFee with 1 should work', async () => {
            await controller.withdrawMinnerFee(kVaultInstance.address, 1);
            let withdrawFeeStatus=await controller.withdrawFeeStatus(kVaultInstance.address);
            assert.equal(withdrawFeeStatus,false,'Controller.withdrawMinnerFee fail of withdrawFeeStatus');
        });
        it('Call withdrawMinnerFee with withdraw Fee status=false should fail', async () => {
            await expectRevert(controller.withdrawMinnerFee(kVaultInstance.address, 1),
                'Controller.withdrawMinnerFee: Already extracted');
        });
    });
    describe('Strategy.init', async () => {
        it('Call init with already initialized should fail', async () => {
            await expectRevert(strategyInstance.init(),
                'Strategy.init: already initialised');
        });
        it('Call init with sender is not controller should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokenA, tokenB);
            await expectRevert(strategyInstance.init(),
                'Strategy.init: !controller');
        });
    });
    describe('Strategy.approveTokens', async () => {
        it('Call approveTokens with uninitialized should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokenA, tokenB);
            await expectRevert(strategyInstance.approveTokens(),
                'Strategy.approveTokens: not initialised');
        });
        it('Call approveTokens with initialized should work', async () => {
            await strategyInstance.approveTokens();
        });
    });

});
