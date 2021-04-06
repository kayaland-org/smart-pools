const TokenHelper = require( "../scripts/TokenHelper" );

let toAddress='0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0';
const buyAddr='0xdAC17F958D2ee523a2206206994597C13D831ec7';
const amountOut=1000000000000;

const IERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/IERC20');

contract('TokenHelper', (accounts) => {
    let butToken;


    before(async () => {
        toAddress=accounts[1];
        butToken=await IERC20.at(buyAddr);
    });

    describe('UniSwap', async () => {
        it('Call swap token should work', async () => {
            let tokenBeforeBal=await butToken.balanceOf(toAddress);
            await TokenHelper.swapExactOutByUniSwap(buyAddr,toAddress,amountOut);
            let tokenAfterBal=await butToken.balanceOf(toAddress);
            assert.equal(tokenAfterBal-tokenBeforeBal,amountOut,'swap token balance fail');
        });
    });
    describe('SushiSwap', async () => {
        it('Call swap token should work', async () => {
            let tokenBeforeBal=await butToken.balanceOf(toAddress);
            await TokenHelper.swapExactOutBySushiSwap(buyAddr,toAddress,amountOut);
            let tokenAfterBal=await butToken.balanceOf(toAddress);
            assert.equal(tokenAfterBal-tokenBeforeBal,amountOut,'swap token balance fail');
        });
    });
});
