// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./GovernanceToken.sol";
import "./libraries/BoringERC20.sol";




// MasterChef is a boss. He says "go f your blocks lego boy, I'm gonna use timestamp instead".
// And to top it off, it takes no risks. Because the biggest risk is operator error.
// So we make it virtually impossible for the operator of this contract to cause a bug with people's harvests.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ISS is sufficiently
// distributed and the community can show to govern itself.
//
// With thanks to the Lydia Finance team.
//
// Godspeed and may the 10x be with you.

contract MasterChefISSV2 is Ownable {
    using SafeMath for uint256;
    using BoringERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ISS tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accISSPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accISSPerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. ISS tokens to distribute per second.
        uint256 lastRewardTimestamp; // Last timestamp that ISS token distribution occurs.
        uint256 accISSPerShare; // Accumulated ISS per share, times 1e12. See below.
    }

    // The ISS TOKEN!
    GovernanceToken public ISS;
    
    // ISS tokens rewarded per second.
    uint256 public iSSPerSec;
    

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Set of all LP tokens that have been added as pools
    EnumerableSet.AddressSet private lpTokens;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The timestamp when ISS mining starts.
    uint256 public startTimestamp;

    event Add(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken);
    event Set(uint256 indexed pid, uint256 allocPoint);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdatePool(uint256 indexed pid, uint256 lastRewardTimestamp, uint256 lpSupply, uint256 accISSPerShare);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 _iSSPerSec);

    constructor(
        GovernanceToken _iSS,
        uint256 _iSSPerSec,
        uint256 _startTimestamp
    )  {
        
        ISS = _iSS;
        iSSPerSec = _iSSPerSec;
        startTimestamp = _startTimestamp;
        totalAllocPoint = 0;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken
    ) public onlyOwner {
        require(Address.isContract(address(_lpToken)), "add: LP token must be a valid contract");
        
        require(!lpTokens.contains(address(_lpToken)), "add: LP already added");
        massUpdatePools();
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accISSPerShare: 0
            })
        );
        lpTokens.add(address(_lpToken));
        emit Add(poolInfo.length.sub(1), _allocPoint, _lpToken);
    }

    // Update the given pool's ISS allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint
    ) public onlyOwner {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        emit Set(_pid, _allocPoint);
    }

    // View function to see pending ISSs on frontend.
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 pendingISS
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accISSPerShare = pool.accISSPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 multiplier = block.timestamp.sub(pool.lastRewardTimestamp);
            uint256 lpPercent = 1000;
            uint256 iSSReward = multiplier.mul(iSSPerSec).mul(pool.allocPoint).div(totalAllocPoint).mul(lpPercent).div(
                1000
            );
            accISSPerShare = accISSPerShare.add(iSSReward.mul(1e12).div(lpSupply));
        }
        pendingISS = user.amount.mul(accISSPerShare).div(1e12).sub(user.rewardDebt);

        
    }



    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp.sub(pool.lastRewardTimestamp);
        uint256 iSSReward = multiplier.mul(iSSPerSec).mul(pool.allocPoint).div(totalAllocPoint);
        uint256 lpPercent = 1000;
        pool.accISSPerShare = pool.accISSPerShare.add(iSSReward.mul(1e12).div(lpSupply).mul(lpPercent).div(1000));
        pool.lastRewardTimestamp = block.timestamp;
        emit UpdatePool(_pid, pool.lastRewardTimestamp, lpSupply, pool.accISSPerShare);
    }

    // Deposit LP tokens to MasterChef for ISS allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            // Harvest ISS
            uint256 pending = user.amount.mul(pool.accISSPerShare).div(1e12).sub(user.rewardDebt);
            safeISSTransfer(msg.sender, pending);
            emit Harvest(msg.sender, _pid, pending);
        }
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accISSPerShare).div(1e12);

        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);

        // Harvest ISS
        uint256 pending = user.amount.mul(pool.accISSPerShare).div(1e12).sub(user.rewardDebt);
        safeISSTransfer(msg.sender, pending);
        emit Harvest(msg.sender, _pid, pending);

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accISSPerShare).div(1e12);

        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param _pid The index of the pool. See `poolInfo`.
    function harvest(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accISSPerShare).div(1e12).sub(user.rewardDebt);
        safeISSTransfer(msg.sender, pending);
        emit Harvest(msg.sender, _pid, pending);
    }

    // Safe ISS transfer function, just in case if rounding error causes pool to not have enough ISS tokens.
    function safeISSTransfer(address _to, uint256 _amount) internal {
        uint256 iSSBal = ISS.balanceOf(address(this));
        if (_amount > iSSBal) {
            ISS.transfer(_to, iSSBal);
        } else {
            ISS.transfer(_to, _amount);
        }
    }

    

    // Pancake has to add hidden dummy pools inorder to alter the emission,
    // here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _iSSPerSec) public onlyOwner {
        massUpdatePools();
        iSSPerSec = _iSSPerSec;
        emit UpdateEmissionRate(msg.sender, _iSSPerSec);
    }
}