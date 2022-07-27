const { expect } = require('chai')
const { ethers } = require('hardhat')
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers')

describe('PaymentChannel', function () {
  async function deployPaymentChannelFixture () {
    const valueStr = ethers.utils.parseUnits('10').toString()
    const closeDuration = 60 * 60
    const [bob, alice] = await ethers.getSigners()
    const PaymentChannel = await ethers.getContractFactory('PaymentChannel', bob)
    const paymentChannel = await PaymentChannel.deploy(alice.address, closeDuration, { value: valueStr })
    return { paymentChannel, bob, alice }
  }

  it('getMessageHash, getEthSignedMessageHash, verifyMessage', async function () {
    const { paymentChannel, bob } = await loadFixture(deployPaymentChannelFixture)
    const contractAddress = paymentChannel.address
    const amount = 10
    const messageHash = ethers.utils.solidityKeccak256(['address', 'uint'], [contractAddress, amount])
    expect(await paymentChannel.getMessageHash(amount)).to.equal(messageHash)

    const ethSignedMessageHash = ethers.utils.solidityKeccak256(['string', 'bytes32'],
      ['\x19Ethereum Signed Message:\n32', messageHash])
    expect(await paymentChannel.getEthSignedMessageHash(amount)).to.equal(ethSignedMessageHash)

    const signature = await bob.signMessage(ethers.utils.arrayify(messageHash))
    expect(await paymentChannel.verifyMessage(amount, signature))
  })

  it('withdraw-case1', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = 5
    const messageHash = await paymentChannel.getMessageHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(messageHash))
    await expect(paymentChannel.withdraw(amount, signature)).to.be.revertedWith('Only receiver withdraw.')
    await expect(paymentChannel.connect(alice).withdraw(amount + 1, signature)).to.be.revertedWith(
      'Signed message is invalid.')
    await paymentChannel.connect(alice).withdraw(amount, signature)

    const newAmount = amount - 1
    const newMessageHash = await paymentChannel.getMessageHash(newAmount)
    const newSignature = await bob.signMessage(ethers.utils.arrayify(newMessageHash))
    await expect(paymentChannel.connect(alice).withdraw(newAmount, newSignature)).to.be.revertedWith(
      'Authorized amount must be greater than withdrawn amount.')
  })

  it('withdraw-case2', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = ethers.utils.parseUnits('11')
    const messageHash = await paymentChannel.getMessageHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(messageHash))
    await expect(paymentChannel.connect(alice).withdraw(amount, signature)).to.be.revertedWith('Transaction failed.')
  })

  it('close-case1', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = 10
    const messageHash = await paymentChannel.getMessageHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(messageHash))
    await paymentChannel.connect(alice).close(amount, signature)
  })

  it('close-case2', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = 5
    const messageHash = await paymentChannel.getMessageHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(messageHash))
    await expect(paymentChannel.close(amount, signature)).to.be.revertedWith('Only receiver can call close function.')
    await expect(paymentChannel.connect(alice).close(amount + 1, signature)).to.be.revertedWith(
      'Signed message is invalid.')
    paymentChannel.connect(alice).withdraw(amount, signature)

    const newAmount = amount - 1
    const newMessageHash = await paymentChannel.getMessageHash(newAmount)
    const newSignature = await bob.signMessage(ethers.utils.arrayify(newMessageHash))
    await expect(paymentChannel.connect(alice).close(newAmount, newSignature)).to.be.revertedWith(
      'Amount must be greater than or equal to withdrawn amount.')

    await paymentChannel.connect(alice).close(amount, signature)
  })

  it('close-case3', async function () {
    const { paymentChannel, bob, alice } = await loadFixture(deployPaymentChannelFixture)
    const amount = ethers.utils.parseUnits('11')
    const messageHash = await paymentChannel.getMessageHash(amount)
    const signature = await bob.signMessage(ethers.utils.arrayify(messageHash))
    await expect(paymentChannel.connect(alice).close(amount, signature)).to.be.revertedWith('Transaction failed.')
  })

  it('startSenderClose', async function () {
    const { paymentChannel, alice } = await loadFixture(deployPaymentChannelFixture)
    await paymentChannel.startSenderClose()
    await expect(paymentChannel.connect(alice).startSenderClose()).to.be.revertedWith(
      'Only sender can start sender close.')
  })

  it('claimTimeout', async function () {
    const { paymentChannel } = await loadFixture(deployPaymentChannelFixture)
    await expect(paymentChannel.claimTimeout()).to.be.revertedWith('Contract is not expired yet.')
    const amountInSeconds = 60 * 60 * 2
    await paymentChannel.startSenderClose()
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