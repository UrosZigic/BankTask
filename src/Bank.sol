//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @author UrosZigic
contract Bank is Ownable2Step, ReentrancyGuard {

    using SafeERC20 for IERC20;

    error NotFirstPeriod();
    error NotWithdrawPeriod();
    error CantWithdraw();
    error NoDepositFound();
    error NoRewardsLeft();
    error CantRenounceOwnership();


    address public immutable tokenAddress;
    
    uint256 public totalStaked;
    mapping(address => uint256) public deposits;

    uint256 public poolR;

    uint256 public immutable startingPoolR2;
    uint256 public immutable startingPoolR3;

    uint256 public immutable initialTime;
    uint256 public immutable timePeriod;


    event Deposited(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed totalAmount, uint256 indexed rewardAmount);
    event OwnerWithdrawn(address indexed adminAddress, uint256 indexed remainingRewards);


    /**
     * @notice Initializes required fields during the creation of the smart contract
     * @param _timePeriodInDays Period in days that determines different periods of the staking process
     * @param _tokenAddress Address of token used in contract
     * @param _amountForRewards Amount of specified token for reward pool
     */
    constructor(uint256 _timePeriodInDays, address _tokenAddress, uint256 _amountForRewards) Ownable(msg.sender) {
        initialTime = block.timestamp;
        timePeriod = _timePeriodInDays * 86_400;

        tokenAddress = _tokenAddress;
        poolR = _amountForRewards;

        startingPoolR2 = (_amountForRewards * 30) / 100;
        startingPoolR3 = _amountForRewards / 2;

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), _amountForRewards);
    }

    /**
     * @notice Deposits specified token for staking
     * @param _amount Amount of specified token for deposit
     * @dev A weird function name results in a function signature starting with 0000,
     * resulting in this function being the first function on the list (sorted by solidity compiler).
     * Saving 22 gas on each hop EVM needs to do, just because of the function name and every gas saved is nontrivial because the deposit function is most frequently used by end users
     */
    function deposit_ps2(uint256 _amount) external nonReentrant {
        if (block.timestamp - initialTime >= timePeriod) {
            revert NotFirstPeriod();
        }

        totalStaked += _amount;
        deposits[msg.sender] += _amount;

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposited(msg.sender, _amount);
    }

    /**
     * @notice Withdraws staked tokens with additional rewards
     */
    function withdraw() external nonReentrant {
        if (block.timestamp - initialTime < timePeriod * 2) {
            revert NotWithdrawPeriod();
        }

        if (block.timestamp - initialTime < timePeriod * 3) {
            _withdrawUsing(poolR - startingPoolR2 - startingPoolR3);

        } else if (block.timestamp - initialTime < timePeriod * 4) {
            _withdrawUsing(poolR - startingPoolR3);

        } else {
            _withdrawUsing(poolR);
        }
    }

    /**
     * @notice Owner can withdraw the leftover amount of the reward pool if all users unstaked their tokens
     */
    function bankWithdraw() external nonReentrant onlyOwner {
        /// Potentially saving gas due to the first part being cheaper
        if (totalStaked != 0 || block.timestamp - initialTime < timePeriod * 4) {
            revert CantWithdraw();
        }

        if (poolR == 0) {
            revert NoRewardsLeft();
        }

        uint256 withdrawAmount = poolR;
        poolR = 0;

        IERC20(tokenAddress).safeTransfer(msg.sender, withdrawAmount);

        emit OwnerWithdrawn(msg.sender, withdrawAmount);
    }

    /**
     * @notice Disables renounceOwnership() function from the imported OZ's Ownable2Step contract
     */
    function renounceOwnership() public view override onlyOwner {
        revert CantRenounceOwnership();
    }

    /**
     * @notice Logic for withdrawing staked tokens
     * @param pool Part of the reward pool that is currently in scope
     */
    function _withdrawUsing(uint256 pool) internal {
        if (deposits[msg.sender] == 0) {
            revert NoDepositFound();
        }

        uint256 rewardAmount = pool * (deposits[msg.sender] * 100 / totalStaked) / 100;
        uint256 withdrawAmount = deposits[msg.sender] + rewardAmount;

        totalStaked -= deposits[msg.sender];
        deposits[msg.sender] = 0;
        poolR -= rewardAmount;

        IERC20(tokenAddress).safeTransfer(msg.sender, withdrawAmount);

        emit Withdrawn(msg.sender, withdrawAmount, rewardAmount);
    }
}