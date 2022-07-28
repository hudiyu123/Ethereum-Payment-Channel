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

  // Amount of ether (in wei) the receiver has already withdrawn
  uint256 public withdrawnAmount;

  // Response timeframe (in seconds) for the receiver after the sender initiates
  // channel closure
  uint public closeTimeframe;

  // Expiration of the payment channel (initially infinite)
  uint public expiration = type(uint).max;

  /**
   * Opens a payment channel.
   *
   * @param receiver_         receiver of the payment channel
   * @param closeTimeframe_   timeframe after the sender initiates channel
   *                          closure
   */
  constructor(address payable receiver_, uint closeTimeframe_) payable {
    sender = payable(msg.sender);
    receiver = receiver_;
    closeTimeframe = closeTimeframe_;
  }

  /**
   * Calculates the hash of payment message.
   *
   * @param amount    amount of ether (in wei)
   * @return          hash of the payment message
   */
  function getPaymentMessageHash(uint256 amount) external view
  returns (bytes32) {
    return getPaymentMessageHash_(amount);
  }

  /**
   * Calculates the hash of Ethereum signed payment message.
   *
   * @param amount    amount of ether (in wei)
   * @return          hash of the eth signed payment message
   */
  function getEthSignedPaymentMessageHash(uint256 amount) external view
  returns (bytes32) {
    return getEthSignedPaymentMessageHash_(amount);
  }

  /**
   * Verifies a payment message with its ECDSA signature.
   *
   * @param amount      amount of ether (in wei)
   * @param signature   ECDSA signature of the payment message
   * @return            true if the payment message is valid, otherwise false
   */
  function verifyPaymentMessage(uint256 amount, bytes memory signature) external
  view returns (bool) {
    return verifyPaymentMessage_(amount, signature);
  }

  /**
   * Closes the payment channel.
   *
   * @param amount      amount of ether (in wei)
   * @param signature   ECDSA signature of the payment message
   */
  function close(uint256 amount, bytes memory signature) external {
    require(msg.sender == receiver,
      "Only the receiver can call the close function.");
    require(verifyPaymentMessage_(amount, signature),
      "Signed payment message is invalid.");
    require(amount >= withdrawnAmount,
      "Amount must be greater than or equal to withdrawn amount.");

    // Perform transaction only when request amount is greater than amount
    // already withdrawn.
    if (amount > withdrawnAmount) {
      (bool success,) = receiver.call{value : amount - withdrawnAmount}("");
      require(success, "Transaction failed.");
    }

    selfdestruct(sender);
  }

  /**
   * Initiates the channel closure by sender.
   */
  function initiateSenderClose() public {
    require(msg.sender == sender, "Only the sender can initiate sender close.");
    expiration = block.timestamp + closeTimeframe;
    // The receiver can monitor the InitiateSenderClose event to known it is
    // time to retrieve what they are owed by closing the channel.
    emit InitiateSenderClose();
  }

  /**
   * Claims the payment channel is expired and closes it.
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
   * Withdraws ether with a payment message.
   *
   * @param authorizedAmount    authorized amount of ether (in wei)
   * @param signature           ECDSA signature of the payment message
   */
  function withdraw(uint256 authorizedAmount, bytes memory signature) public {
    require(msg.sender == receiver, "Only the receiver can withdraw ether.");
    require(verifyPaymentMessage_(authorizedAmount, signature),
      "Signed payment message is invalid.");
    require(authorizedAmount > withdrawnAmount,
      "Authorized amount must be greater than amount already withdrawn.");

    // Actual amount will be withdrawn in the following transaction.
    uint256 amount = authorizedAmount - withdrawnAmount;
    withdrawnAmount += amount;
    (bool success,) = receiver.call{value : amount}("");
    require(success, "Transaction failed.");
  }

  function getPaymentMessageHash_(uint256 amount) private view
  returns (bytes32) {
    // Packs the address of the contract and the amount of ether together.
    // Calculates the hash of the original message.
    return keccak256(abi.encodePacked(address(this), amount));
  }

  function getEthSignedPaymentMessageHash_(uint256 amount) private view
  returns (bytes32) {
    // Calculates the payment message signed in Ethereum style.
    // i.e., keccak256("\x19Ethereum Signed Message:\n32", hash).
    return getPaymentMessageHash_(amount).toEthSignedMessageHash();
  }

  function verifyPaymentMessage_(uint256 amount, bytes memory signature) private
  view returns (bool) {
    // Checks the sender of the payment message with signature.
    return getEthSignedPaymentMessageHash_(amount).recover(signature) == sender;
  }
}