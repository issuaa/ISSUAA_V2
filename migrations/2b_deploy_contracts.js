// Fetch the GovernanceToken contract data from the GovernanceToken.json file
const GovernanceToken = artifacts.require("./GovernanceToken.sol");

const ERC20 = artifacts.require("../openzeppelin/ERC20.sol");
const VotingEscrow = artifacts.require("./VotingEscrow.sol")
const AssetFactory = artifacts.require("./assetFactory.sol");
const VoteMachine = artifacts.require("./VoteMachine.sol");
const RewardsMachine = artifacts.require("./RewardsMachine.sol");
const TokenFactory = artifacts.require("./TokenFactory.sol");
const MarketFactory = artifacts.require("./MarketFactory.sol");
const MarketRouter = artifacts.require("./MarketRouter.sol");
const MarketPair = artifacts.require("./MarketPair.sol");
const DAO = artifacts.require("./DAO.sol");
const AssetToken = artifacts.require("./AssetToken.sol");
const Upgrader = artifacts.require("./Upgrader.sol");
const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const { admin } = require('@openzeppelin/truffle-upgrades');
var USDCaddress = "0x055Ca4CCe0bf1D35e8D7953F5eCaDD0640Be8D46";
//const multisigAddress = "0x61bE0EC6Db427eD02a184A06963F44684547016E";

//let dAOAmount = '10000000000000000000000000'
//let rewardsAmount = '40000000000000000000000000'
//const deployerAddress = "0x644f26199C391FaAd1322f8F17606E3BbE1673D1";

var assetFactory;
var voteMachine;
var rewardsMachine;
var tokenFactory;
var marketFactory;
var marketRouter;
var marketPair;
var dAO;
var now = new Date()
var year = now.getFullYear()+1-2000;
var month = now.getMonth()+1
year = year.toString()
let zero = "0"
if (month <10) {month = zero.concat(month.toString())} else {month = month.toString()}




// JavaScript export

