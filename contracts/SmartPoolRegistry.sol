// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISmartPoolRegistry.sol";

contract SmartPoolRegistry is Ownable,ISmartPoolRegistry {

    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _pools;

    function inRegistry(address pool) external override view returns (bool){
        return _pools.contains(pool);
    }

    function getPools()external override view returns (address[] memory entries){
        uint256 length=_pools.length();
        entries=new address[](length);
        for(uint256 i=0;i<length;i++){
            entries[i]=_pools.at(i);
        }
        return entries;
    }

    function addSmartPool(address pool) external override onlyOwner{
        require(!_pools.contains(pool),"The pool already exists!");
        _pools.add(pool);
    }
    function removeSmartPool(address pool) external override onlyOwner{
        require(_pools.contains(pool),"The pool not exists!");
        _pools.remove(pool);
    }
}
