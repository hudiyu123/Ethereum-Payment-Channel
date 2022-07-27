// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PaymentChannel {
  using ECDSA for bytes32;

  event StartSenderClose();
  event Withdraw(uint256 amountAuthorized, bytes signature);

  address payable public sender;
  address payable public receiver;
  uint256 public withdrawnAmount;
  uint public closeDuration;
  uint public expiration = type(uint).max;

  constructor(address payable receiver_, uint closeDuration_) payable {
    sender = payable(msg.sender);
    receiver = receiver_;
    closeDuration = closeDuration_;
  }

  function getMessageHash(uint amount) external view returns (bytes32) {
    return getMessageHash_(amount);
  }

  function getEthSignedMessageHash(uint amount) external view returns (bytes32) {
    return getEthSignedMessageHash_(amount);
  }

  function verifyMessage(uint amount, bytes memory signature) external view returns (bool) {
    return verifyMessage_(amount, signature);
  }

  function close(uint amount, bytes memory signature) external {
    require(msg.sender == receiver, "Only receiver can call close function.");
    require(verifyMessage_(amount, signature), "Signed message is invalid.");
    require(amount >= withdrawnAmount, "Amount must be greater than or equal to withdrawn amount.");

    if (amount > withdrawnAmount) {
      (bool success, ) = receiver.call{value : amount - withdrawnAmount}("");
      require(success, "Transaction failed.");
    }

    selfdestruct(sender);
  }

  function startSenderClose() public {
    require(msg.sender == sender, "Only sender can start sender close.");
    expiration = block.timestamp + closeDuration;
    emit StartSenderClose();
  }

  function claimTimeout() public {
    require(block.timestamp >= expiration, "Contract is not expired yet.");
    selfdestruct(sender);
  }

  function deposit() public payable {
    require(msg.sender == sender, "Only sender can deposit eth.");
  }

  function withdraw(uint authorizedAmount, bytes memory signature) public {
    require(msg.sender == receiver, "Only receiver withdraw.");
    require(verifyMessage_(authorizedAmount, signature), "Signed message is invalid.");
    require(authorizedAmount > withdrawnAmount, "Authorized amount must be greater than withdrawn amount.");

    uint256 amount = authorizedAmount - withdrawnAmount;
    withdrawnAmount += amount;
    (bool success, ) = receiver.call{value : amount}("");
    require(success, "Transaction failed.");

    emit Withdraw(authorizedAmount, signature);
  }

  function getMessageHash_(uint amount) private view returns (bytes32) {
    return keccak256(abi.encodePacked(address(this), amount));
  }

  function getEthSignedMessageHash_(uint amount) private view returns (bytes32) {
    return getMessageHash_(amount).toEthSignedMessageHash();
  }

  function verifyMessage_(uint amount, bytes memory signature) private view returns (bool) {
    return getEthSignedMessageHash_(amount).recover(signature) == sender;
  }
}