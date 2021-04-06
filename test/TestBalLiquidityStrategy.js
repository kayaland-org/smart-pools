const {BN, ether, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');
const TokenHelper = require("../scripts/TokenHelper");

const tokens = ['0x514910771AF9Ca656af840dff83E8264EcF986CA', '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984'
    , '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9', '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2',
    '0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828', '0xc00e94Cb662C3520282E6f5717214004A7f26888',
    '0xc944E90C64B2c07662A292be6244BDf05Cda44a7', '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e'];

const weights = [new ether('5'), new ether('9'), new ether('9.5'), new ether('9')
    , new ether('5'), new ether('6.5'), new ether('3'), new ether('3')];

const amounts = [new ether('0.4074979625'), new ether('0.9814612868'), new ether('0.03978890937'), new ether('1.3814274751')
    , new ether('0.3546099291'), new ether('0.02894549341'), new ether('6.2731649686'), new ether('0.0001961397731')];

const weth = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const vaultToken = '0xdAC17F958D2ee523a2206206994597C13D831ec7';

const name = 'KF DeFi Pioneer Fund';
const symbol = 'KFDFPF';

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20');
const UniswapV2ExpandLibrary = artifacts.require('./libraries/UniswapV2ExpandLibrary');
const Controller = artifacts.require('./Controller');
const KVault = artifacts.require('./vaults/KVault');
const Strategy = artifacts.require('./strategies/BalLiquidityStrategy');


contract('BalLiquidityStrategy', (accounts) => {

    let controller;
    let kVaultInstance;
    let strategyInstance;

    let tokenContract;

    let initNumber = 200000000;
    let MAX_FEE=200;
    let initShare=new ether('1');
    before(async () => {
        let uniswapV2ExpandLibraryInstance = await UniswapV2ExpandLibrary.new();
        controller = await Controller.new();
        kVaultInstance = await KVault.new();
        await Strategy.link('UniswapV2ExpandLibrary', uniswapV2ExpandLibraryInstance.address);
        strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
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
            await kVaultInstance.setFee(3, 20,100,100e6);
            let fee0=await kVaultInstance.getFee(0);
            let fee1=await kVaultInstance.getFee(1);
            let fee2=await kVaultInstance.getFee(2);
            assert.equal(fee0[0]==0,fee0[1]==1000,'KVault.setFee fail of fee0');
            assert.equal(fee1[0]==2,fee1[1]==1000,'KVault.setFee fail of fee1');
            assert.equal(fee2[0]==5,fee2[1]==1000,'KVault.setFee fail of fee2');
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
    describe('Strategy.newBPool', async () => {
        it('Call newBPool with sender is not controller should fail', async () => {
            let controller = await Controller.new();
            let signature='newBPool()';
            let data=web3.eth.abi.encodeParameters([],[]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });
        it('Call newBPool with sender bPool=0x0 should work', async () => {
            let signature='newBPool()';
            let data=web3.eth.abi.encodeParameters([],[]);
            await controller.exec(strategyInstance.address,false,0,signature,data);
        });
        it('Call newBPool with sender bPool!=0x0 should fail', async () => {
            let signature='newBPool()';
            let data=web3.eth.abi.encodeParameters([],[]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
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
            let totalSupply=await strategyInstance.totalSupply();
            let sbalance=await tokenContract.balanceOf(strategy);
            let cbalance=await tokenContract.balanceOf(controller.address);
            assert.equal(totalSupply.toString(), initShare.toString(), 'Controller.bindVault fail of strategy totalSupply');
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
            let net=await kVaultInstance.getNet(accounts[0]);
            assert.equal(net,1e18,'KVault.joinPool fail of net'+net);
            assert.equal(preShare,tokenAmount,'KVault.joinPool fail of pre share 1');
            assert.equal(kBalAfter-kBalBefore,preShare,'KVault.joinPool fail of pre share 2');
            assert.equal(totalSupplyAfter-totalSupplyBefore,kBalAfter-kBalBefore,'KVault.joinPool fail of totalSupply');
            assert.equal(tokenBalAfter-tokenBalBefore,tokenAmount,'KVault.joinPool fail of token balance');
        });
    });
    describe('KVault.transfer', async () => {
        it('Call transfer should work', async () => {
            let ktoken=await IERC20.at(kVaultInstance.address);
            let before=await ktoken.balanceOf(accounts[0]);
            let net=await kVaultInstance.getNet(accounts[0]);
            assert.notEqual(net,0,'KVault.transfer fail of net')
            await kVaultInstance.transfer(accounts[1],0);
            await kVaultInstance.transfer(accounts[1],before);
             net=await kVaultInstance.getNet(accounts[0]);
            assert.equal(net,0,'KVault.transfer fail of net')
            let after=await ktoken.balanceOf(accounts[0]);
            assert.equal(after,0,'KVault.transfer fail of account0 balance');
            let balance=await ktoken.balanceOf(accounts[1]);
            assert.equal(balance.toString(),before.toString(),'KVault.transferFrom fail of account1 balance');
        });

        it('Call transferFrom should work', async () => {
            let ktoken=await IERC20.at(kVaultInstance.address);
            let before=await ktoken.balanceOf(accounts[1]);
            let net=await kVaultInstance.getNet(accounts[1]);
            assert.notEqual(net,0,'KVault.transferFrom fail of net')
            await kVaultInstance.transferFrom(accounts[1],accounts[0],0,{from:accounts[1]});
            await kVaultInstance.transferFrom(accounts[1],accounts[0],before,{from:accounts[1]});
            net=await kVaultInstance.getNet(accounts[1]);
            assert.equal(net,0,'KVault.transfer fail of net')
            let after=await ktoken.balanceOf(accounts[1]);
            assert.equal(after,0,'KVault.transferFrom fail of account1 balance');
            let balance=await ktoken.balanceOf(accounts[0]);
            assert.equal(balance.toString(),before.toString(),'KVault.transferFrom fail of account0 balance');
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
            assert.equal(tokenBalAfter-tokenBalBefore,preToken,'KVault.exitPool fail of token balance');
            // assert.equal(kBalBefore-kBalAfter,amount-fee-mfee,'KVault.exitPool fail of of ktoken balance');
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
            let totalSupplyBefore=await strategyInstance.totalSupply();
            await controller.invest(kVaultInstance.address,tokenAmount);
            let totalSupplyAfter=await strategyInstance.totalSupply();
            assert.notEqual(totalSupplyAfter-totalSupplyBefore,0,'Controller.invest fail of totalSupply');
            let withdrawFeeStatus=await controller.withdrawFeeStatus(kVaultInstance.address);
            assert.equal(withdrawFeeStatus,true,'Controller.invest fail of withdrawFeeStatus');
            let assets=await kVaultInstance.assets();
            assert.notEqual(assets,0,'Controller.invest fail of assets');
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
            assert.notEqual(fee,0,'KVault.chargeOutstandingPerformanceFee fail of fee');
            await kVaultInstance.chargeOutstandingPerformanceFee(accounts[0]);
            let totalSupplyAfter=await kVaultInstance.totalSupply();
            assert.equal(totalSupplyBefore,totalSupplyAfter.toString(),
                'KVault.chargeOutstandingPerformanceFee fail of totalSupply');
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
            let totalSupply=await strategyInstance.totalSupply();
            assert.equal(totalSupply.toString(),initShare.toString(),'Controller.harvestAll fail of totalSupply');
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                let bal=await token.balanceOf(strategyInstance.address);
                assert.equal(bal,0,'Controller.harvestAll fail of token balance');
            }
            let assets=await strategyInstance.assets();
            assert.notEqual(assets,new BN('0'),'Controller.harvestAll fail of assets');
        });
        it('Call harvestAll with totalSupply=1 should fail', async () => {
            await expectRevert(controller.harvestAll(kVaultInstance.address),
                'Strategy.withdrawAll: Must be greater than the number of initializations');
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
        it('Call init with sender is not controller should fail', async () => {
            await expectRevert(strategyInstance.init(),
                'Strategy.init: !controller');
        });
        it('Call init with not newBPool should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            let signature='init()';
            let data=web3.eth.abi.encodeParameters([],[]);
            let newController=await Controller.new();
            await expectRevert(newController.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });

        it('Call init with already initialised should fail', async () => {
            let signature='init()';
            let data=web3.eth.abi.encodeParameters([],[]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });

    });

    describe('Strategy.approveTokens', async () => {
        it('Call approveTokens with uninitialized should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            await expectRevert(strategyInstance.approveTokens(),
                'Strategy.approveTokens: not initialised');
        });
        it('Call approveTokens with initialized should work', async () => {
            await strategyInstance.approveTokens();
        });
    });

    describe('Strategy.unbind and bind by controller', async () => {
        it('Call bind with sender is not controller should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            await expectRevert(strategyInstance.bind(tokens[0],amounts[0],weights[0]),
                'Strategy.bind: !controller');
        });
        it('Call bind with uninitialized should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            let signature='bind(address,uint256,uint256)';
            let data=web3.eth.abi.encodeParameters(['address','uint256','uint256'],[tokens[0],amounts[0].toString(),weights[0].toString()]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });
        it('Call bind with token is bound should fail', async () => {
            let signature='bind(address,uint256,uint256)';
            let data=web3.eth.abi.encodeParameters(['address','uint256','uint256'],[tokens[0],amounts[0].toString(),weights[0].toString()]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });

        it('Call unbind with sender is not controller should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            await expectRevert(strategyInstance.unbind(tokens[0]),
                'Strategy.unbind: !controller');
        });
        it('Call unbind with uninitialized should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            let signature='unbind(address)';
            let data=web3.eth.abi.encodeParameters(['address'],[tokens[0]]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });
        it('Call unbind with initialized should work', async () => {
            let signature='unbind(address)';
            let data=web3.eth.abi.encodeParameters(['address'],[tokens[0]]);
            await controller.exec(strategyInstance.address,false,0,signature,data);
        });

        it('Call rebind with sender is not controller should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            await expectRevert(strategyInstance.rebind(tokens[0],amounts[0],weights[0]),
                'Strategy.rebind: !controller');
        });
        it('Call rebind with token is not bound should fail', async () => {
            let signature='rebind(address,uint256,uint256)';
            let data=web3.eth.abi.encodeParameters(['address','uint256','uint256'],[tokens[0],amounts[0].toString(),weights[0].toString()]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });
        it('Call bind with token is not bound should work', async () => {
            let signature='bind(address,uint256,uint256)';
            let data=web3.eth.abi.encodeParameters(['address','uint256','uint256'],[tokens[0],amounts[0].toString(),weights[0].toString()]);
            let balance=await tokenContract.balanceOf(kVaultInstance.address);
            await controller.exec(strategyInstance.address,true,balance,signature,data);
        });
        it('Call rebind with uninitialized should fail', async () => {
            let strategyInstance = await Strategy.new(controller.address, tokens, weights, amounts);
            let signature='rebind(address,uint256,uint256)';
            let data=web3.eth.abi.encodeParameters(['address','uint256','uint256'],[tokens[0],amounts[0].toString(),weights[0].toString()]);
            await expectRevert(controller.exec(strategyInstance.address,false,0,signature,data),
                'Controller::exec: Transaction execution reverted');
        });

        it('Call rebind with token is bound should work', async () => {
            let token = await IERC20.at(tokens[0]);
            let bPool=await strategyInstance.bPool();
            let tokenBalance=await token.balanceOf(bPool);
            let newAmount=tokenBalance.add(new ether('1'));
            let signature='rebind(address,uint256,uint256)';
            let data=web3.eth.abi.encodeParameters(['address','uint256','uint256'],[tokens[0],newAmount.toString(),weights[0].toString()]);
            await kVaultInstance.joinPool(new BN('100000000'));
            let balance=await tokenContract.balanceOf(kVaultInstance.address);
            await controller.exec(strategyInstance.address,true,balance,signature,data);
        });
    });
});
