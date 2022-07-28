// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PaymentChannel {
  using ECDSA for bytes32;

  event InitiateSenderClose();

  // Sender of the payment channel
  address payable public sender;

  // Receiver of the payment channel
  address payable public receiver;

  // Weis the receiver has already withdrawn
  uint256 public withdrawnAmount;

  // Response timeframe (in seconds) for the receiver when the sender initiates
  // channel closure
  uint public closeTimeframe;

  // Expiration of the channel (initially infinite)
  uint public expiration = type(uint).max;

  /**
   * Opens a payment channel.
   *
   * @param receiver_         receiver of the payment channel
   * @param closeTimeframe_   timeframe of sender channel closure
   */
  constructor(address payable receiver_, uint closeTimeframe_) payable {
    sender = payable(msg.sender);
    receiver = receiver_;
    closeTimeframe = closeTimeframe_;
  }

  /**
   * Calculates the payment hash.
   *
   * @param amount    amount of the payment
   * @return          hash of the payment
   */
  function getPaymentHash(uint256 amount) external view returns (bytes32) {
    return getPaymentHash_(amount);
  }

  /**
   * Calculates the payment hash in Ethereum signed message style.
   *
   * @param amount    amount of the payment
   * @return          hash of the eth signed payment
   */
  function getEthSignedPaymentHash(uint256 amount) external view
  returns (bytes32) {
    return getEthSignedPaymentHash_(amount);
  }

  /**
   * Verifies a payment with signature.
   *
   * @param amount      amount of the payment.
   * @param signature   ECDSA signature of the signed payment
   * @return            true if the payment is valid, otherwise false
   */
  function verifyPayment(uint256 amount, bytes memory signature) external view
  returns (bool) {
    return verifyPayment_(amount, signature);
  }

  /**
   * Closes the contract with a final payment.
   *
   * @param amount      amount of the payment.
   * @param signature   ECDSA signature of the signed payment
   */
  function close(uint256 amount, bytes memory signature) external {
    require(msg.sender == receiver,
      "Only the receiver can call the close function.");
    require(verifyPayment_(amount, signature),
      "Signed payment message is invalid.");
    require(amount >= withdrawnAmount,
      "Amount must be greater than or equal to withdrawn amount.");

    if (amount > withdrawnAmount) {
      (bool success,) = receiver.call{value : amount - withdrawnAmount}("");
      require(success, "Transaction failed.");
    }

    selfdestruct(sender);
  }

  /**
   * Starts the channel closure from sender.
   */
  function initiateSenderClose() public {
    require(msg.sender == sender, "Only the sender can initiate sender close.");
    expiration = block.timestamp + closeTimeframe;
    emit InitiateSenderClose();
  }

  /**
   * Closes the channel if the channel is expired.
   */
  function claimTimeout() public {
    require(block.timestamp >= expiration, "Contract is not expired yet.");
    selfdestruct(sender);
  }

  /**
   * Transfers ether to the channel.
   */
  function deposit() public payable {
    require(msg.sender == sender, "Only the sender can deposit ether.");
  }

  /**
   * Withdraws ether with signed payment message.
   *
   * @param authorizedAmount    amount of the payment.
   * @param signature           ECDSA signature of the signed payment
   */
  function withdraw(uint256 authorizedAmount, bytes memory signature) public {
    require(msg.sender == receiver, "Only the receiver can withdraw.");
    require(verifyPayment_(authorizedAmount, signature),
      "Signed payment message is invalid.");
    require(authorizedAmount > withdrawnAmount,
      "Authorized amount must be greater than withdrawn amount.");

    // Actual amount will be withdrawn in the following transaction.
    uint256 amount = authorizedAmount - withdrawnAmount;
    withdrawnAmount += amount;
    (bool success,) = receiver.call{value : amount}("");
    require(success, "Transaction failed.");
  }

  function getPaymentHash_(uint256 amount) private view returns (bytes32) {
    // Packs the address of the contract and the amount of ether together.
    // Calculates the hash of the original message.
    return keccak256(abi.encodePacked(address(this), amount));
  }

  function getEthSignedPaymentHash_(uint256 amount) private view
  returns (bytes32) {
    // Calculates the payment message signed in Ethereum style.
    // i.e., keccak256("\x19Ethereum Signed Message:\n32", hash).
    return getPaymentHash_(amount).toEthSignedMessageHash();
  }

  function verifyPayment_(uint256 amount, bytes memory signature) private view
  returns (bool) {
    // Checks the sender of the payment message with signature.
    return getEthSignedPaymentHash_(amount).recover(signature) == sender;
  }
}