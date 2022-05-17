// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./AssetToken.sol";
import "./TokenFactory.sol";
import "./RewardsMachine.sol";
import "./issuaaLibrary.sol";
import "./MarketFactory.sol";
import "./interfaces/IMarketPair.sol";
import "./interfaces/IMarketRouter01.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


//import "../interfaces/RewardsMachineInterface.sol";



contract AssetFactory is Initializable {
	using SafeMath for uint256;
	bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));

	uint256 public feePool;
    uint256 public assetNumber;
	address public USDCaddress;
    address public tokenFactoryAddress;
    address public voteMachineAddress;
    address public rewardsMachineAddress;
    address public marketFactoryAddress;
    address public marketRouterAddress;
    address public ISSAddress;
    string[] public assets;
    address public controlAccount;
    mapping(string => issuaaLibrary.Asset) public getAsset;
    mapping (address => uint256) public harvestCooldown;

	function initializeContract(
		address _governanceTokenAddress, 
		address _tokenFactoryAddress,
		address _controlAccount,
		address _USDCAddress
		) 
		public initializer 
		{
        ISSAddress = _governanceTokenAddress;
		tokenFactoryAddress = _tokenFactoryAddress;
		controlAccount = _controlAccount;
		USDCaddress = _USDCAddress;
    }

	function transferControlAccount(
		address _newControlAccount
		)
		public
		{
			require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
			controlAccount = _newControlAccount;
		}
		
	event Freeze(
        string _symbol
    );

    event EndOfLiveValueSet (
    	string _symbol, 
    	uint256 _value
    );

    event Mint (
		string _symbol, 
		uint256 _amount
	) ;

    event Burn (
		string _symbol, 
		uint256 _amount
	); 

    event BurnExpired (
		string _symbol, 
		uint256 _amount1,
		uint256 _amount2
	); 

	event NewAsset (
		string _name, 
		string _symbol, 
		string _description, 
		uint256 _upperLimit
	);

	

	/**
	* @notice A method to safely transfer ERV20 tokens.
	* @param _token Address of the token.
		_from Address from which the token will be transfered.
		_to Address to which the tokens will be transfered
		_value Amount of tokens to be sent.	
	*/
	function _transferFrom(
		address _token, 
		address _from, 
		address _to, 
		uint256 _value
		) 
		private 
		{
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(SELECTOR, _from, _to, _value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'FAILED');
    }

	/**
	* @notice A method to set the address of the voting machine contract. Ownly executable for the owner.
	* @param _address Address of the voting machine contract.
	*/
	function setVoteMachineAddress (
		address _address
		) 
		external 
		//onlyOwner
		{
		require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
		voteMachineAddress = _address;
	}

	/**
	* @notice A method to set the address of the voting machine contract. Ownly executable for the owner.
	* @param _address Address of the rewards machine contract.
	*/
	function setRewardsMachineAddress (
		address _address
		) 
		external 
		//onlyOwner
		{
		require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
		rewardsMachineAddress = _address;
	}

	/**
	* @notice A method to set the address of the market factory contract. Ownly executable for the owner.
	* @param _address Address of the market factory contract.
	*/
	function setMarketFactoryAddress (
		address _address
		) 
		external 
		//onlyOwner
		{
		require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
		marketFactoryAddress = _address;
	}

	/**
	* @notice A method to set the address of the market router contract. Ownly executable for the owner.
	* @param _address Address of the market router contract.
	*/
	function setMarketRouterAddress (
		address _address
		) 
		external
		//onlyOwner
		{
		require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
		marketRouterAddress = _address;
	}

	/**
	* @notice A method to define ad create a new Asset.
	* @param _name Name of the new Asset.
		_symbol Symbol of the new Asset.
		_description Short description of the asset
		_upperLimit Upper limit of the assets, that defines when the asset is frozen.	
	*/
	function createAssets (
		string calldata _name, 
		string calldata _symbol, 
		string calldata _description, 
		uint256 _upperLimit
		) 
		external 
		//onlyOwner
		{
		require (msg.sender == controlAccount,"NOT_CONTROL_ACCOUNT");
		require (getAsset[_symbol].exists == false,'EXISTS'); assets.push(_symbol);
		assetNumber = assetNumber.add(1);
		getAsset[_symbol].name = _name;
		getAsset[_symbol].description = _description;
		getAsset[_symbol].Token1 = TokenFactory(tokenFactoryAddress).deployToken(_name,_symbol);
		getAsset[_symbol].Token2 = TokenFactory(tokenFactoryAddress).deployToken(_name,string(abi.encodePacked("i",_symbol)));
		getAsset[_symbol].upperLimit = _upperLimit;
		getAsset[_symbol].expiryTime = block.timestamp.add(365 days);
		getAsset[_symbol].exists = true;
		emit NewAsset ( _name, _symbol, _description, _upperLimit);
		//MarketFactory(marketFactoryAddress).createPair(getAsset[_symbol].Token1,USDCaddress);
		//MarketFactory(marketFactoryAddress).createPair(getAsset[_symbol].Token2,USDCaddress);
	}


	/**
	* @notice A method that checks if a specific asset does already exist.
	* @param _symbol Symbol of the asset to check.
	* @return bool Returns true if the asset exists and false if not.
	*/
	function assetExists (
		string calldata _symbol
		)
		external 
		view 
		returns(bool)
		{
		return(getAsset[_symbol].exists);
	}

	/**
	* @notice A method that checks if a specific asset is frozen.
	* @param _symbol Symbol of the asset to check.
	* @return bool Returns true if the asset is frozen or not.
	*/
	function assetFrozen (
		string calldata _symbol
		)
		external 
		view 
		returns(bool)
		{
		return(getAsset[_symbol].frozen);
	}
	
	/**
	* @notice A method that checks if a specific asset is marked as expired.
	* @param _symbol Symbol of the asset to check.
	* @return bool Returns true if the asset is expired or not.
	*/
	function assetExpired (
		string calldata _symbol
		)
		external 
		view 
		returns(bool)
		{
		return(getAsset[_symbol].expired);
	}

	/**
	* @notice A message that checks the expiry time of an asset.
	* @param _symbol Symbol of the asset to check.
	* @return uint256 Returns the expiry time as a timestamp.
	*/
	function getExpiryTime(
		string calldata _symbol
		)
		external 
		view 
		returns(uint256)
		{
		return (getAsset[_symbol].expiryTime);
	}


	/**
	* @notice A message that checks the upper limit an asset.
	* @param _symbol Symbol of the asset to check.
	* @return uint256 Returns the upper limit.
	*/
	function getUpperLimit(
		string calldata _symbol
		)
		external 
		view 
		returns(uint256)
		{
		return (getAsset[_symbol].upperLimit);
	}

	/**
	* @notice A message that checks the expiry price of an asset.
	* @param _symbol Symbol of the asset to check.
	* @return uint256 Returns the expiry price.
	*/
	function getExpiryPrice(
		string calldata _symbol
		) 
		external 
		view 
		returns(uint256)
		{
		return (getAsset[_symbol].endOfLifeValue);
	}

	/**
	* @notice A message that checks the token addresses for an asset symbol.
	* @param _symbol Symbol of the asset to check.
	* @return address, address Returns the long und short token addresses.
	*/
	function getTokenAddresses(
		string calldata _symbol
		) 
		external 
		view 
		returns(address,address)
		{
		return (getAsset[_symbol].Token1, getAsset[_symbol].Token2);
	}

	/**
	* @notice A message that mints a specific asset. The caller will get both long and short
	*         assets and will pay the upper limit in USD stable coins as a price.
	* @param _symbol Symbol of the asset to mint.
	*/
	function mintAssets (
		string calldata _symbol, 
		uint256 _amount
		) 
		external 
		{
		require (getAsset[_symbol].frozen == false && getAsset[_symbol].expiryTime > block.timestamp,'INVALID'); 
		IERC20(USDCaddress).transferFrom(msg.sender,address(this),_amount);
		uint256 USDDecimals = ERC20(USDCaddress).decimals();
		uint256 tokenAmount = _amount.mul(10**(18-USDDecimals)).mul(1000).div(getAsset[_symbol].upperLimit);
		TokenFactory(tokenFactoryAddress).mint(getAsset[_symbol].Token1, msg.sender, tokenAmount);
		TokenFactory(tokenFactoryAddress).mint(getAsset[_symbol].Token2, msg.sender, tokenAmount);
		emit Mint(_symbol, _amount);
	}

	/**
	* @notice A message that burns a specific asset to get USD stable coins in return.
	* @param _symbol Symbol of the asset to burn.
	*        _amount Amount of long and short tokens to be burned.
	*/
	function burnAssets (
		string calldata _symbol,
		uint256 _amount
		) 
		external 
		{
		require(getAsset[_symbol].expired == false,'EXPIRED');
		uint256 USDDecimals = ERC20(USDCaddress).decimals();
		uint256 amountOut = _amount.mul(getAsset[_symbol].upperLimit).div(10**(18-USDDecimals)).div(1000);
		
		if (getAsset[_symbol].frozen) {
			IERC20(USDCaddress).transfer(msg.sender,amountOut);
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token1, msg.sender, _amount);
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token2, msg.sender, AssetToken(getAsset[_symbol].Token2).balanceOf(msg.sender));
			//AssetToken(getAsset[_symbol].Token1).transferFrom(msg.sender, address(this), _amount);
			//AssetToken(getAsset[_symbol].Token2).transferFrom(msg.sender, address(this), AssetToken(getAsset[_symbol].Token2).balanceOf(msg.sender));
		}
		else {
			IERC20(USDCaddress).transfer(msg.sender,amountOut*98/100);
			feePool += amountOut*2/100;
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token1, msg.sender, _amount);
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token2, msg.sender, _amount);
			
			//AssetToken(getAsset[_symbol].Token1).burn(msg.sender, _amount);
			//AssetToken(getAsset[_symbol].Token2).burn(msg.sender, _amount);

		}
		emit Burn (_symbol, _amount);	
	}

	/**
	* @notice A method that burns a specific expired asset to get USD stable coins in return.
	* @param _symbol Symbol of the asset to burn.
	*        _amount1 Amount of the long token to be burned.
	*        _amount2 Amount of the short token to be burned.
	*/
	function burnExpiredAssets (
		string calldata _symbol, 
		uint256 _amount1, 
		uint256 _amount2
		) 
		external 
		{
		require(getAsset[_symbol].expired == true,'NOT_EXPIRED');
		require(getAsset[_symbol].frozen == false,'FROZEN');
		require(getAsset[_symbol].endOfLifeValue > 0,'VOTE_NOT_CLOSED');
		
		uint256 USDDecimals = ERC20(USDCaddress).decimals();
		uint256 valueShort = getAsset[_symbol].upperLimit.sub(getAsset[_symbol].endOfLifeValue);
		uint256 amountOut1 = _amount1.mul(getAsset[_symbol].endOfLifeValue).div(10**(18-USDDecimals)).div(1000);
		uint256 amountOut2 = _amount2.mul(valueShort).div(10**(18-USDDecimals)).div(1000);
        IERC20(USDCaddress).transfer(msg.sender,amountOut1.add(amountOut2));
        AssetToken(getAsset[_symbol].Token1).transferFrom(msg.sender, address(this), _amount1);
        AssetToken(getAsset[_symbol].Token2).transferFrom(msg.sender, address(this), _amount2);
        emit BurnExpired (_symbol, _amount1, _amount2);
	}

    /**
	* @notice A method that freezes a specific asset. Can only be called by the votemachine contract.
	* @param _symbol Symbol of the asset to freeze.
	*/
    function freezeAsset(
    	string calldata _symbol
    	) 
    	external 
    	{
    	require(msg.sender == voteMachineAddress);
    	getAsset[_symbol].frozen = true;
    	emit Freeze (_symbol);
    }

    /**
	* @notice A method that sets the expiry value of a specific asset. Can only be called by the votemachine contract.
	* @param _symbol Symbol of the asset to freeze.
	*        _value Value of the asset at the expiry time
	*/
	function setEndOfLifeValue(
    	string calldata _symbol, 
    	uint256 _value
    	) 
    	external 
    	{
    	require(msg.sender == voteMachineAddress);
    	getAsset[_symbol].endOfLifeValue = _value;
    	getAsset[_symbol].expired = true;
    	emit EndOfLiveValueSet (_symbol,_value);
    }

    /**
	* @notice A method that unstakes liquidiy provider tokens, which have been earned as fees for the governance token.
	*         Asset tokens are then sold for USD stable coins.
	* @param _pairAddress Address of the market pair.
	*/
	function harvestFees(
    	address _pairAddress
    	)
    	external
    	
    	{
    	require (harvestCooldown[_pairAddress] < block.timestamp,'COOLDOWN');
    	harvestCooldown[_pairAddress] = (block.timestamp + 60 minutes);
    	address token0 = IMarketPair(_pairAddress).token0();
        address token1 = IMarketPair(_pairAddress).token1();

        // get balance
    	uint256 liquidity = IMarketPair(_pairAddress).balanceOf(address(this));
    	// burn balance
    	IMarketPair(_pairAddress).approve(marketRouterAddress,liquidity);
    	(uint256 amount0, uint256 amount1) = IMarketRouter01(marketRouterAddress).removeLiquidity(token0,token1,liquidity,0,0,address(this),block.timestamp.add(1 hours));
        //uint256 tokenAmt = token0 == USDCaddress ? amount1 : amount0;
        uint256 usdAmt = token0 == USDCaddress ? amount0 : amount1;
        address tokenAddress = token0 == USDCaddress ? token1 : token0;
        uint256 tokenAmt = AssetToken(tokenAddress).balanceOf(address(this));
    	
    	// trade asset against USD
    	IERC20(tokenAddress).approve(marketRouterAddress,tokenAmt);
    	address[] memory path = new address[](2);
    	path[0] = tokenAddress;
   		path[1] = USDCaddress;
   		
   		(uint256 _reserve0, uint256 _reserve1) = IMarketPair(_pairAddress).getReserves();
   		(uint256 tokenReserves, uint256 USDCReserves) = tokenAddress < USDCaddress ? (_reserve0,_reserve1) : (_reserve1,_reserve0);
   		if (tokenAmt > tokenReserves * 6 / 1000) {tokenAmt = tokenReserves * 6 / 1000;}
   		//uint256 expectedUSDCAmt = USDCReserves - ((tokenReserves * USDCReserves)/(tokenAmt + tokenReserves));
   		
   		uint256[] memory amounts = IMarketRouter01(marketRouterAddress).swapExactTokensForTokens(tokenAmt,0,path,address(this),block.timestamp.add(1 hours));
    	usdAmt = usdAmt.add(amounts[1]);
    	feePool += usdAmt;

    	//Sell fees for ISS and send the ISS to treasury
    	address[] memory ISSpath = new address[](2);
    	ISSpath[0] = USDCaddress;
    	ISSpath[1] = ISSAddress;
    	address ISSPairAddress = MarketFactory(marketFactoryAddress).getPair(ISSAddress,USDCaddress);
    	(_reserve0, _reserve1) = IMarketPair(ISSPairAddress).getReserves();
    	
    	uint256 ISSReserves;
    	(ISSReserves, USDCReserves) = ISSAddress < USDCaddress ? (_reserve0,_reserve1) : (_reserve1,_reserve0);
    	uint256 USDCAmt = feePool;
    	if (USDCAmt > ISSReserves * 6 / 1000) {USDCAmt = ISSReserves * 6 / 1000;}
    	feePool -= USDCAmt;
    	IERC20(USDCaddress).approve(marketRouterAddress,USDCAmt);
    	amounts = IMarketRouter01(marketRouterAddress).swapExactTokensForTokens(USDCAmt,0,ISSpath,address(this),block.timestamp.add(1 hours));
    	uint256 contractISSBalance = IERC20(ISSAddress).balanceOf(address(this));
    	RewardsMachine(rewardsMachineAddress).burnAssetFactoryISS(contractISSBalance);
    	
    	
    }

}