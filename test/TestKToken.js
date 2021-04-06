const kToken = artifacts.require('KToken');

contract('kToken', (accounts) => {

  it('should put 0 kToken in the first account', async () => {
    const kTokenInstance = await kToken.new('KToken','K',18);
    kTokenInstance.autoGas=true;
    const balance = await kTokenInstance.balanceOf(accounts[0]);
    assert.equal(balance.valueOf(), 0, "0 wasn't in the first account");
  });


});
