// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PaymentChannel {
    using ECDSA for bytes32;

    address payable public sender;
    address payable public receiver;
    uint256 public withdrawn;
    uint public closeDuration;
    uint public expiration = type(uint).max;

    constructor(address payable receiver_, uint closeDuration_) payable {
        sender = payable(msg.sender);
        receiver = receiver_;
        closeDuration = closeDuration_;
    }

    function getMessageHash(uint amount_) external view returns (bytes32) {
        return getMessageHash_(amount_);
    }

    function getEthSignedMessageHash(uint amount_) external view returns (bytes32) {
        return getEthSignedMessageHash_(amount_);
    }

    function verifyMessage(uint amount_, bytes memory signature_) external view returns (bool) {
        return verifyMessage_(amount_, signature_);
    }

    function getMessageHash_(uint amount_) private view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), amount_));
    }

    function getEthSignedMessageHash_(uint amount_) private view returns (bytes32) {
        return getMessageHash_(amount_).toEthSignedMessageHash();
    }

    function verifyMessage_(uint amount_, bytes memory signature_) private view returns (bool) {
        return getEthSignedMessageHash_(amount_).recover(signature_) == sender;
    }

    function close(uint amount_, bytes memory signature_) external {
        require(msg.sender == receiver);
        require(verifyMessage_(amount_, signature_));
        require(amount_ >= withdrawn);

        (bool sent, ) = receiver.call{value: amount_ - withdrawn}("");
        require(sent);

        selfdestruct(sender);
    }

    function startSenderClose() public {
        require(msg.sender == sender);
        expiration = block.timestamp + closeDuration;
    }

    function claimTimeout() public {
        require(block.timestamp >= expiration);
        selfdestruct(sender);
    }

    function deposit() public payable {
        require(msg.sender == sender);
    }

    function withdraw(uint256 amountAuthorized_, bytes memory signature_) public {
        require(msg.sender == receiver);
        require(verifyMessage_(amountAuthorized_, signature_));
        require(amountAuthorized_ > withdrawn);

        uint256 amountToWithdraw = amountAuthorized_ - withdrawn;
        withdrawn += amountToWithdraw;
        (bool sent, ) = receiver.call{value: amountToWithdraw}("");
        require(sent);
    }
}
