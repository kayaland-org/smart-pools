// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../storage/SmartPoolStorage.sol";

library ChargeModelLibrary {

    using SafeMath for uint256;

    event FeeChanged(address indexed setter, uint256 oldRatio, uint256 oldDenominator, uint256 newRatio, uint256 newDenominator);


    function getFee(SmartPoolStorage.FeeType ft)internal view returns(uint256,uint256){
        SmartPoolStorage.Fee memory fee=SmartPoolStorage.load().fees[ft];
        if(fee.denominator==0){
            return(fee.ratio,1000);
        }else{
            return(fee.ratio,fee.denominator);
        }
    }

    function setFee(SmartPoolStorage.FeeType ft,uint256 ratio,uint256 denominator)internal {
        require(ratio<=denominator,"ChargeModelLibrary.setFee: setFee ratio<=denominator");
        SmartPoolStorage.Fee storage fee=SmartPoolStorage.load().fees[ft];
        fee.ratio=ratio;
        fee.denominator=denominator;
        fee.lastTimestamp=block.timestamp;
        emit FeeChanged(msg.sender, fee.ratio,fee.denominator, ratio,denominator);
    }

    function setFeeTime(SmartPoolStorage.FeeType ft,uint256 time)internal {
        SmartPoolStorage.Fee storage fee=SmartPoolStorage.load().fees[ft];
        fee.lastTimestamp=time;
    }

    function calcFee(SmartPoolStorage.FeeType ft,uint256 totalAmount)internal view returns(uint256){
        SmartPoolStorage.Fee memory fee=SmartPoolStorage.load().fees[ft];
        uint256 denominator=fee.denominator==0?1000:fee.denominator;
        uint256 ratio=fee.ratio;
        if(SmartPoolStorage.FeeType.JOIN_FEE==ft||SmartPoolStorage.FeeType.EXIT_FEE==ft){
            uint256 amountRatio=totalAmount.div(denominator);
            return amountRatio.mul(ratio);
        }else if(SmartPoolStorage.FeeType.MANAGEMENT_FEE==ft){
            if(fee.lastTimestamp==0||totalAmount==0){
                return 0;
            }else{
                uint256 diff=block.timestamp.sub(fee.lastTimestamp);
                return totalAmount.mul(diff).mul(ratio).div(denominator*365.25 days);
            }
        }else{
            return 0;
        }
    }

}
