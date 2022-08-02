
const { expect } = require("chai");
const { ethers } = require("hardhat");


const Abicoder = ethers.utils.defaultAbiCoder

// const sha3 = (number, address) => ethers.utils.keccak256(
//   Abicoder.encode(['uint256', 'uint256'], [number, address])
// )

const sha3 = (number, address) => ethers.utils.solidityKeccak256(['uint256', 'address'], [number, address])

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
    await lottery.connect(addr1).join(sha3(2022, addr1.address), { value: ethers.utils.parseEther('0.02') });
    const currentCount = await lottery.getCurrentCount.call();
    expect(currentCount).to.equal(1);
  });

  it('should count the current joined users 2', async () => {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await lottery.connect(addr1).join(sha3(2022, addr1.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr2).join(sha3(2022, addr2.address), { value: ethers.utils.parseEther('0.02') });
    const currentCount = await lottery.getCurrentCount.call();
    expect(currentCount).to.equal(2);
  });



  it('initialize submitted count = 0', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    expect(ownerAddress).to.equal(0);
  });


  it('submit secret with same key, check submitted count', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(2022, addr1.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr1).submitSecret(2022)
    let count = await lottery.connect(owner).getCurrentSubmittedCount()
    console.log(sha3(2022, addr1.address))

    expect(count.toString()).equal('1')


  });


  it('submit secret with different key, check submitted count', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(2022, addr1.address), { value: ethers.utils.parseEther('0.02') });

    await lottery.connect(addr1).submitSecret(2021)
    let count = await lottery.connect(owner).getCurrentSubmittedCount()

    expect(count.toString()).equal('0')
  });

  it('check method is joined', async () => {
    const [owner, addr1] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(2022, addr1.address), { value: ethers.utils.parseEther('0.02') });

    let res = await lottery.connect(addr1).isWalletSubmittedHash()
    // let count = await lottery.connect(owner).getCurrentSubmittedCount()

    expect(res).equal(true)
  });


  it('should emit event lotteryRunFinised when lottery end', async () => {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(2022, addr1.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr1).submitSecret(2022)
    await lottery.connect(addr2).join(sha3(1231, addr2.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr2).submitSecret(1231)
    await lottery.connect(addr3).join(sha3(1128, addr3.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr3).submitSecret(1128)


    await expect(lottery.runLottery())
      .to.emit(lottery, "LotteryRunFinished")




  });

  it('check correct random number based on submissions', async () => {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(9998, addr1.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr1).submitSecret(9998)
    await lottery.connect(addr2).join(sha3(1231, addr2.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr2).submitSecret(1231)
    await lottery.connect(addr3).join(sha3(1128, addr3.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr3).submitSecret(1128)

    let addresses = [addr1, addr2, addr3]
    let xor = 9998 ^ 1231 ^ 1128;
    let random = xor % 3;

    await lottery.connect(owner).runLottery()
    let data = await lottery.getLastLottery()

   
    
  
  
    expect(data.winner).to.equal(addresses[random].address)

  });


  it('get past lottery events', async () => {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(9998, addr1.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr1).submitSecret(9998)
    await lottery.connect(addr2).join(sha3(1231, addr2.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr2).submitSecret(1231)
    await lottery.connect(addr2).join(sha3(1128, addr3.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr2).submitSecret(1128)


    await lottery.connect(owner).runLottery()
    let eventFilter = lottery.filters.LotteryRunFinished()
    let events = await lottery.queryFilter(eventFilter)

    
  
  
    expect(events.length).to.equal(1)

  });


  it('check wallet balance after won lottery', async () => {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const ownerAddress = await lottery.getCurrentSubmittedCount.call();
    await lottery.connect(addr1).join(sha3(9998, addr1.address), { value: ethers.utils.parseEther('0.02') });
  
    await lottery.connect(addr2).join(sha3(1231, addr2.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr2).join(sha3(1128, addr3.address), { value: ethers.utils.parseEther('0.02') });
    await lottery.connect(addr2).submitSecret(1231)
    await lottery.connect(addr1).submitSecret(9998)
    await lottery.connect(addr2).submitSecret(1128)

    let addresses = [addr1, addr2, addr3]
    let xor = 9998 ^ 1231 ^ 1128;
    let random = xor % 3;
    let contractBalance= await ethers.provider.getBalance(lottery.address)
    let pre_balance = await addresses[random].getBalance()
    
    await lottery.connect(owner).runLottery()
    let data = await lottery.getLastLottery()

    let post_balance = await addresses[random].getBalance()    
    expect(post_balance).to.equal(pre_balance.add(ethers.utils.parseEther('0.06')))

  });





});
