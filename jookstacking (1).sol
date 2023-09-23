// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract jookStaking is Ownable  {
    using SafeERC20 for IERC20;

    uint256 public totalStakedAmount;
    uint256 public totalRewardsGenerated;
    address public TokenAddress;
    uint64 public tokenDecimal;
    uint64 public monthly;

    struct userData {
        uint32 stakingTime;
        uint32 stakingType;
        uint128 stakedAmount;
        bool claimed;
    }

    mapping(address => uint128) public userStakeId; //  total stake done by a particular user
    mapping(address => mapping(uint128 => userData)) public userMapping; // this user at this stakecount then user struct

    event stakeEvent(
        uint128 userStakeId,
        uint32 userStakingTime,
        uint32 userStakingType,
        uint128 userStakedAmount,
        address userAddress
    );

    event claimEvent(
        uint128 userStakeId,
        address userAddress,
        uint256 userClaimedAmount
    );

    bool isInitialized;

    constructor(address _TokenAddress, uint64  _tokenDecimal
)  {
        // require(!isInitialized, "Already initialized");
        // isInitialized = true;
        // _setOwner(_owner);
        TokenAddress = _TokenAddress;
        tokenDecimal = _tokenDecimal;
        monthly = 28 days;
        // monthly = 60;
    }


    //    ***************************************     FUNCTION    FOR     STAKING       ****************************************

    function staking(uint32 _type, uint128 _amount) public {
        //_type ==1 ==> staking for 6 months = 180 days
        //_type==2  ==> staking for 12 months = 360 days
        require(
            IERC20(TokenAddress).allowance(msg.sender, address(this)) >=
                _amount,
            " allowance is not provided"
        );
        require(
            IERC20(TokenAddress).balanceOf(msg.sender) > _amount,
            " user dont have enough balance"
        );
        userData storage uData = userMapping[msg.sender][
            userStakeId[msg.sender]
        ];

        uData.stakingTime = uint32(block.timestamp);
        uData.stakingType = _type;
        uData.stakedAmount = _amount;
        uData.claimed = false;

        SafeERC20.safeTransferFrom(
            IERC20(TokenAddress),
            msg.sender,
            address(this),
            _amount
        ); ///tranfering the staked amount to the contract from user ADDERSS

        totalStakedAmount += _amount;
        emit stakeEvent(
            userStakeId[msg.sender],
            uData.stakingTime,
            uData.stakingType,
            uData.stakedAmount,
            msg.sender
        );
        ++userStakeId[msg.sender];
    }

    //    ****************************************   FOR  CLAIM TIME DETAILS   ********************************************

    function claimDetails(uint32 _stakeId)
        public
        view
        returns (uint128, uint128)
    {
        userData memory uData = userMapping[msg.sender][_stakeId];
        require(
            block.timestamp >
                (uData.stakingTime + (monthly * uData.stakingType)),
            " Staking period is still going  on"
        );
        return (
            uData.stakedAmount,
            (calculation(_stakeId) - uData.stakedAmount)
        );
    }

    //     ***************************************    FOR   UNSTAKEAMOUNT   CALCULATION    *************************************

    function calculation(uint32 _stakeId) public view returns (uint128) {
        userData memory uData = userMapping[msg.sender][_stakeId];
        uint128 totalAmount;
        uint128 count = uint128(
            (block.timestamp - uData.stakingTime) /
                (monthly * uData.stakingType)
        );
        if (uData.stakingType == 1) {
            totalAmount = uint128(
                (uData.stakedAmount * (125**count)) / (100**count)
            );
            return totalAmount;
        } else if (uData.stakingType == 2) {
            totalAmount = uint128(
                (uData.stakedAmount * (160**count)) / (100**count)
            );
            return totalAmount;
        }else{
             totalAmount = uint128(
                (uData.stakedAmount * (215**count)) / (100**count)
            );
            return totalAmount;
        }
    }

    //    *********************************************   FUNCTION  FOR CLAIMING AMOUNT   **************************************

    function claim(uint32 _stakeId) public {
        userData storage uData = userMapping[msg.sender][_stakeId];
        require(
            block.timestamp >
                (uData.stakingTime + monthly * uData.stakingType),
            " Staking period is still going  on"
        );
        require(uData.claimed == false, " user has already claimed");
        uint128 claimAmount = calculation(_stakeId);
        require(
            claimAmount <= IERC20(TokenAddress).balanceOf(address(this)),
            " contract dont have enough tokens left"
        );
        totalRewardsGenerated += (claimAmount - uData.stakedAmount);
        SafeERC20.safeTransfer(IERC20(TokenAddress), msg.sender, claimAmount);
        uData.claimed = true;
        emit claimEvent(_stakeId, msg.sender, claimAmount);
    }
}
