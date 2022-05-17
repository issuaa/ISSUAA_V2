// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MarketFactory.sol";
import "./GovernanceToken.sol";
import "./VotingEscrow.sol";
import "./VoteMachine.sol";
//import "./issuaaLibrary.sol";
import "./interfaces/IMarketPair.sol";
import "./assetFactory.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RewardsMachine is Initializable{
    address public controlAccount;
    using SafeMath for uint256;
    uint256 public nextRewardsPayment;
    uint256 public currentISSSupply;
    uint256 public maxISSSupply;
    uint256  public maxBonusPools;
    
    uint256 public rewardsRound;
    mapping (address => uint256) public lastRewardsRound;

    GovernanceToken public governanceToken;
    VotingEscrow public votingEscrow;
    VoteMachine public voteMachine;
    
    
    
    address public USDCaddress;

    address public voteMachineAddress;
    address public assetFactoryAddress;
    address public marketFactoryAddress;
    uint256 public vestingPeriod;
    uint256 public LPRewardTokenNumber;
    uint256 public votingRewardTokenNumber;
    bool public ISSBonusPoolAdded;

    address[] public pools;
    mapping(string =>bool) public poolExists;
    uint256 public numberOfPools; 


    address public ISSPoolAddress;

    //uint public debug1;
    //uint public debug2;
    //address public debug3;

    function initializeContract(
        address _controlAccount,
        GovernanceToken _governanceToken,
        VotingEscrow _votingEscrow,
        address _USDCAddress 
        ) 
        public initializer 
        {
        controlAccount = _controlAccount;
        governanceToken = _governanceToken;
        votingEscrow = _votingEscrow;
        currentISSSupply = 40000000 * (10 ** 18);
        vestingPeriod = 180 days;
        nextRewardsPayment = 1633273200;
        maxISSSupply = 100000000 * (10 ** 18);
        maxBonusPools = 250;
        USDCaddress = _USDCAddress;
        rewardsRound = 1;
    }

    function transferControlAccount(
        address _newControlAccount
        )
        public
        {
            require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
            controlAccount = _newControlAccount;
        }


    event currentISSSupplyReduced(
        uint256 _amount
    );
    event rewardPoolAdded(
        string _symbol
    );
    event ISSPoolAdded(
        address _poolAddress
    );

    /**
    * @notice A method that set the address of the VoteMachine contract.
    * @param  _address Address of the VoteMachine contract
    */
    function setVoteMachineAddress (
        address _address
        )
        public
        //onlyOwner
        {
        require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
        voteMachineAddress = _address;
    }

    /**
    * @notice A method that set the address of the VoteMachine contract.
    * @param  _address Address of the VoteMachine contract
    */
    function setMarketFactoryAddress (
        address _address
        )
        public
        //onlyOwner
        {
        require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
        marketFactoryAddress = _address;
    }

    /**
    * @notice A method that set the address of the AssetFactory contract.
    * @param  _address Address of the AssetFactory contract
    */
    function setAssetFactoryAddress (
        address _address
        ) 
        public
        //onlyOwner
        {
        require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
        assetFactoryAddress = _address;
    }

    
    /**
    * @notice A method that reduced the variable currentISSSupply.
    *         currentISSsupply keeps track of the amount of governace token, which is important
    *         to keep reducing the rewards to ot let the issued amount exceed the max value.
    *         this function is used when givernance tokens are burned.
    * @param  _amount Amount by which the currentISSSupply is reduced.
    */
    function reduceCurrentISSSupply(
        uint256 _amount
        ) 
        external 
        {
        require (msg.sender == assetFactoryAddress,'Not authorized');
        currentISSSupply = currentISSSupply.sub(_amount);
        emit currentISSSupplyReduced(_amount);
    }

    /**
    * @notice A method that burns ISS owned by the assetFactory contract.
    * @param  _amount Amount of ISS which is burned.
    */
    function burnAssetFactoryISS(
        uint256 _amount
        ) 
        external 
        {
        require (msg.sender == assetFactoryAddress,'Not authorized');
        governanceToken.burn(assetFactoryAddress, _amount);
        
    }

    /**
    * @notice A method that lets an external contract fetch the current supply of the governance token.
    */
    function getCurrentSupply() 
        external
        view 
        returns (uint256) 
        {
        return (currentISSSupply);
    }

    /**
    * @notice A method that adds a market pair to the list of pools, which will get rewarded.
    * @param  _symbol Address of the asset, for which the new pool is generated
    */
    function addPools(
        string calldata _symbol
        ) 
        external
        //onlyOwner
        {
        require (pools.length+2 <= maxBonusPools,'TOO_MANY_POOLS');
        require(poolExists[_symbol] == false,'POOL_EXISTS_ALREADY');
        require(AssetFactory(assetFactoryAddress).assetExists(_symbol),'UNKNOWN_SYMBOL');
        (address token1,address token2) = AssetFactory(assetFactoryAddress).getTokenAddresses(_symbol);
        address pair1 = MarketFactory(marketFactoryAddress).getPair(token1,USDCaddress);
        address pair2 = MarketFactory(marketFactoryAddress).getPair(token2,USDCaddress);
        require (pair1 != address(0),"PAIR1_DOES_NOT_EXIST");
        require (pair2 != address(0),"PAIR2_DOES_NOT_EXIST");
        poolExists[_symbol] = true;
        pools.push(pair1);
        pools.push(pair2);
        numberOfPools +=2;
        emit rewardPoolAdded(_symbol);
    }

    /**
    * @notice A method that adds the ISS MarketPool.
    * @param  _poolAddress Address of the pool, for which the new pool is generated
    */
    function addISSBonusPool(
        address _poolAddress
        ) 
        external
        
        {
        require(ISSBonusPoolAdded == false,'POOL_EXISTS_ALREADY');
        
        pools.push(_poolAddress);
        numberOfPools +=1;
        ISSBonusPoolAdded = true;
        ISSPoolAddress = _poolAddress;
        emit ISSPoolAdded(_poolAddress);
    }
    

    /**
    * @notice A method that creates the weekly reward tokens. Can only be called once per week.
    */
    function createRewards() 
        external
        returns (uint256) 
        {
        require(nextRewardsPayment<block.timestamp,'TIME_NOT_UP');
        uint256 veSupply = votingEscrow.totalSupply();
        uint256 weeklyRewards = governanceToken.balanceOf(address(this)) * 2 / 100;
        
        votingRewardTokenNumber = weeklyRewards * veSupply / (maxISSSupply - governanceToken.balanceOf(address(this)));
        LPRewardTokenNumber = weeklyRewards - votingRewardTokenNumber;

        
        //SNAPSHOT FOR THE LP TOKEN HOLDERS
        for (uint256 s = 0; s < numberOfPools; s += 1){
            address poolAddress = pools[s];
            IMarketPair(poolAddress).createSnapShot();
        }

        nextRewardsPayment = block.timestamp.add(7 days);
        VoteMachine(voteMachineAddress).resetRewardPoints();
        rewardsRound = rewardsRound.add(1);
        return (weeklyRewards);
    }


    /**
    * @notice A method that claims the rewards for the calling address.
    */
    function claimRewards()
        external
        returns (uint256)
        {
            require (lastRewardsRound[msg.sender]<rewardsRound-1,'CLAIMED_ALREADY');
            VoteMachine(voteMachineAddress).checkVotesIfClosed(rewardsRound - 1,msg.sender); 
            require(VoteMachine(voteMachineAddress).checkFreezeVotes(rewardsRound - 1,msg.sender),'VOTE_NOT_CONSENSUS');
            
            require(VoteMachine(voteMachineAddress).checkExpiryVotes(rewardsRound - 1,msg.sender),'VOTE_NOT_CONSENSUS');
            lastRewardsRound[msg.sender] = rewardsRound - 1;
            
            //Voting rewards
            uint256 votingRewardPoints = VoteMachine(voteMachineAddress).adjustedRewardPointsOf(msg.sender);
            uint256 totalVotingRewardPoints = VoteMachine(voteMachineAddress).getTotalRewardPoints();
            uint256 votingRewards;
            if (totalVotingRewardPoints > 0) {
                votingRewards = votingRewardTokenNumber.mul(votingRewardPoints).div(totalVotingRewardPoints);   
            }
            else {
                votingRewards = 0;
            }
            
            //LP Rewards
            uint256 LPRewards;
            uint256 veSupply = votingEscrow.totalSupply();
            uint256 veISS = votingEscrow.balanceOf(msg.sender);

            
            for (uint256 s = 0; s < numberOfPools; s += 1){
                address poolAddress = pools[s];
                uint256 rewards;
                uint256 rawRewards;
                uint256 snapshotID = IMarketPair(poolAddress).snapshotID();
                
                uint256 LPTokenBalance = IMarketPair(poolAddress).balanceOfAt(msg.sender, snapshotID);
                uint256 LPTokenTotalSupply = IMarketPair(poolAddress).totalSupplyAt(snapshotID);

                if (LPTokenTotalSupply >0){
                    if (poolAddress == ISSPoolAddress){
                        rawRewards = LPRewardTokenNumber.mul(4*5).mul(LPTokenBalance).div(LPTokenTotalSupply).div(numberOfPools+4).div(10);
                    }
                    else{
                        rawRewards = LPRewardTokenNumber.mul(4).mul(LPTokenBalance).div(LPTokenTotalSupply).div(numberOfPools+4).div(10);
                    }    
                    uint256 boostFactor = 1000;
                    if (veSupply >0) {
                        boostFactor = 1000 + (1500 * LPTokenTotalSupply * veISS) / (LPTokenBalance * veSupply);
                        if (boostFactor >2500) {boostFactor = 2500;}
                        }
                    
                    
                    rewards = rawRewards * boostFactor / 1000;
                }
                else{
                    rewards = 0;    
                }
                
                LPRewards = LPRewards + rewards;
            }
            
            

            uint256 totalRewards = votingRewards + LPRewards;

            //Add rewardspoints for the next voting round
            VoteMachine(voteMachineAddress).addRewardPointsDAO(msg.sender,veISS);
            VoteMachine(voteMachineAddress).addTotalRewardPointsDAO(veISS);

            currentISSSupply = currentISSSupply + totalRewards;
            
            governanceToken.transfer(msg.sender, totalRewards);
            return (totalRewards);

        }

    /**
    * @notice A method that gets the pending rewards for a specific address.
    * @param  _address Address for the pending rewards are checked
    */
    function getRewards(address _address)
        external
        view
        returns (uint256)
        {
            if (lastRewardsRound[_address]>=rewardsRound-1){return 0;}

            //Voting rewards
            uint256 votingRewardPoints = VoteMachine(voteMachineAddress).adjustedRewardPointsOf(_address);
            uint256 totalVotingRewardPoints = VoteMachine(voteMachineAddress).getTotalRewardPoints();
            uint256 votingRewards;
            if (totalVotingRewardPoints > 0) {
                votingRewards = votingRewardTokenNumber.mul(votingRewardPoints).div(totalVotingRewardPoints);   
            }
            else {
                votingRewards = 0;
            }
            
            
            
            //LP Rewards
            uint256 LPRewards;
            uint256 veSupply = votingEscrow.totalSupply();
            uint256 veISS = votingEscrow.balanceOf(_address);

            for (uint256 s = 0; s < numberOfPools; s += 1){
                address poolAddress = pools[s];
                uint256 rewards;
                uint256 rawRewards;
                uint256 snapshotID = IMarketPair(poolAddress).snapshotID();
                
                uint256 LPTokenBalance = IMarketPair(poolAddress).balanceOfAt(_address, snapshotID);
                uint256 LPTokenTotalSupply = IMarketPair(poolAddress).totalSupplyAt(snapshotID);

                if (LPTokenTotalSupply >0){
                    if (poolAddress == ISSPoolAddress){
                        rawRewards = LPRewardTokenNumber.mul(4*5).mul(LPTokenBalance).div(LPTokenTotalSupply).div(numberOfPools+4).div(10);
                    }
                    else{
                        rawRewards = LPRewardTokenNumber.mul(4).mul(LPTokenBalance).div(LPTokenTotalSupply).div(numberOfPools+4).div(10);
                    }    
                    uint256 boostFactor = 1000;
                    if (veSupply >0) {
                        boostFactor = 1000 + (1500 * LPTokenTotalSupply * veISS) / (LPTokenBalance * veSupply);
                        if (boostFactor >2500) {boostFactor = 2500;}
                        }
                    
                    
                    rewards = rawRewards * boostFactor / 1000;
                }
                else{
                    rewards = 0;    
                }
                
                LPRewards = LPRewards + rewards;
            }
            
            

            uint256 totalRewards = votingRewards + LPRewards;
            return (totalRewards);

        }
}
