// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface SynthSwap {

    function get_swap_into_synth_amount(
        address _from,
        address _synth,
        uint256 _amount) external view returns (uint256);

    function get_swap_from_synth_amount(
        address _synth,
        address _to,
        uint256 _amount) external view returns (uint256);

    function swap_into_synth(
        address _from,
        address _synth,
        uint256 _amount,
        uint256 _expected)
    external returns (uint256);

    function swap_into_synth(
        address _from,
        address _synth,
        uint256 _amount,
        uint256 _expected,
        address _receiver)
    external returns (uint256);

    function swap_into_synth(
        address _from,
        address _synth,
        uint256 _amount,
        uint256 _expected,
        address _receiver,
        uint256 _existing_token_id)
    external returns (uint256);

    function swap_from_synth(
        uint256 _token_id,
        address _to,
        uint256 _amount,
        uint256 _expected,
        address _receiver
    )external returns (uint256);

    function token_info(uint256 _token_id)external view returns(TokenInfo memory tokenInfo);

    function withdraw(uint256 _token_id,uint256 _amount)external;

    function withdraw(uint256 _token_id,uint256 _amount,address _receiver)external;

    struct TokenInfo{
        address owner;
        address synth;
        uint256 underlying_balance;
        uint256 time_to_settle;
    }

}
