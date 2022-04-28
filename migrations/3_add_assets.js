// Fetch the GovernanceToken contract data from the GovernanceToken.json file
const GovernanceToken = artifacts.require("./GovernanceToken.sol");


const VotingEscrow = artifacts.require("./VotingEscrow.sol")
const AssetFactory = artifacts.require("./assetFactory.sol");
const MockUSDC = artifacts.require("./MockUSDT.sol");
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
const multisigAddress = "0x61bE0EC6Db427eD02a184A06963F44684547016E";

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

const dAOAmount = BigInt(10000000) * BigInt(1e18)
const rewardsAmount = BigInt(20000000) * BigInt(1e18)

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

    else if (network === "mumbai") {ISSAddress = "0x1AFB455e5431a41f97d37179672377BBa973Fd87"; USDCaddress = "0x85f825bD8BcC002fF8E201926B7b334e0E05a91C"}
    else if (network === "rinkeby") {ISSAddress = "0x92B971d00EC3Dfcb7F5A8DFe24B7A5d2e6C87e35"}
    else if (network === "bscTestnet") {ISSAddress = "0x4d44454CCDC152DF034b73C64707E937ACf21DcB"}
    else if (network === "fuji") {ISSAddress = "0xB7A89f28b9A7bdb20c53aE3EC74F7a00fF5c3b3B"}
    else if (network === "arbitrumRinkeby") {ISSAddress = "0x4d44454CCDC152DF034b73C64707E937ACf21DcB"}
    else if (network === "kovan") {ISSAddress = "0x72aB53a133b27Fa428ca7Dc263080807AfEc91b5"}    
    else if (network === "fantomTestnet") {ISSAddress = "0x976c8A03382034Ce52c189a4733Ed8c759EcA43C"}
    else if (network === "development") {ISSAddress = "0x356F26716Fe237aD540F53D926D557Ae352Ea73E"; USDCaddress = "0x055Ca4CCe0bf1D35e8D7953F5eCaDD0640Be8D46"}
    
    console.log("ISS Address: ",ISSAddress)
    const governanceToken = await GovernanceToken.at(ISSAddress);
    

    const myAddress = accounts[0]
    

    votingEscrow = await VotingEscrow.deployed()
    tokenFactory = await TokenFactory.deployed()
    rewardsMachine = await RewardsMachine.deployed()
    assetFactory = await AssetFactory.deployed()
    proxyAdmin = await admin.getInstance();
    voteMachine = await VoteMachine.deployed()
    dAO= await DAO.deployed()
    marketFactory= await MarketFactory.deployed()
    marketRouter = await MarketRouter.deployed()
    upgrader = await Upgrader.deployed()
    


    var assets = []
    assets.push(["Dow Jones Industrial Average Index", "DJIA", "US Equity Index (30 main US-Stocks). ISIN: US2605661048",60000000,34607000])
    assets.push(["NASDAQ 100 Index", "NDX", "US Equity Index (100 largest non-fin. NASDAQ listed comp.). ISIN: US6311011026 ",30000000,15444000])
    //assets.push(["Standard & Poors 500 Index", "S500", "US Equity Index (500 largest listed US Companies). ISIN: US78378X1072",10000000,4460000])
    //assets.push(["WTI crude oil", "WTI", "WTI crude oil Price (Spot) in USD. ISIN: XD0015948363",150000,70000])
    //assets.push(["Gold", "XAU", "Gold Price (Spot) in USD. ISIN: XC0009655157 ",4000000,1788000])
    //assets.push(["Silver", "XAG", "Silver Price (Spot) in USD. ISIN: XC0009653103",50000,23765])
    //assets.push(["Bitcoin", "BTC", "Native cryptocurrency of the Bitcoin Blockchain",120000000,45506000])
    //assets.push(["Ether", "ETH", "Native cryptocurrency of the Ethereum Blockchain",10000000,3283000])
    console.log(AssetFactory.address)
    for(var i = 0; i <assets.length; i++) {
        asset = assets[i]
        //console.log(asset)
        let name = asset[0]
        let symbol = asset[1].concat("_").concat(year).concat(month)
        console.log("Symbol: ",symbol)
        let assetExists = await assetFactory.assetExists(symbol)
        console.log(assetExists)
        if (assetExists === false) {
            
            let description = asset[2]
            let upperLimit = asset[3]
            await assetFactory.createAssets(name,symbol,description,upperLimit);
            console.log("Asset created")
        }
        let assetDetails  = await assetFactory.getAsset(symbol);
        console.log(assetDetails)
        let token1 = assetDetails[0]
        console.log(token1)
        let token2 = assetDetails[1]
        console.log(token2)
        let pair1 = await marketFactory.getPair(token1,USDCaddress);
        let pair2 = await marketFactory.getPair(token2,USDCaddress);
        console.log(pair1)
        console.log(pair2)
        if (pair1 === '0x0000000000000000000000000000000000000000'){
            await marketFactory.createPair(token1,USDCaddress);
            console.log("market pair 1 added")
        }
        if (pair2 === '0x0000000000000000000000000000000000000000'){
            await marketFactory.createPair(token2,USDCaddress);
            console.log("market pair 2 added")
        }

        
        pair1 = await marketFactory.getPair(token1,USDCaddress);
        pair2 = await marketFactory.getPair(token2,USDCaddress);
        await rewardsMachine.addPools(symbol);
        if (pair2 =! '0x0000000000000000000000000000000000000000'){
            
            console.log("Pools added");
        }
        else{
            console.log("Pool could not be added")
        }
        //await marketFactory.createPair(token2,USDCaddress);
        //let pair2 = await marketFactory.getMarketPair(token2,USDCaddress);
        //await rewardsMachine.addPool(pair2,symbol);
        //console.log("Pool 2 added");
    }   
    
    await marketFactory.createPair(ISSAddress,USDCaddress);
    console.log("ISS USD market pair generated")
    let pair = await marketFactory.getPair(ISSAddress,USDCaddress);
    await rewardsMachine.addIPTBonusPool(pair);
    console.log("ISS pool added")

    //transfer ownership to AssetFactory Address where no longer needed.
    await rewardsMachine.transferControlAccount(AssetFactory.address);
    console.log("Ownership of the RewardsMachine contract transferred")


    

    
    const USDC = await MockUSDC.at(USDCaddress);
    
    await USDC.approve(AssetFactory.address,'1000000000000000000000000000000000000000')
    console.log("Approved AssetFactory to spend USDC")
    await USDC.approve(MarketRouter.address,'1000000000000000000000000000000000000000')
    console.log("Approved MarketRouter to spend USDC")
    
    for(var i = 0; i <assets.length; i++) {        
        
        let asset = assets[i]
        let symbol = asset[1].concat("_").concat(year).concat(month)
        console.log(symbol)
        
        result = await assetFactory.mintAssets(symbol,'20000000');
        //console.log(result)
        console.log("Asset minted")
        let tokenLong
        let tokenShort
        result = await assetFactory.getTokenAddresses(symbol);
        tokenLong = result[0]
        tokenShort = result[1]
        //console.log(tokenLong)
        //console.log(tokenShort)
        let upperLimit = asset[3]
        let pair = await marketFactory.getPair(tokenLong,USDCaddress);
        //console.log(pair)
        let token = await AssetToken.at(tokenLong);
        longTokenVolume = await token.balanceOf(myAddress);
        await token.approve(MarketRouter.address,'1000000000000000000000000000000000000000')
        //console.log("Token 1 approved")
        

        token = await AssetToken.at(tokenShort);
        shortTokenVolume = await token.balanceOf(myAddress);
        await token.approve(MarketRouter.address,'1000000000000000000000000000000000000000')
        //console.log("Token 2 approved")

        var longUSDAmount = parseInt(longTokenVolume * asset[4] / (10**15))
        var shortUSDAmount = parseInt(longTokenVolume * (asset[3] - asset[4]) / (10**15))
        //console.log(longUSDAmount)
        //console.log(longTokenVolume.toString())
        //console.log(shortUSDAmount)
        //console.log(shortTokenVolume.toString())
        await marketRouter.addLiquidity(tokenLong, USDCaddress,longTokenVolume.toString(),longUSDAmount.toString(),'1000000000000000',(asset[4]*1).toString(),myAddress,'1829861859');
        await marketRouter.addLiquidity(tokenShort, USDCaddress,shortTokenVolume.toString(),shortUSDAmount.toString(),'1000000000000000',((asset[3]-asset[4])*1).toString(),myAddress,'1829861859')

    }
    pair = await marketFactory.getPair(ISSAddress,USDCaddress);
    console.log(pair)
    await governanceToken.approve(MarketRouter.address,'1000000000000000000000000000000000000000')
    
    
    //transfer ownership to NULL.
    await assetFactory.transferControlAccount(DAO.address);
    console.log("Control Account of the assetFactory contract transferred to DAO contract")   

    //transfer ownership to DAO Address where no longer needed.
    await marketFactory.transferControlAccount('0x0000000000000000000000000000000000000000');
    console.log("Ownership of the MarketFactory contract transferred to DAO contract")   

    //transfer control to DAO Address where no longer needed.
    await voteMachine.transferControlAccount('0x0000000000000000000000000000000000000000');
    console.log("Control of the VoteMachine contract transferred to DAO contract")     

    //Change ownership of the proxy contracts to the upgrader contract
    //await admin.transferProxyAdminOwnership(upgrader.address);

    await governanceToken.mint(dAO.address,dAOAmount)
    await governanceToken.mint(rewardsMachine.address,rewardsAmount)
    console.log("DAO and RewardsMachine share of the GovernanceToken transferred")

    try{
        //Transfer ISS to DAO and RewardsMachine
        b = await governanceToken.balanceOf(rewardsMachine.address)
        console.log("Balance rewards machine: " ,b/1e18+'')
    }
    catch (err) {
        console.log('Deploy step 8 failed', err);
        throw new Error('Deploy step 8 failed');
    }
    
 
    await governanceToken.approve(VotingEscrow.address,'10000000000000000000000000000')
    await votingEscrow.createLock('100000000000000000000000',1744622600)

    if (network === 'development'){
        await rewardsMachine.createRewards();
        let z =  await rewardsMachine.getRewards(myAddress)
        console.log("Rewards: ",z/1e18+'')
        await rewardsMachine.claimRewards();
        b = await governanceToken.balanceOf(myAddress)
 
    }
    
    
    console.log("RewardsMachine: ",RewardsMachine.address)
    console.log("AssetFactory: ",AssetFactory.address)
    console.log("VoteMachine: ",VoteMachine.address)
    console.log("DAO: ",DAO.address)
    console.log("MarketFactory: ",MarketFactory.address)
    console.log("Upgrader: ",Upgrader.address)
    console.log("MarktRouter: ",MarketRouter.address)
    console.log("VotingEscrow: ", VotingEscrow.address)  
  

 
}