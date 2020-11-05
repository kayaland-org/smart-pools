# Description
The project name is KayaLand(<https://www.kayaland.org>).

# Release [Create Contract Tool](http://remix.ethereum.org/#optimize=true&version=soljson-v0.6.4+commit.1dca32f3.js&evmVersion=null&gist=54dce4e475c987021816a99ed3739855)
   
- BalancerFactory: 0x9424B1412450D0f8Fc2255FAf6046b98213B76Bd

- Tokens: Go to Etherscan for query       

- Create BalLiquidityFactory: No parameters

- Init Pool: Call "BalancerFactory.init" Function
    ```text
    Parameter: BalancerFactory
    ```

- Approve Tokens to BalLiquidityFactory: Call "Token.Approve" Function

    <span style="color:yellow"> Notes: If no approval token is given to balliquidityfactory, the create pool will fail </span>
    
    ```text
    Parameter: BalLiquidityFactory,Pool init amount
    ```

- Create Pool: Call "newProxiedSmartPool" Function

     <span style="color:yellow">  Notes:You need to use Etherscan to query this transaction to get the pool address </span>
    
    ```text
    Parameter: name,symbol,initialSupply,tokens[],amounts[],weights[]
    
    Example: "KF DeFi Large Cap Fund","KFDFLC","1000000000000000000",["0xdc5850C120d6CA91a88Eb357dB9a30A01b7796BC","0xd0A1E359811322d97991E03f863a0C30C2cF029C","0x25E5DFAe0E66246d5423862af3Ad4Da650dE4ff3","0x1B1690550235FC494abD6820dBd0DD8b11050828","0xAe30BEBE8617616CD863e54bD58B39F3C0911dAD","0x63C96B7BEaD34dE4f54aFa7C9eE5d8e6B8Ce495e","0x9f5A9c9eBa9977757A3809d673E1C02eD66d9666","0xDdA4242aD365a659d458982B41344ac0BAfE1652"],["95000000000000000","55000000000000000","90000000000000000","20000000000000000","35000000000000000","95000000000000000","45000000000000000","65000000000000000"],["9500000000000000000","5500000000000000000","9000000000000000000","2000000000000000000","3500000000000000000","9500000000000000000","4500000000000000000","6500000000000000000"],"1000000000000000000000"
    ```

- SmartPoolRegister: No parameters

- Register Pool：Call "SmartPoolRegister.addSmartPool" Function
    ```text
    Parameter: Pool
    ```
# Copyright
MIT