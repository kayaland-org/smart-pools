// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface ISmartPool is IERC20{

    function getJoinFeeRatio() external view returns (uint256,uint256);

    function getExitFeeRatio() external view returns (uint256,uint256);

    function joinPool(address user,uint256 _amount) external;

    function exitPool(address user,uint256 _amount) external;

    function getController() external view returns (address);

    function getTokens() external view returns (address[] memory);

    function calcTokensForAmount(uint256 _amount) external view returns (address[] memory tokens, uint256[] memory amounts);
}
