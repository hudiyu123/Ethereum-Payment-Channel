const { expect } = require('chai')
const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')

describe('PaymentChannel', function () {
  async function deployPaymentChannelFixture () {
    const valueStr = ethers.utils.parseUnits('10').toString()
    const closeTimeframe = 60 * 60
    const [bob, alice] = await ethers.getSigners()
    const PaymentChannel = await ethers.getContractFactory('PaymentChannel', bob)
    const paymentChannel = await PaymentChannel.deploy(alice.address, closeTimeframe, { value: valueStr })
    return { paymentChannel, bob, alice }
  }

  it('getPaymentHash, getEthSignedPaymentHash, verifyPayment', async function () {
    const { paymentChannel, bob } = await loadFixture(deployPaymentChannelFixture)
    const contractAddress = paymentChannel.address
    const amount = 10
    const paymentHash = ethers.utils.solidityKeccak256(['address', 'uint256'], [contractAddress, amount])
    expect(await paymentChannel.getPaymentHash(amount)).to.equal(paymentHash)

    const ethSignedPaymentHash = ethers.utils.solidityKeccak256(['string', 'bytes32'],
      ['\x19Ethereum Signed Message:\n32', paymentHash])
    expect(await paymentChannel.getEthSignedPaymentHash(amount)).to.equal(ethSignedPaymentHash)

    const signature = await bob.signMessage(ethers.utils.arrayify(paymentHash))
    expect(await paymentChannel.verifyPayment(amount, signature))
  })

  it('withdraw-case1', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = 5
    const paymentHash = await paymentChannel.getPaymentHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(paymentHash))
    await expect(paymentChannel.withdraw(amount, signature)).to.be.revertedWith('Only receiver withdraw.')
    await expect(paymentChannel.connect(alice).withdraw(amount + 1, signature)).to.be.revertedWith(
      'Signed message is invalid.')
    await paymentChannel.connect(alice).withdraw(amount, signature)

    const newAmount = amount - 1
    const newPaymentHash = await paymentChannel.getPaymentHash(newAmount)
    const newSignature = await bob.signMessage(ethers.utils.arrayify(newPaymentHash))
    await expect(paymentChannel.connect(alice).withdraw(newAmount, newSignature)).to.be.revertedWith(
      'Authorized amount must be greater than withdrawn amount.')
  })

  it('withdraw-case2', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = ethers.utils.parseUnits('11')
    const paymentHash = await paymentChannel.getPaymentHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(paymentHash))
    await expect(paymentChannel.connect(alice).withdraw(amount, signature)).to.be.revertedWith('Transaction failed.')
  })

  it('close-case1', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = 10
    const paymentHash = await paymentChannel.getPaymentHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(paymentHash))
    await paymentChannel.connect(alice).close(amount, signature)
  })

  it('close-case2', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = 5
    const paymentHash = await paymentChannel.getPaymentHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(paymentHash))
    await expect(paymentChannel.close(amount, signature)).to.be.revertedWith(
      'Only the receiver can call the close function.')
    await expect(paymentChannel.connect(alice).close(amount + 1, signature)).to.be.revertedWith(
      'Signed message is invalid.')
    paymentChannel.connect(alice).withdraw(amount, signature)

    const newAmount = amount - 1
    const newPaymentHash = await paymentChannel.getPaymentHash(newAmount)
    const newSignature = await bob.signMessage(ethers.utils.arrayify(newPaymentHash))
    await expect(paymentChannel.connect(alice).close(newAmount, newSignature)).to.be.revertedWith(
      'Amount must be greater than or equal to withdrawn amount.')

    await paymentChannel.connect(alice).close(amount, signature)
  })

  it('close-case3', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = ethers.utils.parseUnits('11')
    const paymentHash = await paymentChannel.getPaymentHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(paymentHash))
    await expect(paymentChannel.connect(alice).close(amount, signature)).to.be.revertedWith('Transaction failed.')
  })

  it('initiateSenderClose', async function () {
    const { paymentChannel, alice } = await loadFixture(deployPaymentChannelFixture)
    await paymentChannel.initiateSenderClose()
    await expect(paymentChannel.connect(alice).initiateSenderClose()).to.be.revertedWith(
      'Only the sender can initiate sender close.')
  })

  it('claimTimeout', async function () {
    const { paymentChannel } = await loadFixture(deployPaymentChannelFixture)
    await expect(paymentChannel.claimTimeout()).to.be.revertedWith('Contract is not expired yet.')
    const amountInSeconds = 60 * 60 * 2
    await paymentChannel.initiateSenderClose()
    await time.increase(amountInSeconds)
    await paymentChannel.claimTimeout()
  })

  it('deposit', async function () {
    const { paymentChannel, alice } = await loadFixture(deployPaymentChannelFixture)
    const valueStr = ethers.utils.parseUnits('5').toString()
    await expect(paymentChannel.connect(alice).deposit({ value: valueStr })).to.be.revertedWith(
      'Only sender can deposit eth.')
    await paymentChannel.deposit({ value: valueStr })
  })
})