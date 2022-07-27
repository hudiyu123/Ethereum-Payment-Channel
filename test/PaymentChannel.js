const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PaymentChannel contract", function () {
    it("Deployment should assign the total supply of tokens to the owner", async function () {
        const [bob, alice] = await ethers.getSigners();
        const PaymentChannel = await ethers.getContractFactory("PaymentChannel", bob);
        const paymentChannel = await PaymentChannel.deploy(alice.address, 3600, {value: "10000000000000000000"});
        expect(await paymentChannel.sender()).to.equal(bob.address);
    });
});