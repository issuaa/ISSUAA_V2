// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./assetFactory.sol";
import "./VotingEscrow.sol";


contract VoteMachine is Initializable{
	address public controlAccount;
	AssetFactory internal assetFactory;
	VotingEscrow internal votingEscrow;
	address public assetFactoryAddress;
	address public rewardsMachineAddress;
	address public DAOAddress;
	address public UpdaterAddress;	
	uint256 internal DAOVolume;
	uint256 public lastVoteID;
	mapping (string => uint256) public lastFreezeVoteIDBySymbol;
	mapping (uint256 => mapping (address => bool)) public freezeVotesByID;
	mapping (uint256 => freezeVoteDetails) public allFreezeVotesByID;
	mapping (uint256 => mapping (address => bool)) public hasVoted;

	mapping (uint256 => rewardPointsSnapshot) public rewardPointsSnapshots;
    uint256 public currentRewardsRound;
    mapping(string => FreezeVotes) public getFreezeVotes;
    mapping(string => endOfLifeVotes) public getEndOfLifeVotes;
    mapping (address => uint256) public rewardPoints;

	mapping (uint256 => mapping (address => individualFreezeVote[])) public freezeVotesToCheck;
	mapping (uint256 => bool) public freezeVoteResults;
	
	mapping (string => uint256) public lastExpiryVoteIDBySymbol;
	mapping (uint256 => mapping (address => uint256)) public expiryVotesByID;
	mapping (uint256 => expiryVoteDetails) public allExpiryVotesByID;
	mapping (uint256 => mapping (address => individualExpiryVote[])) public expiryVotesToCheck;
	mapping (uint256 => uint256) public expiryVoteResults;

	struct individualFreezeVote {
		uint256 voteID;
		bool vote;
		uint256 votingPoints;
	}
	struct freezeVoteDetails{
		bool voteResult;
		bool open;
		uint256 endingTime;
	}

	struct individualExpiryVote {
		uint256 voteID;
		uint256 vote;
		uint256 votingPoints;

	}
	struct expiryVoteDetails{
		uint256 voteResult;
		bool open;
		uint256 endingTime;
	}
	

	
	//END OF NEW PART
	

	struct Votes{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}

	

    struct FreezeVotes {
        uint256 voteID;
        uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        bool open;
        bool exists;
        mapping (address => bool) hasvoted;
        uint256 voteNumber;
        //Votes[] individualVotes;
    }


    struct endOfLifeVote{
		address votingAddress;
		bool voted;
		uint256 numberOfVotingShares;
		uint256 voteValue;
	}

	struct endOfLifeVotes {
    	uint256 voteID;
    	uint256 startingTime;
    	uint256 endingTime;
    	uint256 numberOfVotingShares;
    	uint256 totalVoteValue;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    	//endOfLifeVote[] individualVotes;
    }

    struct rewardPointsSnapshot {
    	mapping (address => uint256) votingRewardpoints;
    	address[] votingRewardAddresses;
    	uint256 totalVotingRewardPoints;
    }

    

    
    
    event freezeVoteInitiated(
		string _symbol
	);

	event freezeVoteClosed (
		string  _symbol,
		bool success
	);



	function initializeContract(
		address _controlAccount,
		VotingEscrow _votingEscrow, 
		AssetFactory _assetFactory,
		address _rewardsMachineAddress
		
		) 
		public initializer 
		{
        controlAccount = _controlAccount;
        votingEscrow = _votingEscrow;
		assetFactory = _assetFactory;
		rewardsMachineAddress = _rewardsMachineAddress;
		DAOVolume = 10000000 * 1e18;
		currentRewardsRound= 1;
    }

	function transferControlAccount(
		address _newControlAccount
		)
		public
		{
			require (msg.sender == controlAccount);
			controlAccount = _newControlAccount;
		}
	
	/**
    * @notice A method that sets the DAO contract address
    * @param _DAOAddress Address of the DAO contract
    * @param _UpdaterAddress Address of the Updater contract
    */
    function setAddresses (
		address _DAOAddress,
		address _UpdaterAddress
		)
		external 
		//onlyOwner
		{
		require (msg.sender == controlAccount,"NOT_CONTROL");
		DAOAddress = _DAOAddress;
		UpdaterAddress = _UpdaterAddress;
	}

	
	/**
    * @notice A method initiates a new voting process that determines if an asset is frozen.
    * @param _symbol Symbol of the asset that is voted on
    */
    function initiateFreezeVote(
		string calldata _symbol
		)
		public 
		{
		(uint256 veAmount, uint256 lockedUntil) = votingEscrow.lockedBalances(msg.sender);	
		
		require (veAmount > 100000*(10**18),'INSUFF_ISS');
		require (assetFactory.assetExists(_symbol),'ASSET_UNKNOWN'); //check if the symbol already exists
		require (getFreezeVotes[_symbol].open == false,'VOTE_OPEN');   //check if the voting process is open
		require (assetFactory.assetFrozen(_symbol) == false,'ASSET_IS_FROZEN');   //check if the asset is frozen
		require(assetFactory.getExpiryTime(_symbol) > block.timestamp, 'ASSET_EXP');
		getFreezeVotes[_symbol].startingTime = (block.timestamp);
    	getFreezeVotes[_symbol].endingTime = block.timestamp + (7 days);
    	//getFreezeVotes[_symbol].yesVotes = 0;
    	//getFreezeVotes[_symbol].noVotes = 0;
    	getFreezeVotes[_symbol].open = true;
    	getFreezeVotes[_symbol].exists = true;
    	emit freezeVoteInitiated(_symbol);
    	//NEW
    	getFreezeVotes[_symbol].voteID = lastVoteID +1;
    	lastFreezeVoteIDBySymbol[_symbol] = lastVoteID + 1;
    	allFreezeVotesByID[lastVoteID +1].open = true;
    	lastVoteID = lastVoteID + 1;

    }


    

	/**
    * @notice A method that votes if an asset should be frozen or not
    * @param _symbol Symbol of the asset that is voted on
    *        _vote Should be set to true when it should be frozen or false if not
    */
    function voteFreezeVote (
		string  calldata _symbol, 
		bool _vote
		)
		external
		{
		(uint256 voteNumber, uint256 lockedUntil) = votingEscrow.lockedBalances(msg.sender);	
		require(hasVoted[lastFreezeVoteIDBySymbol[_symbol]][msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		hasVoted[lastFreezeVoteIDBySymbol[_symbol]][msg.sender] = true;

		require(getFreezeVotes[_symbol].exists,'UNKNOWN'); //checks if the vote id exists)
		require(getFreezeVotes[_symbol].open,'NOT_OPEN'); //checks is the vote is open)
		require(getFreezeVotes[_symbol].endingTime >= block.timestamp, 'VOTE_OPEN'); //checks if the voting period is still open
		require(lockedUntil > getFreezeVotes[_symbol].endingTime,'LOCK_TOO_SHORT');
		
		if (_vote == true) {
			getFreezeVotes[_symbol].yesVotes = getFreezeVotes[_symbol].yesVotes + voteNumber;
			
		}
		else {
			getFreezeVotes[_symbol].noVotes = getFreezeVotes[_symbol].noVotes + voteNumber;
			
		}
		
		getFreezeVotes[_symbol].voteNumber = getFreezeVotes[_symbol].voteNumber + 1;
		addRewardPoints(msg.sender,voteNumber);
		rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints = rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints + voteNumber;
		//NEW
		freezeVotesByID[lastFreezeVoteIDBySymbol[_symbol]][msg.sender] = _vote;
		individualFreezeVote memory voteToCheck;
		voteToCheck.voteID = lastFreezeVoteIDBySymbol[_symbol];
		voteToCheck.vote = _vote;
		voteToCheck.votingPoints = voteNumber;
		freezeVotesToCheck[currentRewardsRound][msg.sender].push(voteToCheck);					
	}

	/**
    * @notice A method that checks if an address has already voted in a specific freeze vote.
    * @param _address Address that is checked
    *        _symbol Symbol for which the voting process should be checked
    */
    function checkIfVoted(
		address _address, 
		string calldata _symbol
		) 
		external
		view
		returns(bool)
		{
		//uint256 voteID = lastFreezeVoteIDBySymbol[_symbol];
		return (hasVoted[lastFreezeVoteIDBySymbol[_symbol]][_address]);
	}

	/**
    * @notice A method that checks if an address has already voted in a specific expiry vote.
    * @param _address Address that is checked
    *        _symbol Symbol for which the voting process should be checked
    */
    function checkIfVotedOnExpiry(
		address _address,
		string calldata _symbol
		) 
		external
		view
		returns(bool)
		{
		//uint256 voteID = lastExpiryVoteIDBySymbol[_symbol];
		return (hasVoted[lastExpiryVoteIDBySymbol[_symbol]][_address]);
		
	}
	
	/**
    * @notice A method that closes a specific freeze voting process.
    * @param _symbol Symbol for which the voting process should be closed
    */
    function closeFreezeVote (
		string calldata _symbol
		)
		external 
		{
		require(getFreezeVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getFreezeVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getFreezeVotes[_symbol].endingTime < block.timestamp);

		
		
		if (getFreezeVotes[_symbol].yesVotes > getFreezeVotes[_symbol].noVotes){
			emit freezeVoteClosed(_symbol,true);
			assetFactory.freezeAsset(_symbol);
			freezeVoteResults[getFreezeVotes[_symbol].voteID] = true;

			allFreezeVotesByID[getFreezeVotes[_symbol].voteID].open = false;
			allFreezeVotesByID[getFreezeVotes[_symbol].voteID].voteResult = true;
		}
		else {
			emit freezeVoteClosed(_symbol,false);
			freezeVoteResults[getFreezeVotes[_symbol].voteID] = false;
			allFreezeVotesByID[getFreezeVotes[_symbol].voteID].open = false;
			allFreezeVotesByID[getFreezeVotes[_symbol].voteID].voteResult = false;
		}
		delete(getFreezeVotes[_symbol]);
		
	}

	

	/**
    * @notice A method to checks for a specific address and voteID if the freeze vote is qualifiying for rewards.
    * @param _rewardsRound The rewards round to get the data from
    *        _address Address to check
    */
    function checkFreezeVotes (
		uint256 _rewardsRound,
		address _address
		)
		external
		view
		returns (bool)
		{
		bool result = true; 
		for (uint256 s = 0; s < freezeVotesToCheck[_rewardsRound][_address].length; s += 1){
	    	uint256 voteID = freezeVotesToCheck[_rewardsRound][_address][s].voteID;
	    	//uint256 votingPoints = freezeVotesToCheck[_rewardsRound][_address][s].votingPoints;
	    	bool vote = freezeVotesToCheck[_rewardsRound][_address][s].vote;
	    	bool voteConsensusresult = freezeVoteResults[voteID]; 
	    	if (vote != voteConsensusresult && allFreezeVotesByID[voteID].open == false){
	    		result = false;
	    	}
	    	
       	}
		return (result);
		}

	/**
    * @notice A method to checks if votes are closes and if not moves the votes and rewards to the next period.
    * @param _rewardsRound The rewards round to get the data from
    *        _address Address to check
    */
    function checkVotesIfClosed (
		uint256 _rewardsRound,
		address _address
		)
		external
		{
		require (msg.sender == rewardsMachineAddress,'NOT_ALLOWED');
		uint256 numberOfVotesToCheck = freezeVotesToCheck[_rewardsRound][_address].length;
		for (uint256 s = 0; s < numberOfVotesToCheck; s += 1){
	    	uint256 voteID = freezeVotesToCheck[_rewardsRound][_address][s].voteID;
	    	
	    	if (allFreezeVotesByID[voteID].open) {
	    		uint256 votingPoints = freezeVotesToCheck[_rewardsRound][_address][s].votingPoints;
	    		// Move the votingPoints into the next rewards Round
	    		rewardPointsSnapshots[_rewardsRound].votingRewardpoints[_address] = rewardPointsSnapshots[_rewardsRound].votingRewardpoints[_address] - votingPoints;
	    		rewardPointsSnapshots[_rewardsRound+1].votingRewardpoints[_address] = rewardPointsSnapshots[_rewardsRound+1].votingRewardpoints[_address] + votingPoints;
	    		rewardPointsSnapshots[_rewardsRound+1].totalVotingRewardPoints = rewardPointsSnapshots[_rewardsRound+1].totalVotingRewardPoints + votingPoints;
	    		// Add the Votes to check into the next rewards round
	    		freezeVotesToCheck[_rewardsRound+1][_address].push(freezeVotesToCheck[_rewardsRound][_address][s]);
	    	}
	    }

	    numberOfVotesToCheck = expiryVotesToCheck[_rewardsRound][_address].length;
		for (uint256 s = 0; s < numberOfVotesToCheck; s += 1){
	    	uint256 voteID = expiryVotesToCheck[_rewardsRound][_address][s].voteID;
	    	
	    	if (allExpiryVotesByID[voteID].open) {
	    		uint256 votingPoints = expiryVotesToCheck[_rewardsRound][_address][s].votingPoints;
	    		// Move the votingPoints into the next rewards Round
	    		rewardPointsSnapshots[_rewardsRound].votingRewardpoints[_address] -= votingPoints;
	    		rewardPointsSnapshots[_rewardsRound+1].votingRewardpoints[_address] += votingPoints;
	    		rewardPointsSnapshots[_rewardsRound+1].totalVotingRewardPoints += votingPoints;
	    		// Add the Votes to check into the next rewards round
	    		expiryVotesToCheck[_rewardsRound+1][_address].push(expiryVotesToCheck[_rewardsRound][_address][s]);
	    	}

		}
		}		

	/**
    * @notice A method initiates a new voting process that determines the price of an asset at expiry.
    * @param _symbol Symbol of the asset that is voted on
    */
    function initiateEndOfLifeVote(
		string calldata _symbol
		)
		external
		{
		require (assetFactory.assetExists(_symbol),'ASSET_UNKNOWN'); //check if the symbol already exists
		require (getEndOfLifeVotes[_symbol].open == false,'VOTE_OPEN');
		require(assetFactory.getExpiryTime(_symbol) < block.timestamp, 'EXPIRY_TIME_NOT_REACHED');
		require(assetFactory.assetExpired(_symbol) == false, 'ASSET_ALREADY_EXPIRED');
		require (assetFactory.assetFrozen(_symbol) == false,'ASSET_IS_FROZEN');   //check if the asset is frozen
		require (getFreezeVotes[_symbol].open == false,'FV__OPEN');   //check if the freeze voting process is open
		
		getEndOfLifeVotes[_symbol].startingTime = (block.timestamp);
    	getEndOfLifeVotes[_symbol].endingTime = block.timestamp + 7 days;
    	//getEndOfLifeVotes[_symbol].numberOfVotingShares = 0;
    	//getEndOfLifeVotes[_symbol].totalVoteValue = 0;
    	getEndOfLifeVotes[_symbol].open = true;
    	getEndOfLifeVotes[_symbol].exists = true;
    	//NEW
    	getEndOfLifeVotes[_symbol].voteID = lastVoteID +1;
    	lastExpiryVoteIDBySymbol[_symbol] = lastVoteID + 1;
    	allExpiryVotesByID[lastVoteID +1].open = true;
    	lastVoteID = lastVoteID + 1;
    	}

	/**
    * @notice A method that votes on the expiry price
    * @param _symbol Symbol of the asset that is voted on
    *        _value Value of the price at expiry
    */
    function voteOnEndOfLifeValue (
		string  calldata _symbol,
		uint256 _value
		) 
		external
		{
		(uint256 voteNumber, uint256 lockedUntil) = votingEscrow.lockedBalances(msg.sender);	
		uint256 voteID = lastExpiryVoteIDBySymbol[_symbol];
		require(hasVoted[voteID][msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		hasVoted[voteID][msg.sender] = true;

		require(getEndOfLifeVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getEndOfLifeVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getEndOfLifeVotes[_symbol].endingTime >= block.timestamp, 'VOTE_OVER'); //checks if the voting period is still open
		require(lockedUntil > getEndOfLifeVotes[_symbol].endingTime,'LOCK_TOO_SHORT');
		require(_value < assetFactory.getUpperLimit(_symbol), 'EXCEEDS_UPPERLIMIT');
		
		getEndOfLifeVotes[_symbol].numberOfVotingShares = getEndOfLifeVotes[_symbol].numberOfVotingShares + voteNumber;
		getEndOfLifeVotes[_symbol].totalVoteValue = (getEndOfLifeVotes[_symbol].totalVoteValue + voteNumber) *_value;

		getEndOfLifeVotes[_symbol].voteNumber = getFreezeVotes[_symbol].voteNumber + 1;
		addRewardPoints(msg.sender,voteNumber);
		rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints = rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints + voteNumber;
		//NEW
		expiryVotesByID[lastExpiryVoteIDBySymbol[_symbol]][msg.sender] = _value;
		individualExpiryVote memory voteToCheck;
		voteToCheck.voteID = lastExpiryVoteIDBySymbol[_symbol];
		voteToCheck.vote = _value;
		voteToCheck.votingPoints = voteNumber;
		expiryVotesToCheck[currentRewardsRound][msg.sender].push(voteToCheck);			
	}

	/**
    * @notice A method that closes a specific expiry voting process.
    * @param _symbol Symbol for which the voting process should be closed
    */
    function closeEndOfLifeVote (
		string calldata _symbol
		)
		external
		{
		require(getEndOfLifeVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getEndOfLifeVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks if the vote is open)
		require(getEndOfLifeVotes[_symbol].endingTime < block.timestamp);  //checks if the voting period is over
		uint256 endOfLiveValue;
		getEndOfLifeVotes[_symbol].open = false;
		if (getEndOfLifeVotes[_symbol].numberOfVotingShares != 0) {
			 endOfLiveValue = getEndOfLifeVotes[_symbol].totalVoteValue / (getEndOfLifeVotes[_symbol].numberOfVotingShares);
			 expiryVoteResults[getFreezeVotes[_symbol].voteID]  = endOfLiveValue;
			 allExpiryVotesByID[getFreezeVotes[_symbol].voteID].open = false;
			 allExpiryVotesByID[getFreezeVotes[_symbol].voteID].voteResult = endOfLiveValue;
		}
		else {
			endOfLiveValue =  0;
			expiryVoteResults[getFreezeVotes[_symbol].voteID]  = endOfLiveValue;
		}
		assetFactory.setEndOfLifeValue(_symbol,endOfLiveValue);
		delete(getEndOfLifeVotes[_symbol]);
	}

	/**
    * @notice A method to checks for a specific address and voteID if the freeze vote is qualifiying for rewards.
    * @param _rewardsRound The rewards round to get the data from
    *        _address Address to check
    */
    function checkExpiryVotes (
		uint256 _rewardsRound,
		address _address
		)
		external
		view
		returns (bool)
		{
		//bool result = true;
		for (uint256 s = 0; s < expiryVotesToCheck[_rewardsRound][_address].length; s += 1){
	    	uint256 voteID = expiryVotesToCheck[_rewardsRound][_address][s].voteID;
	    	uint256 vote = expiryVotesToCheck[_rewardsRound][_address][s].vote;
	    	uint256 voteConsensusresult = expiryVoteResults[voteID];
	    	if ((vote > (voteConsensusresult * 102 / 100) || vote < (voteConsensusresult * 98 / 100)) && allExpiryVotesByID[voteID].open == false){
	    		return (false);
	    	}
	    	
       	}
		return (true);
		}

		


   	
   	/**
    * @notice A method to retrieve the reward points for an address.
    * @param _address The address to retrieve the stake for.
    * @return uint256 The amount of earned rewards points.
    */
   	function rewardPointsOf(
   		address _address
   		)
    	external
       	view
       	returns(uint256)
   		{
       	return rewardPointsSnapshots[currentRewardsRound - 1].votingRewardpoints[_address];
   	}

   	/**
    * @notice A method to retrieve the reward points for an address adjusted for votes not yet closed.
    * @param _address The address to retrieve the stake for.
    * @return uint256 The amount of earned rewards points.
    */
   	function adjustedRewardPointsOf(
   		address _address
   		)
    	external
       	view
       	returns(uint256)
   		{
   		uint256 points = rewardPointsSnapshots[currentRewardsRound -1].votingRewardpoints[_address];
   		uint256 numberOfVotesToCheck = freezeVotesToCheck[currentRewardsRound -1][_address].length;
		for (uint256 s = 0; s < numberOfVotesToCheck; s += 1){
	    	//uint256 voteID = freezeVotesToCheck[currentRewardsRound -1][_address][s].voteID;
	    	
	    	if (allFreezeVotesByID[freezeVotesToCheck[currentRewardsRound -1][_address][s].voteID].open) {
	    		uint256 votingPoints = freezeVotesToCheck[currentRewardsRound -1][_address][s].votingPoints;
	    		points -= votingPoints;
	    	}
	    }

	    numberOfVotesToCheck = expiryVotesToCheck[currentRewardsRound -1][_address].length;
		for (uint256 s = 0; s < numberOfVotesToCheck; s += 1){
	    	//uint256 voteID = expiryVotesToCheck[currentRewardsRound -1][_address][s].voteID;
	    	
	    	if (allExpiryVotesByID[expiryVotesToCheck[currentRewardsRound -1][_address][s].voteID].open) {
	    		uint256 votingPoints = expiryVotesToCheck[currentRewardsRound -1][_address][s].votingPoints;
	    		points -= votingPoints;
	    	}

		}

       	return (points);
   	}

   	function addRewardPoints(
   		address _address, 
   		uint256 _amount
   		)
    	internal
   		{
	       	rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] = rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] + _amount;
   	}

   	/**
    * @notice A method to add  reward points for an address. Can only be called by the DAO contract.
    * @param _address The address to retrieve the stake for.
    + @param _amount The amount of reward points to be added
    */	
   	function addRewardPointsDAO(
   		address _address, 
   		uint256 _amount
   		)
    	external
   		{
	       	require (msg.sender == DAOAddress || msg.sender == UpdaterAddress || msg.sender == rewardsMachineAddress);
	       	rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] = rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] + _amount;
   	}

   	/**
    * @notice A method to add  total reward points. Can only be called by the DAO contract.
    + @param _amount The amount of total reward points to be added
    */	
   	function addTotalRewardPointsDAO(
   		uint256 _amount
   		)
    	external
   		{
	       	require (msg.sender == DAOAddress || msg.sender == UpdaterAddress || msg.sender == rewardsMachineAddress);
	       	rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints = rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints + _amount;
   	}




   	function getTotalRewardPoints()
	   	external
	   	view
	   	returns(uint256)
	   	{
	   		return (rewardPointsSnapshots[currentRewardsRound -1].totalVotingRewardPoints);
   	}

   	/**
    * @notice A method to reset all reward points to zero.
    */
   	function resetRewardPoints () 
    	external
   		{
	       	require (msg.sender == rewardsMachineAddress,'NOT_ALLOWED');
	       	currentRewardsRound = currentRewardsRound +1;
	}

}