const { ethers } = require('hardhat')

// Gets the contract address
const address = process.argv[2]
// Gets the amount of ether (in wei)
const amount = ethers.utils.parseUnits(process.argv[3], 'wei')
// Gets the private key of the sender
const privateKey = process.argv[4]
// Creates a wallet with the private key
const wallet = new ethers.Wallet(privateKey)
// Calculates the payment message using keccak256 from solidity
const paymentHash = ethers.utils.solidityKeccak256(['address', 'uint256'],
  [address, amount])
// Signs the arrayified message using wallet
wallet.signMessage(ethers.utils.arrayify(paymentHash)).then(signature => {
  // Outputs the signature in cyan
  console.log('\x1b[36m%s', signature)
})