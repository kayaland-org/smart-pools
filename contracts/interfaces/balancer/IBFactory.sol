// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./IBPool.sol";
interface IBFactory {

    function isBPool(address pool) external view returns (bool);
    function newBPool() external returns (address);

}