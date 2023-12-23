require('dotenv').config();
var HDWalletProvider = require("@truffle/hdwallet-provider");


module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*",
      gas: 5000000
    },
    mumbai: {
      provider: function() {
        return new HDWalletProvider(process.env.MNEMONIC, process.env.RPC_ENDPOINT)
      },
      network_id: 80001,
      gas: 4000000,
      networkCheckTimeout: 1000000,
      timeoutBlocks: 200
    }
  },
  compilers: {
    solc: {
      version: "^0.8.0",
      settings: {
        optimizer: {
          enabled: false,
          runs: 200
        },
      }
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    polygonscan: process.env.POLYGONSCAN_API
  }
};
