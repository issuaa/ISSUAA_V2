// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//pragma experimental ABIEncoderV2;
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./VotingEscrow.sol";
import "./GovernanceToken.sol";
import "./VoteMachine.sol";
import "./assetFactory.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";



contract DAO is Initializable{
	
	using SafeMath for uint256;
	VoteMachine public voteMachine;
	VotingEscrow public votingEscrow;
	AssetFactory public assetFactory;
	GovernanceToken public governanceToken;
	uint256 public numberOfGrantVotes;
	uint256 public numberOfNewAssetVotes;
	address[] public grantVoteAddresses;
	string[] public newAssetVoteSymbols;
	uint256 DAOVolume;

    struct grantFundingVote{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}

	struct grantFundingVotes {
    	uint256 voteID;
        uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 amount;
        string description;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    }

	mapping(address => grantFundingVotes) public getGrantVotes;

	struct newAssetVote{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}

	struct newAssetVotes {
    	uint256 voteID;
        uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        string symbol;
        string name;
        string description;
        uint256 upperLimit;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    }

    mapping (uint256 => mapping (address => bool)) public hasVoted;

	mapping(string => newAssetVotes) public getNewAssetVotes;

	//NEW
	uint256 public lastVoteID;
	mapping (address => uint256) public lastGrantVoteIDByReceiver;
	mapping (string => uint256) public lastNewAssetVoteIDBySymbol;

	mapping (uint256 => grantVoteDetails) public allGrantVotesByID;
	mapping (uint256 => newAssetVoteDetails) public allNewAssetVotesByID;

	struct grantVoteDetails{
		bool voteResult;
		bool open;
		uint256 endingTime;
	}
	struct newAssetVoteDetails{
		bool voteResult;
		bool open;
		uint256 endingTime;
	}


	function initializeContract(
		VotingEscrow _votingEscrow, 
		VoteMachine _voteMachine,
		AssetFactory _assetFactory,
		GovernanceToken _governanceToken,
		uint256 _DAOVolume,
		uint256 _lastVoteID
		) 
		public initializer 
		{
        voteMachine = _voteMachine;
        votingEscrow = _votingEscrow;
		assetFactory = _assetFactory;
		governanceToken = _governanceToken;
		DAOVolume = _DAOVolume * 1e18;
		lastVoteID = _lastVoteID;
    }

	
	event grantFundingVoteInitiated(
		address _receiver,
		uint256 _amount,
		string _description
	);

	event grantFundingVoteClosed(
		address _receiver,
		bool success
	);

	event newAssetVoteInitiated(
		string _symbol,
		string _name,
		uint256 _upperLimit,
		string _description
	);

	event newAssetVoteClosed(
		string _symbol,
		bool success
	);

	

	
	
	
	/**
    * @notice A method initiates a new voting process if a certain address gets funding.
    * @param _receiver Address that will receive the grant
    *        _amount   Amount of grant in WEI
    *        _description Description for what you request funding
    */
    function initiateGrantFundingVote(
		address _receiver,
		uint256 _amount,
		string calldata _description
		)
		external 
		{
		(uint256 voteNumber, uint256 lockedUntil) = votingEscrow.lockedBalances(msg.sender);	
		require (voteNumber > 100000*(10**18),'INSUFFICIENT_ISS_STAKED');
		require (getGrantVotes[_receiver].open == false,'VOTE_OPEN');   //check if the voting process is open
		require (_amount < (100000 * (10**18)),'AMOUNT_TOO_HIGH');
		if (getGrantVotes[_receiver].exists != true)
			{
			numberOfGrantVotes +=1;
    		grantVoteAddresses.push(_receiver);
			}
		DAOVolume = DAOVolume.sub(_amount);
		//delete (getGrantVotes[_receiver].individualVotes);
		
		getGrantVotes[_receiver].startingTime = (block.timestamp);
    	getGrantVotes[_receiver].endingTime = block.timestamp.add(7 days);
    	getGrantVotes[_receiver].yesVotes = 0;
    	getGrantVotes[_receiver].noVotes = 0;
    	getGrantVotes[_receiver].open = true;
    	getGrantVotes[_receiver].exists = true;
    	getGrantVotes[_receiver].amount = _amount;    	
    	getGrantVotes[_receiver].description = _description;
    	emit grantFundingVoteInitiated(_receiver, _amount, _description);
    	//New
    	getGrantVotes[_receiver].voteID = lastVoteID +1;
    	lastGrantVoteIDByReceiver[_receiver] = lastVoteID + 1;
    	allGrantVotesByID[lastVoteID +1].open = true;
    	lastVoteID = lastVoteID + 1;
    }



	/**
    * @notice A method that votes if a suggest grant will be given or not
    * @param _receiver Address that has requested a DAO grant
    *.       _vote     True or False aka Yes or No
    */
    function voteGrantFundingVote (
		address _receiver, 
		bool _vote
		)
		external
		{
		(uint256 voteNumber, uint256 lockedUntil) = votingEscrow.lockedBalances(msg.sender);
		require(lockedUntil > getGrantVotes[_receiver].endingTime,'LOCK_TOO_SHORT');	
		uint256 voteID = lastGrantVoteIDByReceiver[_receiver];
		require(hasVoted[voteID][msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		hasVoted[voteID][msg.sender] = true;

		require(getGrantVotes[_receiver].exists,'UNKNOWN'); //checks if the grant request exists)
		require(getGrantVotes[_receiver].open,'NOT_OPEN'); //checks is the vote is open)
		require(getGrantVotes[_receiver].endingTime >= block.timestamp, 'VOTE_ENDED'); //checks if the voting period is still open
		
		
		if (_vote == true) {
			getGrantVotes[_receiver].yesVotes = getGrantVotes[_receiver].yesVotes.add(voteNumber);
			//individualVote.yesVotes = voteNumber;

		}
		else {
			getGrantVotes[_receiver].noVotes = getGrantVotes[_receiver].noVotes.add(voteNumber);
			//individualVote.noVotes = voteNumber;
		}
		//getGrantVotes[_receiver].hasvoted[msg.sender] = true;
		//getGrantVotes[_receiver].individualVotes.push(individualVote);
		getGrantVotes[_receiver].voteNumber = getGrantVotes[_receiver].voteNumber.add(1);
		voteMachine.addRewardPointsDAO(msg.sender,voteNumber);
		voteMachine.addTotalRewardPointsDAO(voteNumber);		
	}

	/**
    * @notice A method that checks if an address has already voted in a grant Vote.
    * @param _address Address that is checked
    *        _receiver Address for which the voting process should be checked
    */
    function checkIfVotedGrantFunding(
		address _address, 
		address _receiver
		) 
		external
		view
		returns(bool)
		{
		uint256 voteID = lastGrantVoteIDByReceiver[_receiver];
		return (hasVoted[voteID][_address]);
	}

	
	/**
    * @notice A method that closes a specific grant funding voting process.
    * @param _receiver Address for which the voting process should be closed
    */
    function closeGrantFundingVote (
		address _receiver
		)
		external 
		{
		require(getGrantVotes[_receiver].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getGrantVotes[_receiver].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getGrantVotes[_receiver].endingTime < block.timestamp);
		getGrantVotes[_receiver].open = false;
		
		
		if (getGrantVotes[_receiver].yesVotes > getGrantVotes[_receiver].noVotes){
			governanceToken.transfer(_receiver,getGrantVotes[_receiver].amount);
			emit grantFundingVoteClosed(_receiver,true);	
			}
		else {
			emit grantFundingVoteClosed(_receiver,false);
			DAOVolume = DAOVolume.add(getGrantVotes[_receiver].amount);
		}
		
		
		//delete(getGrantVotes[_receiver]);
		//emit grantFundingVoteClosed(_receiver,true);		
	}

	/**
	* @notice A method that gets the details of a specific grant poposal Vote
	* @param _address Address to check
	*/
	function getGrantVoteDetails(
		address _address
		)
		external
		view
		//returns (uint256,uint256,uint256,uint256,bool,bool,uint256,string memory)
		returns (uint256,uint256,uint256,uint256,string memory,bool)
		{
			//uint256 startingTime = getGrantVotes[_address].startingTime;
			uint256 endingTime = getGrantVotes[_address].endingTime;
			uint256 yesVotes = getGrantVotes[_address].yesVotes;
			uint256 noVotes = getGrantVotes[_address].noVotes;
			uint256 grantAmount = getGrantVotes[_address].amount;
			//bool proposalExists = getGrantVotes[_address].exists;
			string memory description = getGrantVotes[_address].description;
			bool grantVoteOpen = getGrantVotes[_address].open;
			
			return (endingTime,yesVotes,noVotes,grantAmount,description,grantVoteOpen);
		}


	// NEW ASSET CREATION STARTING HERE

    /**
    * @notice A method initiates a new voting process if a certain address gets funding.
    * @param _symbol Symbol of the new asset
    *        _name Name of the new asset
    *        _upperLimit  Upper limit for the new asset
    *        _description Description of the asset
    */
    function initiateNewAssetVote(
		string calldata _symbol,
		string calldata _name,
		uint256 _upperLimit,
		string calldata _description
		)
		external 
		{
		uint256 voteNumber = votingEscrow.balanceOf(msg.sender);	
		require (voteNumber > 100000*(10**18),'INSUFFICIENT_ISS_STAKED');
		require (getNewAssetVotes[_symbol].open == false,'VOTE_OPEN');   //check if the voting process is open
		require (assetFactory.assetExists(_symbol) == false,'ASSET_EXISTS');
		if (getNewAssetVotes[_symbol].exists == false){
			numberOfNewAssetVotes +=1;
    		newAssetVoteSymbols.push(_symbol);
		}
		//delete (getNewAssetVotes[_symbol].individualVotes);
		
		
		getNewAssetVotes[_symbol].startingTime = (block.timestamp);
    	getNewAssetVotes[_symbol].endingTime = block.timestamp.add(7 days);
    	getNewAssetVotes[_symbol].yesVotes = 0;
    	getNewAssetVotes[_symbol].noVotes = 0;
    	getNewAssetVotes[_symbol].open = true;
    	getNewAssetVotes[_symbol].exists = true;
    	getNewAssetVotes[_symbol].name = _name;    	
    	getNewAssetVotes[_symbol].upperLimit = _upperLimit;   	
    	getNewAssetVotes[_symbol].description = _description;
    	emit newAssetVoteInitiated ( _symbol, _name, _upperLimit, _description);
    	//NEW
    	getNewAssetVotes[_symbol].voteID = lastVoteID +1;
    	lastNewAssetVoteIDBySymbol[_symbol] = lastVoteID + 1;
    	allNewAssetVotesByID[lastVoteID +1].open = true;
    	lastVoteID = lastVoteID + 1;
    	
    }


	/**
    * @notice A method that votes if a suggest grant will be given or not
    * @param _symbol Symbol of the new asset that is voted on
    *.       _vote     True or False aka Yes or No
    */
    function voteNewAssetVote (
		string calldata _symbol, 
		bool _vote
		)
		external
		{
		(uint256 voteNumber, uint256 lockedUntil) = votingEscrow.lockedBalances(msg.sender);
		require(lockedUntil > getNewAssetVotes[_symbol].endingTime,'LOCK_TOO_SHORT');	

		uint256 voteID = lastNewAssetVoteIDBySymbol[_symbol];
		require(hasVoted[voteID][msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		hasVoted[voteID][msg.sender] = true;

		require(getNewAssetVotes[_symbol].exists,'UNKNOWN'); //checks if the newAsset vote exists)
		require(getNewAssetVotes[_symbol].open,'NOT_OPEN'); //checks is the vote is open)
		require(getNewAssetVotes[_symbol].endingTime >= block.timestamp, 'VOTE_ENDED'); //checks if the voting period is still open
		//require(getNewAssetVotes[_symbol].hasvoted[msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		
		newAssetVote memory individualVote;
		individualVote.voted = true;
		individualVote.votingAddress = msg.sender;
		if (_vote == true) {
			getNewAssetVotes[_symbol].yesVotes = getNewAssetVotes[_symbol].yesVotes.add(voteNumber);
			individualVote.yesVotes = voteNumber;

		}
		else {
			getNewAssetVotes[_symbol].noVotes = getNewAssetVotes[_symbol].noVotes.add(voteNumber);
			individualVote.noVotes = voteNumber;
		}
		//getNewAssetVotes[_symbol].hasvoted[msg.sender] = true;
		//getNewAssetVotes[_symbol].individualVotes.push(individualVote);
		getNewAssetVotes[_symbol].voteNumber = getNewAssetVotes[_symbol].voteNumber.add(1);	

		voteMachine.addRewardPointsDAO(msg.sender,voteNumber);
		voteMachine.addTotalRewardPointsDAO(voteNumber);	
	}

	/**
    * @notice A method that checks if an address has already voted in a new asset Vote.
    * @param _address Address that is checked
    *        _symbol Symbol of the asset that is checked
    */
    function checkIfVotedNewAsset(
		address _address, 
		string calldata _symbol
		) 
		external
		view
		returns(bool)
		{
		uint256 voteID = lastNewAssetVoteIDBySymbol[_symbol];
		return (hasVoted[voteID][_address]);
	}

	
	/**
    * @notice A method that closes a specific new asset voting process.
    * @param _symbol Symbol of the potential new asset for which the voting process should be closed
    */
    function closeNewAssetVote (
		string calldata _symbol
		)
		external 
		{
		require(getNewAssetVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getNewAssetVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks if the vote is open)
		require(getNewAssetVotes[_symbol].endingTime < block.timestamp);
		getNewAssetVotes[_symbol].open = false;
		
		
		if (getNewAssetVotes[_symbol].yesVotes > getNewAssetVotes[_symbol].noVotes){
			emit newAssetVoteClosed(_symbol,true);
			assetFactory.createAssets(getNewAssetVotes[_symbol].name,_symbol,getNewAssetVotes[_symbol].description,getNewAssetVotes[_symbol].upperLimit);	
		}
		else {
			emit newAssetVoteClosed(_symbol,false);
		}
		
		delete(getNewAssetVotes[_symbol]);
		
	}
    //END

}