const {DeployOptions} = require('web3-eth-contract');

//todo auto deploy tools
//1. load config
//2. run flow script
//3.

async function deploy(deployer,options){
    let contractInstance;
    await deployer.deploy(options).then(function (instance) {
        contractInstance=instance;
    });
    return contractInstance;
}


module.exports = {
    deploy
};







