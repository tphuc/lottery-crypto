const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("Lottery", async function () {

  var lottery;
  beforeEach(async function () {
    const Lottery = await ethers.getContractFactory("KriptoLottery");
    lottery = await Lottery.deploy();
    await lottery.deployed();
  });

  

  it('should set the participant number 10 by default', async () => {
    const maxCount = await lottery.maxParticipant.call();
    expect(maxCount).to.equal(10);

  });

  it('should set the owner', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.owner.call();
    expect(ownerAddress).to.equal(owner.address);
  });

  it('should count the current joined users 1', async () => {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await lottery.connect(addr1).join({value: ethers.utils.parseEther('0.02')});
    const currentCount = await lottery.getCurrentCount.call();
    expect(currentCount).to.equal(1);
  });

  it('should count the current joined users 2', async () => {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await lottery.connect(addr1).join({value: ethers.utils.parseEther('0.02')});
    await lottery.connect(addr2).join({value: ethers.utils.parseEther('0.02')});
    const currentCount = await lottery.getCurrentCount.call();
    expect(currentCount).to.equal(2);
  });

  it('should update contract eth balance when users join', async () => {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await lottery.connect(addr1).join({value: ethers.utils.parseEther('0.02')});
    await lottery.connect(addr2).join({value: ethers.utils.parseEther('0.02')});
    const balance = await ethers.provider.getBalance(lottery.address)

    expect(balance.toString()).to.equal(ethers.utils.parseEther('0.04').toString());
  });


});
