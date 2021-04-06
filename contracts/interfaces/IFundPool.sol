// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./IPool.sol";

interface IFundPool is IPool{

    function getTokenWeight(address token) external view returns(uint256 weight);

    function getTokens() external view returns (address[] memory);

    function calcTokensForAmount(uint256 amount,uint8 direction) external view returns (address[] memory tokens, uint256[] memory amounts);
}
