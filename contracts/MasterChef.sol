// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./GovernanceToken.sol";
import "./RewardsMachine.sol";
import "./VotingEscrow.sol";
import "./libraries/BoringERC20.sol";




// MasterChef is a boss. He says "go f your blocks lego boy, I'm gonna use timestamp instead".
// And to top it off, it takes no risks. Because the biggest risk is operator error.
// So we make it virtually impossible for the operator of this contract to cause a bug with people's harvests.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ISS is sufficiently
// distributed and the community can show to govern itself.
//
// With thanks to the TraderJoe team.
//
// Godspeed and may the 10x be with you.

contract MasterChef {
    using SafeMath for uint256;
    using BoringERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 boostFactor; // Boost Factory applied to the rewards payment
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

    // The rewardsMachine contract
    RewardsMachine public rewardsMachine;

    // The VotingEscrow contract
    VotingEscrow public votingEscrow;
    
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
    // The control account
    address public controlAccount;
    // Total amount of claimed rewards
    uint256 public totalClaimedPendingRewards;
    // Time of last emission change
    uint256 public timeOfLastEmissionChange;
    // Accumulated Emissions at the time of the last emission change
    uint256 public AccumulatedEmissionsAtLastEmissionChange;

    

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
        RewardsMachine _rewardsMachine,
        VotingEscrow _votingEscrow,
        address _controlAccount,
        uint256 _iSSPerSec,
        uint256 _startTimestamp
        ) 
        {
        ISS = _iSS;
        rewardsMachine = _rewardsMachine;
        controlAccount = _controlAccount;
        votingEscrow = _votingEscrow;
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
    ) public  {
        require (msg.sender == address(rewardsMachine),"NOT_REWARDS_MACHINE");
        massUpdatePools();
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
    ) public  {
        require (msg.sender == address(rewardsMachine),"NOT_REWARDS_MACHINE");
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        emit Set(_pid, _allocPoint);
    }

    // A fucntion to get the boost factor for an address and a pool idea
    function getBoost(address _address, uint256 _pid) 
        public
        view 
        returns (
            uint256
        )
    {
        PoolInfo storage pool = poolInfo[_pid]; //get pool data
        UserInfo storage user = userInfo[_pid][msg.sender]; //get the user data for this pool
        uint256 veISSBalance = votingEscrow.balanceOf(_address);
        uint256 totalVeISS = votingEscrow.totalSupply();
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (veISSBalance == 0 || lpSupply == 0){
            return(1e12);
        }
        uint256 boostFactor = 1e12 + (user.amount * 1e12 *  totalVeISS / veISSBalance / lpSupply);
        if (boostFactor > 25 * 1e11) {
            boostFactor = 25 * 1e11;
        }
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
            uint256 iSSReward = multiplier.mul(iSSPerSec).mul(pool.allocPoint).div(totalAllocPoint);
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
        PoolInfo storage pool = poolInfo[_pid]; //get the pool data
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp.sub(pool.lastRewardTimestamp); // get the number of seconds since the last rewardsTimestamp
        uint256 iSSReward = multiplier.mul(iSSPerSec).mul(pool.allocPoint).div(totalAllocPoint); // calculate how many ISS tokens have accrued as rewards since last timeStamp
        pool.accISSPerShare = pool.accISSPerShare.add(iSSReward.mul(1e12).div(lpSupply));
        pool.lastRewardTimestamp = block.timestamp;
        emit UpdatePool(_pid, pool.lastRewardTimestamp, lpSupply, pool.accISSPerShare);
    }

    // Deposit LP tokens to MasterChef for ISS allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid]; //get pool data
        UserInfo storage user = userInfo[_pid][msg.sender]; //get the user data for this pool
        updatePool(_pid);
        if (user.amount > 0) {
            // Harvest ISS
            uint256 pending = user.amount.mul(pool.accISSPerShare).div(1e12).sub(user.rewardDebt);
            //uint256 payout = pending * user.boostFactor * 4 /1e13;
            uint256 payout = pending;
            rewardsMachine.transferISSforMasterChef(msg.sender, payout);
            totalClaimedPendingRewards += pending;
            emit Harvest(msg.sender, _pid, payout);
        }
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accISSPerShare).div(1e12);
        user.boostFactor = getBoost(msg.sender,_pid);
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
        uint256 payout = pending * user.boostFactor * 4 /1e13;
        rewardsMachine.transferISSforMasterChef(msg.sender, payout);
        totalClaimedPendingRewards += pending;
        emit Harvest(msg.sender, _pid, payout);

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accISSPerShare).div(1e12);
        user.boostFactor = getBoost(msg.sender,_pid);
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
        user.boostFactor = 1000;
    }

    /// @notice Harvest proceeds for msg.sender.
    /// @param _pid The index of the pool. See `poolInfo`.
    function harvest(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accISSPerShare).div(1e12).sub(user.rewardDebt);
        uint256 payout = pending * user.boostFactor * 4 /1e13;
        rewardsMachine.transferISSforMasterChef(msg.sender, payout);
        totalClaimedPendingRewards += pending;
        user.rewardDebt = user.amount.mul(pool.accISSPerShare).div(1e12);
        user.boostFactor = getBoost(msg.sender,_pid);
        emit Harvest(msg.sender, _pid, payout);
    }

    // get the pending rewards which can potentially still be minted
    function getPendingRewards()
        public
        view
        returns (uint256 totalPendingRewards)
        {
        uint256 AccumulatedEmissions = AccumulatedEmissionsAtLastEmissionChange + ((block.timestamp - timeOfLastEmissionChange) * iSSPerSec);
        totalPendingRewards = AccumulatedEmissions - totalClaimedPendingRewards;
        return (totalPendingRewards);
    }

    

    // Pancake has to add hidden dummy pools inorder to alter the emission,
    // here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _iSSPerSec) public {
        require (msg.sender == address(rewardsMachine),"NOT_REWARDS_MACHINE");
        massUpdatePools();
        AccumulatedEmissionsAtLastEmissionChange += (block.timestamp - timeOfLastEmissionChange) * iSSPerSec;
        timeOfLastEmissionChange = block.timestamp;
        
        iSSPerSec = _iSSPerSec;
        emit UpdateEmissionRate(msg.sender, _iSSPerSec);
    }
}