const { expect } = require("chai");
const { ethers } = require("hardhat");


const Abicoder = ethers.utils.defaultAbiCoder 
const sha3 = (hash) => ethers.utils.keccak256( 
    Abicoder.encode(['uint256'],[hash]) 
  )

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
    const [owner, addr1] = await ethers.getSigners(); // get wallets
    const ownerAddress = await lottery.owner.call();
    expect(ownerAddress).to.equal(owner.address);
  });


  it('change max participant numbers', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.connect(owner).setParticipantsNumber(19);
    const count = await lottery.connect(owner).maxParticipant()
    expect(count.toString()).to.equal('19');

  });

  

  it('should count the current joined users 1', async () => {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await lottery.connect(addr1).join(120, {value: ethers.utils.parseEther('0.02') });
    const currentCount = await lottery.getCurrentCount.call();
    expect(currentCount).to.equal(1);
  });

 

  it('initialize submitted count = 0', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    expect(ownerAddress).to.equal(0);
  });


  it('submit secret with same key, check submitted count', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(2022), {value: ethers.utils.parseEther('0.02') });

    await lottery.connect(addr1).submitSecret(2022)
    let count = await lottery.connect(owner).getCurrentSubmittedCount()

    expect(count.toString()).equal('1')

    
  });


  it('submit secret with different key, check submitted count', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(2022), {value: ethers.utils.parseEther('0.02') });

    await lottery.connect(addr1).submitSecret(2021)
    let count = await lottery.connect(owner).getCurrentSubmittedCount()

    expect(count.toString()).equal('0')
    
  });


});
