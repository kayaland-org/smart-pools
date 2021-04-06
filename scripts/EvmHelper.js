
async function increaseBlockTime(time){
    await web3.currentProvider.send({
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [time],
        id: 0
    },function () {

    });
    await web3.currentProvider.send({
        jsonrpc: "2.0",
        method: "evm_mine",
        params: [],
        id: 0
    },function () {

    });
}


module.exports = {
    increaseBlockTime
};







