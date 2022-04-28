// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAssetFactory {
    function transferControllAccount(address _newControllAccount) external;
	event Freeze(string _symbol);
    event EndOfLiveValueSet (string _symbol, uint256 _value);
    event Mint (string _symbol, uint256 _amount);
    event Burn (string _symbol, uint256 _amount); 
    event BurnExpired (string _symbol, uint256 _amount1,uint256 _amount2); 
	event NewAsset (string _name, string _symbol, string _description, uint256 _upperLimit);
	event BurnIPT (uint256 _amount, address _address);

	
	function setVoteMachineAddress (address _address) external ;
	function setRewardsMachineAddress (address _address) external;
	function setMarketFactoryAddress (address _address) external;
	function setMarketRouterAddress (address _address) external;
	function createAssets (string calldata _name, string calldata _symbol, string calldata _description, uint256 _upperLimit) external; 
	function assetExists (string calldata _symbol) external view returns(bool);
	function assetFrozen (string calldata _symbol) external view returns(bool);
	function assetExpired (string calldata _symbol) external view returns(bool);
	function getExpiryTime(string calldata _symbol) external view returns(uint256);
	function getUpperLimit(string calldata _symbol) external view returns(uint256);
	function getExpiryPrice(string calldata _symbol) external view returns(uint256);
	function getTokenAddresses(string calldata _symbol) external view returns(address,address);
	function mintAssets (string calldata _symbol, uint256 _amount) external;
	function burnAssets (string calldata _symbol, uint256 _amount) external;
	function burnExpiredAssets (string calldata _symbol, uint256 _amount1, uint256 _amount2) external;
	function burnGovernanceToken (uint256 _amount) external; 
    function freezeAsset(string calldata _symbol) external;
	function setEndOfLifeValue(string calldata _symbol, uint256 _value) external;
	function harvestFees(address _pairAddress) external;
}