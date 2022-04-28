/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

// const HDWalletProvider = require('@truffle/hdwallet-provider');
// const infuraKey = "fj4jll3k.....";
//
// const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();

var fs = require("fs");
var path = require("path");
var HDWalletProvider = require("@truffle/hdwallet-provider");
//var mnemonic = "ride apart network once pioneer praise replace extend entire reason jaguar upon";
var mnemonic = fs.readFileSync(path.join(__dirname, "deploy_mnemonic.key"), {encoding: "utf8"}).trim();
const projectId = "12931f0d89a849898efddfb35c9bd5d9";  


module.exports = {

  plugins: [
    'truffle-plugin-verify',
    'truffle-contract-size'
  ],
  api_keys: {
    etherscan: 'MY_API_KEY',
    bscscan: 'MY_API_KEY',
    hecoinfo: 'MY_API_KEY',
    ftmscan: 'MY_API_KEY',
    polygonscan: 'KUG6WXTB5YCCBMSFXM9ASNRGCGBDMVNRU9',
  },
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    development: {
      host: "localhost",
      port: 7545,
      network_id: "5777",
      gasPrice: 1000

    },

    ropsten: {
      //networkCheckTimeout: 100000,  // NB: this option does nothing
      provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/${projectId}`),
      network_id: 3,
      gasPrice: 10000000000,
      gas: 6000000,      //make sure this gas allocation isn't over 4M, which is the max
      skipDryRun: true
    },

    goerli: {
      //networkCheckTimeout: 100000,  // NB: this option does nothing
      provider: () => new HDWalletProvider(mnemonic, `https://goerli.infura.io/v3/${projectId}`),
      network_id: 5,
      gasPrice: 40000000009,
      gas: 6000000      //make sure this gas allocation isn't over 4M, which is the max
    },

    bscTestnet: {
      provider: () => new HDWalletProvider(mnemonic, `https://speedy-nodes-nyc.moralis.io/685c4adf707f9eaf8a3c2d95/bsc/testnet`),
      network_id: 97,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      enableTimeouts: false,
      networkCheckTimeout: 1000000,
      before_timeout: 120000 // Here is 2min but can be whatever timeout is suitable for you.
    
    },

    rinkeby: {
      provider: () => new HDWalletProvider(mnemonic, `https://speedy-nodes-nyc.moralis.io/685c4adf707f9eaf8a3c2d95/eth/rinkeby`),
      network_id: 4,
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    arbitrumRinkeby: {
      provider: () => new HDWalletProvider(mnemonic, `https://speedy-nodes-nyc.moralis.io/685c4adf707f9eaf8a3c2d95/arbitrum/testnet`),
      network_id: 421611,
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true
    },

    fuji: {
      provider: () => new HDWalletProvider(mnemonic, `https://speedy-nodes-nyc.moralis.io/685c4adf707f9eaf8a3c2d95/avalanche/testnet`),
      network_id: 43113,
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    mumbai: {
      //provider: () => new HDWalletProvider(mnemonic, `https://speedy-nodes-nyc.moralis.io/685c4adf707f9eaf8a3c2d95/polygon/mumbai`),
      provider: () => new HDWalletProvider(mnemonic, `wss://ws-matic-mumbai.chainstacklabs.com`),
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      //enableTimeouts: false,
      before_timeout: 120000, // Here is 2min but can be whatever timeout is suitable for you.

    },

    kovan: {
      provider: () => new HDWalletProvider(mnemonic, `https://kovan.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161`),
      network_id: 6,
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    fantomTestnet: {
      provider: () => new HDWalletProvider(mnemonic, `https://rpc.testnet.fantom.network/`),
      network_id: 4002,
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true
    },


    maticTestnet: {
      provider: () => new HDWalletProvider(mnemonic, `wss://ws-matic-mumbai.chainstacklabs.com`),
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      enableTimeouts: false,
      before_timeout: 120000 // Here is 2min but can be whatever timeout is suitable for you.
    },

    ethereum: {
      provider: () => new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161`),
      network_id: 1,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc: {
      provider: () => new HDWalletProvider(mnemonic, `https://bsc-dataseed.binance.org/`),
      network_id: 56,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    avalanche: {
      provider: () => new HDWalletProvider(mnemonic, `https://api.avax.network/ext/bc/C/rpc`),
      network_id: 43114,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    polygon: {
      provider: () => new HDWalletProvider(mnemonic, `https://polygon-rpc.com/`),
      network_id: 137,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },

    arbitrum: {
      provider: () => new HDWalletProvider(mnemonic, `https://rpc.ankr.com/arbitrum`),
      network_id: 42161,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    optimism: {
      provider: () => new HDWalletProvider(mnemonic, `https://mainnet.optimism.io`),
      network_id: 10,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    fantom: {
      provider: () => new HDWalletProvider(mnemonic, `https://rpc.ftm.tools/`),
      network_id: 250,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },

  
    // live: { ... }
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    // development: {
    //  host: "127.0.0.1",     // Localhost (default: none)
    //  port: 8545,            // Standard Ethereum port (default: none)
    //  network_id: "*",       // Any network (default: none)
    // },
    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },
    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    // ropsten: {
    // provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/YOUR-PROJECT-ID`),
    // network_id: 3,       // Ropsten's id
    // gas: 5500000,        // Ropsten has a lower block limit than mainnet
    // confirmations: 2,    // # of confs to wait between deployments. (default: 0)
    // timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    // skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    // },
    // Useful for private networks
    // private: {
    // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
    // network_id: 2111,   // This network is yours, in the cloud.
    // production: true    // Treats this network as if it was a public net. (default: false)
    // }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.12",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      optimizer: {
        enabled: true,
        runs: 10
      },
      evmVersion: "istanbul"
      // }
    }
  }
 

};
