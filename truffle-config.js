const TestRPC = require('ganache-cli')
const HDWalletProvider = require("@truffle/hdwallet-provider");
const { pkey, bscScanApiKey } = require('./env.json');

module.exports = {
  plugins: ['truffle-plugin-verify', 'solidity-coverage'],
  api_keys: {
    bscscan: bscScanApiKey
  },
  networks: {
    development: {
      provider: TestRPC.provider(),
      network_id: '*'
    },
    dev: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*'
    },
    testnet: {
      provider: () => new HDWalletProvider(`0x${pkey}`, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      confirmations: 2,
      skipDryRun: true
    },
    bsc: {
      provider: () => new HDWalletProvider(`0x${pkey}`, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 2,
      skipDryRun: true
    },
  },
  compilers: {
    solc: {
      version: '^0.6.0'
    }
  }
};