module.exports = async function(deployer,network,accounts) {
    var ISSAddress;
    if (network === "polygon") {ISSAddress = "0x3c2269811836af69497E5F486A85D7316753cf62"; USDCaddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"}
    else if (network === "ethereum") {ISSAddress = "0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675"; USDCaddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"}
    else if (network === "bsc") {ISSAddress = "0x3c2269811836af69497E5F486A85D7316753cf62"; USDCaddress = "0x672147dD47674757C457eB155BAA382cc10705Dd"}
    else if (network === "avalanche") {ISSAddress = "0x3c2269811836af69497E5F486A85D7316753cf62"; USDCaddress = "0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664"}
    else if (network === "arbitrum") {ISSAddress = "0x3c2269811836af69497E5F486A85D7316753cf62"}
    else if (network === "optimism") {ISSAddress = "0x3c2269811836af69497E5F486A85D7316753cf62"}
    else if (network === "fantom") {ISSAddress = "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7"}

    else if (network === "mumbai") {ISSAddress = "0xAF28499cbBd64bE71B5D6386888b68e177861025"; USDCaddress = "0x85f825bD8BcC002fF8E201926B7b334e0E05a91C"}
    else if (network === "bscTestnet") {ISSAddress = "0x6bf5ca5639133B622c71BA23abd73948CEf2675f"}
    else if (network === "fuji") {ISSAddress = "0xd9d40DB84625663a8c214977a088bc624E88006F"}
    else if (network === "rinkeby") {ISSAddress = "0xeFE5922a09E954b7d4c4ea89dc5Ffd08Afa77B8F"}
    else if (network === "arbitrumRinkeby") {ISSAddress = "0x79e35AaaCc316D1A3403424aEEbE4cD9a5EBA6A2"}
    else if (network === "fantomTestnet") {ISSAddress = "0x56e09a54bed3dEF906d29dC721b0AB3586E9E021"}
    
    else if (network === "kovan") {ISSAddress = "0x72aB53a133b27Fa428ca7Dc263080807AfEc91b5"}    
    else if (network === "development") {ISSAddress = "0x356F26716Fe237aD540F53D926D557Ae352Ea73E"; USDCaddress = "0x055Ca4CCe0bf1D35e8D7953F5eCaDD0640Be8D46"}
    const governanceToken = await GovernanceToken.at(ISSAddress);
    

    const myAddress = accounts[0]
    

    try {
        await deployer.deploy(VotingEscrow,ISSAddress)
        votingEscrow = await VotingEscrow.deployed()

    }
    catch (err) {
        console.log('Deploy step 1b failed', err);
        throw new Error('Deploy step 1b failed');
    }

    try {
        await deployer.deploy(TokenFactory);
        tokenFactory = await TokenFactory.deployed()
    }
    catch (err) {
        console.log('Deploy step 2 failed', err);
        throw new Error('Deploy step 2 failed');
    }

    
    try{
        // Deploy the VoteMachine
        let instance = await deployProxy(RewardsMachine, [myAddress, ISSAddress, VotingEscrow.address, USDCaddress], { deployer, initializer: 'initializeContract' });
        console.log('Deployed', instance.address);
        rewardsMachine = await RewardsMachine.deployed()
    }
    catch (err) {
        console.log('Deploy step 5 failed', err);
        throw new Error('Deploy step 5 failed');
    }

    let instance = await deployProxy(AssetFactory, [ISSAddress, tokenFactory.address, myAddress,USDCaddress], { deployer, initializer: 'initializeContract' });
        console.log('Deployed', instance.address);
    
    assetFactory = await AssetFactory.deployed()
    proxyAdmin = await admin.getInstance();


    try{
        // Deploy the VoteMachine
        let instance1 = await deployProxy(VoteMachine, [myAddress, VotingEscrow.address, AssetFactory.address, RewardsMachine.address], { deployer, initializer: 'initializeContract' });
        console.log('Deployed', instance1.address);
        voteMachine = await VoteMachine.deployed()
    }
    catch (err) {
        console.log('Deploy step 6 failed', err);
        throw new Error('Deploy step 6 failed');
    }



    try{
        // Deploy the DAO
        let instance1 = await deployProxy(DAO, [VotingEscrow.address, VoteMachine.address, AssetFactory.address,ISSAddress,10000000,1], { deployer, initializer: 'initializeContract' });
        console.log('Deployed', instance1.address);
         dAO= await DAO.deployed()
    }
    catch (err) {
        console.log('Deploy step 7 failed', err);
        throw new Error('Deploy step 7 failed');
    }

      

    

    
    
    
    
    

    // set the voteMachineAddress in the assetFactory contract  and the RewardsMachine contract
    await assetFactory.setVoteMachineAddress(VoteMachine.address)
    console.log("Vote Machine Address set in the Asset Factory Contract")
    await rewardsMachine.setVoteMachineAddress(VoteMachine.address)
    console.log("Vote Machine Address set in the Rewards Machine Contract")

    // set the assetFactoryAddress in the VoteMachine contract and the RewardsMachine contract
    //await voteMachine.setAssetFactoryAddress(AssetFactory.address)
    //console.log("Asset Factory Address set in the Vote Machine Contract")
    await rewardsMachine.setAssetFactoryAddress(AssetFactory.address)
    console.log("Asset Factory Address set in the Rewards Machine Contract")


    // set the RewardsMachineAddress in to the assetFactory contract and in the Vote Machine contract
    await assetFactory.setRewardsMachineAddress(RewardsMachine.address)
    console.log("Rewards Machine Address set in the Asset Factory Contract")
    
    
    

    // Deploy the Market
    try{
        // Deploy the VoteMachine
        let instance = await deployProxy(MarketFactory, [myAddress, AssetFactory.address, USDCaddress], { deployer, initializer: 'initializeContract' });
        console.log('Deployed', instance.address);
         marketFactory= await MarketFactory.deployed()
    }
    catch (err) {
        console.log('Deploy step 7 failed', err);
        throw new Error('Deploy step 7 failed');
    }

    try{
        // Deploy the Upgrader Contract
        let instance = await deployProxy(Upgrader, [ISSAddress,voteMachine.address, votingEscrow.address, proxyAdmin.address, assetFactory.address,voteMachine.address,dAO.address, rewardsMachine.address,marketFactory.address,votingEscrow.address], { deployer, initializer: 'initializeContract' });
        console.log('Deployed', instance.address);
        upgrader = await Upgrader.deployed()
    }
    catch (err) {
        console.log('Deploy step 6a failed', err);
        throw new Error('Deploy step 6a failed');
    }
    try{
        //Set the DAO Address, the Upgrader and the VotingEscrow Address into the VoteMachine contract
        await voteMachine.setAddresses(dAO.address,upgrader.address)
        console.log("DAO and Upgrader and Voting Escrow address set to the VoteMachine contract")
        }
    catch (err) {
        console.log('Deploy step 13 failed', err);
        throw new Error('Deploy step 13  failed');
    }



    // set the RewardsMachineAddress in to the MarketFactory  contract
    await marketFactory.setRewardsMachineAddress(RewardsMachine.address)
    console.log("Rewards Machine Address set in the Market Factory Contract")

    await deployer.deploy(MarketRouter, MarketFactory.address, USDCaddress);
    marketRouter = await MarketRouter.deployed();
    
    // set the MarketFactoryAddress and the MArketRouter address in the assetFactory contract
    await assetFactory.setMarketFactoryAddress(MarketFactory.address);
    console.log("Market Factory Address set in the Asset Factory Contract")
    await assetFactory.setMarketRouterAddress(MarketRouter.address);
    console.log("Market Router Address set in the Asset Factory Contract")

    // set the MarketFactoryAddress in the RewardsMachine contract
    await rewardsMachine.setMarketFactoryAddress(MarketFactory.address);
    console.log("Market Factory Address set in the Rewardsmachine Contract")

    // Transfer ownership of the Governance Token Contract to the RewardsMachine
    //await governanceToken.transferOwnership(RewardsMachine.address)
    //console.log("Ownership of the Governance Token Contract transferred to the Rewards Machine contract")

    try {
        //transfer ownership of the TokenFactory contract to the AssetFactory
        await tokenFactory.transferOwnership(AssetFactory.address);
        console.log("Ownership of TokenFactory transferred to Asset Factory")
    }
    catch (err) {
        console.log('Deploy step 4 failed', err);
        throw new Error('Deploy step 4 failed');
    }
}