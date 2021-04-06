// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
interface IController {

    function invest(address _vault, uint256 _amount) external;

    function exec(
        address _strategy,
        bool _useToken,
        uint256 _useAmount,
        string memory _signature,
        bytes memory _data) external;

    function harvest(uint256 _amount) external;

    function harvestAll(address _vault)external;

    function harvestOfUnderlying(address to,uint256 _amount)external;

    function assets() external view returns (uint256);

    function vaults(address _strategy) external view returns(address);

    function strategies(address _vault) external view returns(address);

    function inRegister(address _contract) external view returns (bool);
}
