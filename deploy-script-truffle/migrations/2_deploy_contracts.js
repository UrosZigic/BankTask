require('dotenv').config();
const Bank = artifacts.require("Bank");
var HDWalletProvider = require("@truffle/hdwallet-provider");
const { Web3 } = require('web3');
const { sha3, toWei, toHex } = require('web3-utils');
var RLP = require('rlp');
const erc20ABI = require("../erc20ABI.json");

module.exports = async function(deployer) {

  const tokenAddress = process.env.TOKEN_ADDRESS;
  const rewardAmount = toWei(process.env.REWARD_AMOUNT, "ether");
  const timePeriodInDays = 1;

  let provider = new HDWalletProvider({
    mnemonic: {
      phrase: process.env.MNEMONIC
    },
    providerOrUrl: process.env.RPC_ENDPOINT
  });

  const web3 = new Web3(provider);

  const deployerAddress = await provider.getAddress();
  var nonceBefore = await web3.eth.getTransactionCount(deployerAddress);

  var nonce = Number(nonceBefore) + 1;

  const contractAddress = "0x" + sha3(RLP.encode([deployerAddress, toHex(nonce)])).slice(12).substring(14);


  const tokenContract = new web3.eth.Contract(erc20ABI, tokenAddress);


  try {
    const privateKey = process.env.PRIVATE_KEY;
  
    const account = web3.eth.accounts.privateKeyToAccount(privateKey);
    const gasPrice = await web3.eth.getGasPrice();
  
    const approveData = tokenContract.methods.approve(contractAddress, rewardAmount).encodeABI();
  
    const txObject = {
      nonce: web3.utils.toHex(nonceBefore),
      gasLimit: web3.utils.toHex(610000),
      gasPrice: web3.utils.toHex(gasPrice),
      to: tokenAddress,
      data: approveData,
      value: '0x00',
    };
  
    const signedTx = await web3.eth.accounts.signTransaction(txObject, privateKey);
  
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
  
    console.log('Approval transaction hash:', receipt.transactionHash);
    
  
    await deployer.deploy(Bank, timePeriodInDays, tokenAddress, rewardAmount);
  
    console.log('Contract deployed!');
  } catch (error) {
    console.error('Error:', error);
  }
};
