// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ISmartPoolRegistry {
    function inRegistry(address pool) external view returns (bool);
    function getPools()external view returns (address[] memory entries);
    function addSmartPool(address pool) external;
    function removeSmartPool(address pool) external;
}
