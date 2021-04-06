const {BN, ether, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');
const TokenHelper = require("../scripts/TokenHelper");
const EvmHelper = require( "../scripts/EvmHelper" );

const curve_seth_pool='0xc5424B857f758E906013F3555Dad202e4bdB4567';
const vaultToken = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
const WETH='0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const WBTC='0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';
const UNI='0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984';
const sETH='0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb';
const sBTC='0xfE18be6b3Bd88A2D2A7f928d00292E7a9963CfC6';
const tokens=[vaultToken,WETH,WBTC,UNI];

const name = 'KF BTC-ETH Fund';
const symbol = 'KFBET';

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20');
const UniswapV2ExpandLibrary = artifacts.require('./libraries/UniswapV2ExpandLibrary');
const UniswapV2ExpandLibraryMock = artifacts.require('./mocks/UniswapV2ExpandLibraryMock');
const Controller = artifacts.require('./Controller');
const KVault = artifacts.require('./vaults/KVault');
const Strategy = artifacts.require('./strategies/UniDynamicLiquidityStrategy');


contract('UniDynamicLiquidityStrategy', (accounts) => {

    let controller;
    let kVaultInstance;
    let strategyInstance;

    let tokenContract;

    let initNumber = 0;
    let MAX_FEE=200;

    before(async () => {
        let uniswapV2ExpandLibraryInstance = await UniswapV2ExpandLibrary.new();
        await UniswapV2ExpandLibraryMock.link('UniswapV2ExpandLibrary', uniswapV2ExpandLibraryInstance.address);
        this.uniswapV2ExpandLibraryMockInstance=await UniswapV2ExpandLibraryMock.new();
        controller = await Controller.new();
        kVaultInstance = await KVault.new();
        await Strategy.link('UniswapV2ExpandLibrary', uniswapV2ExpandLibraryInstance.address);
        strategyInstance = await Strategy.new(controller.address);
        await TokenHelper.swapExactOutByUniSwap(vaultToken, accounts[0], 100000000000);
        tokenContract = await IERC20.at(vaultToken);
        await tokenContract.approve(kVaultInstance.address, 100000000000);
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
            assert.equal(fee3[0]==30,fee3[1]==100,'KVault.setFee fail of fee3');
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
            let tokenAmount=50000000000;
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
            let amount=11000000;
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
            assert.equal(assets.toString(),tokenAmount.toString(),'Controller.invest fail of assets,'+assets+","+tokenAmount);
            let withdrawFeeStatus=await controller.withdrawFeeStatus(kVaultInstance.address);
            assert.equal(withdrawFeeStatus,true,'Controller.invest fail of withdrawFeeStatus');
            let tokenBal=await tokenContract.balanceOf(strategyInstance.address);
            assert.equal(tokenBal.toString(),tokenAmount.toString(),'Controller.invest fail of token balance'+tokenBal);
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
            let beforeBal=[];
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                beforeBal[i]=await token.balanceOf(accounts[0]);
            }
            await kVaultInstance.exitPoolOfUnderlying(amount);
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                let symbol=await token.symbol();
                let bal=await token.balanceOf(accounts[0]);
                assert.equal((bal-beforeBal[i]).toString(),0,'KVault.exitPoolOfUnderlying fail of '+symbol+' balance');
            }
        });
    });

    describe('Strategy.check before', async () => {
        it('Call setUnderlyingTokens should work', async () => {
           await strategyInstance.setUnderlyingTokens(tokens);
           let _tokens=await strategyInstance.getTokens();
           for(var i=0;i<tokens.length;i++){
               assert.equal(_tokens[i],tokens[i],'setUnderlyingTokens fail of tokens');
           }
        });
        it('Call getWeights should work', async () => {
            let _weights=await strategyInstance.getWeights();
            assert.equal(_weights[0],1e20,'getWeights fail of init weights');
        });
    });

    describe('Strategy.check liquidity', async () => {

        it('Call swap by uni should work', async () => {
            let uniToken=await IERC20.at(UNI);
            let amountIn=new ether('0.0000000001');
            await strategyInstance.swapExactInByUni(vaultToken,UNI,amountIn);
            let uniBalance=await uniToken.balanceOf(strategyInstance.address);
            assert.notEqual(uniBalance.toString(),0,'Strategy.swapExactInByUni fail of uni balance');

            let amountOut=new ether('100');
            await strategyInstance.swapExactOutByUni(vaultToken,UNI,amountOut);
            uniBalance=await uniToken.balanceOf(strategyInstance.address);
            assert.notEqual(uniBalance.toString(),0,'Strategy.swapExactOutByUni fail of uni balance');

        });

        it('Call swap by curve should work', async () => {
            let vaultTokenContract=await IERC20.at(vaultToken);
            let balance=await vaultTokenContract.balanceOf(strategyInstance.address);
            let amountIn=balance.div(new BN('10'));

            let ethRecipe=await strategyInstance.swapIntoByCurve(vaultToken,sETH,amountIn);
            let btcRecipe=await strategyInstance.swapIntoByCurve(vaultToken,sBTC,amountIn);
            let ethTokenId=ethRecipe.receipt.rawLogs[ethRecipe.receipt.rawLogs.length-1].topics[1];
            let btcTokenId=btcRecipe.receipt.rawLogs[btcRecipe.receipt.rawLogs.length-1].topics[1];

            let ethTokenInfo=await strategyInstance.tokenInfo(ethTokenId);
            let btcTokenInfo=await strategyInstance.tokenInfo(btcTokenId);
            // console.log("btcTokenInfo:"+btcTokenInfo);
            // console.log("btcTokenId:"+btcTokenId);

            await EvmHelper.increaseBlockTime(400000);
            await strategyInstance.withdrawByCurve(ethTokenId,ethTokenInfo[2]);
            await strategyInstance.swapByCurvePool(curve_seth_pool,sETH,1,0,ethTokenInfo[2]);
            await strategyInstance.ethToWeth(ethTokenInfo[2]);

            let ethtoken=await IERC20.at(sETH);
            let ethBal=await ethtoken.balanceOf(strategyInstance.address);
            assert.notEqual(ethBal,new BN('0'),'Strategy.swap fail of sETH');

            await EvmHelper.increaseBlockTime(400000);
            await strategyInstance.swapFromByCurve(btcTokenId,sBTC,WBTC,btcTokenInfo[2]);
            let btcToken=await IERC20.at(WBTC);
            let btcBal=await btcToken.balanceOf(strategyInstance.address);
            assert.notEqual(btcBal,0,'Strategy.swap fail of wBTC');

        });

        it('Call add liquidity should work', async () => {
            let ethTokenContract=await IERC20.at(WETH);
            let ethBal=await ethTokenContract.balanceOf(strategyInstance.address);
            let ethAmountIn=ethBal.div(new BN('3'));

            let vaultTokenContract=await IERC20.at(vaultToken);
            let vaultBal=await vaultTokenContract.balanceOf(strategyInstance.address);
            let eth_vault=await this.uniswapV2ExpandLibraryMockInstance.pairFor(WETH,vaultToken);
            await strategyInstance.addLiquidity(eth_vault,0,ethAmountIn,vaultBal);
            let eth_vaultToken=await IERC20.at(eth_vault);
            assert.notEqual(await eth_vaultToken.balanceOf(strategyInstance.address),0,'Strategy.addLiquidity fail of eth_vault');

            let btcToken=await IERC20.at(WBTC);
            let btcBal=await btcToken.balanceOf(strategyInstance.address);
            let eth_btc=await this.uniswapV2ExpandLibraryMockInstance.pairFor(WETH,WBTC);
            await strategyInstance.addLiquidity(eth_btc,0,btcBal,ethAmountIn);
            let eth_btcToken=await IERC20.at(eth_btc);
            assert.notEqual(await eth_btcToken.balanceOf(strategyInstance.address),0,'Strategy.addLiquidity fail of eth_btc');

            let uniToken=await IERC20.at(UNI);
            let uniBal=await uniToken.balanceOf(strategyInstance.address);
            let eth_uni=await this.uniswapV2ExpandLibraryMockInstance.pairFor(WETH,UNI);
            await strategyInstance.addLiquidity(eth_uni,0,ethAmountIn,uniBal);
            let eth_uniToken=await IERC20.at(eth_uni);
            assert.notEqual(await eth_uniToken.balanceOf(strategyInstance.address),0,'Strategy.addLiquidity fail of eth_uni');
        });

        it('Call remove liquidity should work', async () => {
            let eth_vault=await this.uniswapV2ExpandLibraryMockInstance.pairFor(WETH,vaultToken);
            let eth_vaultToken=await IERC20.at(eth_vault);
            let eth_vault_bal=await eth_vaultToken.balanceOf(strategyInstance.address);
            let eth_vault_r=eth_vault_bal.div(new BN('10'));
            await strategyInstance.removeLiquidity(eth_vault,eth_vault_r);

            let eth_btc=await this.uniswapV2ExpandLibraryMockInstance.pairFor(WETH,WBTC);
            let eth_btcToken=await IERC20.at(eth_btc);
            let eth_btc_bal=await eth_btcToken.balanceOf(strategyInstance.address);
            let eth_btc_r=eth_btc_bal.div(new BN('10'));
            await strategyInstance.removeLiquidity(eth_btc,eth_btc_r);

            let eth_uni=await this.uniswapV2ExpandLibraryMockInstance.pairFor(WETH,UNI);
            let eth_uniToken=await IERC20.at(eth_uni);
            let eth_uni_bal=await eth_uniToken.balanceOf(strategyInstance.address);
            let eth_uni_r=eth_uni_bal.div(new BN('10'));
            await strategyInstance.removeLiquidity(eth_uni,eth_uni_r);
        });
    });

    describe('Strategy.assets', async () => {

        it('Call pools should work', async () => {
            let pools=await strategyInstance.pools();
            // console.log("pools:"+pools);
            assert.equal(pools.length,3,'Strategy.pools fail of pools length');
        });
        it('Call assets should work', async () => {
            let assetsBal=await strategyInstance.assets();
            // console.log("assetsBal:"+assetsBal);
            assert.notEqual(assetsBal,new BN('0'),'Strategy.assets fail of assetsBal');
        });

        it('Call available should work', async () => {
            let availableBal=await strategyInstance.available();
            // console.log("availableBal:"+availableBal);
            assert.notEqual(availableBal,new BN('0'),'Strategy.available fail of availableBal');
        });

        it('Call tokenValue should work', async () => {
            let tokenValueByIn=await strategyInstance.tokenValueByIn(WBTC,vaultToken,1e8);
            assert.notEqual(tokenValueByIn,new BN('0'),'Strategy.tokenValueByIn fail of tokenValueByIn');
            let tokenValueByOut=await strategyInstance.tokenValueByOut(WBTC,vaultToken,1e8);
            assert.notEqual(tokenValueByOut,new BN('0'),'Strategy.tokenValueByOut fail of tokenValueByOut');
        });

        it('Call liquidityTokenOut should work', async () => {
            let eth_btc=await this.uniswapV2ExpandLibraryMockInstance.pairFor(WETH,WBTC);
            let liquidityTokenOut=await strategyInstance.liquidityTokenOut(eth_btc);
            assert.notEqual(liquidityTokenOut[0],new BN('0'),'Strategy.liquidityTokenOut fail of liquidityTokenOut[0]');
            assert.notEqual(liquidityTokenOut[1],new BN('0'),'Strategy.liquidityTokenOut fail of liquidityTokenOut[1]');
        });

        it('Call getTokenNumbers should work', async () => {
            let tokenNumbers=await strategyInstance.getTokenNumbers();
            for(var i=0;i<tokenNumbers.length;i++){
                // let tokenValueByIn=await strategyInstance.tokenValueByIn(tokens[i],vaultToken,tokenNumbers[i]);
                // console.log("tokenNumbers["+i+"]="+tokenNumbers[i]+",tokenValueByIn:"+tokenValueByIn);
                assert.notEqual(tokenNumbers[i],new BN('0'),'Strategy.getTokenNumbers fail of tokenNumbers['+i+']');
            }
        });

        it('Call extractableUnderlyingNumber should work', async () => {
            let underlyingNumber=await strategyInstance.extractableUnderlyingNumber(100e6);
            for(var i=0;i<underlyingNumber.length;i++){
                // console.log("underlyingNumber["+i+"]="+underlyingNumber[i]);
                assert.notEqual(underlyingNumber[i],new BN('0'),'Strategy.extractableUnderlyingNumber fail of underlyingNumber['+i+']');
            }
        });

    });

    describe('KVault.exitPoolOfUnderlying', async () => {
        it('Call exitPoolOfUnderlying token with has liquidity should work', async () => {
            let amount=90000000;
            let beforeBal=[];
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                beforeBal[i]=await token.balanceOf(accounts[0]);
            }
            await kVaultInstance.exitPoolOfUnderlying(amount);
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                let symbol=await token.symbol();
                let bal=await token.balanceOf(accounts[0]);
                // console.log(symbol+":"+bal);
                assert.notEqual((bal-beforeBal[i]).toString(),new BN('0'),'KVault.exitPoolOfUnderlying fail of '+symbol+' balance');
            }
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
            for(var i=0;i<tokens.length;i++){
                let token=await IERC20.at(tokens[i]);
                let bal=await token.balanceOf(strategyInstance.address);
                assert.equal(bal.valueOf(),0,'Controller.harvestAll fail of token balance');
            }
            let assets=await strategyInstance.assets();
            assert.notEqual(assets,new BN('0'),'Controller.harvestAll fail of assets');
        });
    });
});
