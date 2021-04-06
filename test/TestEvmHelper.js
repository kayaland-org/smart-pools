
const EvmHelper = require( "../scripts/EvmHelper" );
contract('TokenHelper', (accounts) => {


    describe('EvmHelper', async () => {
        it('Call increaseBlockTime should work', async () => {
            await EvmHelper.increaseBlockTime(370000);
        });
    });
});
