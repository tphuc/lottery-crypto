pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract KriptoLottery is Ownable, Pausable {
    // wait for approx. 1 week.
    uint256 constant NEXT_LOTTERY_WAIT_TIME_IN_BLOCKS = 38117;

    event LotteryRunFinished(
        address winner,
        uint256 charityAmount,
        uint256 affiliateAmount,
        uint256 jackpot
    );
    event ApplicationDone(uint256 applicationNumber);

    uint128 public maxParticipant;
    uint256 public lotteryAmount;
    address public charityAddress;
    address public affiliateAddress;
    uint256 public totalGivenAmount;
    uint256 public totalDonation;
    uint256 public totalAffiliateAmount;
    uint16 public donationRatio;
    uint16 public affiliateRatio;


    mapping(uint256 => LotteryPlay) public lotteries;
    uint16 public currentLottery;

    struct LotteryPlay {
        uint256 endBlock;
        uint256 startBlock;
        bytes32 blockHash;
        address winner;
        Participant[] participants;
    }

    struct Participant {
        address addr;
    }

    constructor(){
 
        maxParticipant = 10;
        lotteryAmount = 0.02 ether;

        _pause();
        initialise();
        _unpause();
        affiliateAddress = msg.sender;
        charityAddress = msg.sender;
        donationRatio = 100;
        affiliateRatio = 0;
    }

    // only owner
    function setMaxParticipant(uint128 val) public onlyOwner {
        maxParticipant = val;
    }

    // only owner
    function setLotteryAmount(uint256 val) public onlyOwner {
        lotteryAmount = val;
    }



    function join() public payable whenNotPaused returns (uint256) {
        // Anyone can apply as much as they want.
        require(
            lotteries[currentLottery].participants.length + 1 <= maxParticipant
        );
        require(msg.value == lotteryAmount);

        lotteries[currentLottery].participants.push(Participant(msg.sender));
        emit ApplicationDone(lotteries[currentLottery].participants.length - 1);
        return lotteries[currentLottery].participants.length - 1;
    }

    function getCurrentCount() public view returns (uint256) {
        return lotteries[currentLottery].participants.length;
    }



    function getCurrentLottery()
        public
        view
        returns (
            uint256 endBlock,
            uint256 startBlock,
            bytes32 blockHash,
            address winner,
            uint256 participants
        )
    {
        LotteryPlay storage lottery = lotteries[currentLottery];
        return (
            lottery.endBlock,
            lottery.startBlock,
            lottery.blockHash,
            lottery.winner,
            lottery.participants.length
        );
    }

    // Admin tools

    function initialise() public whenPaused onlyOwner {
        // Balance should be 0 in order to start a new lottery.
        // otherwise you might end up **stealing** others money.
        require(address(this).balance == 0);
        currentLottery++;
        lotteries[currentLottery].startBlock = block.number;
        lotteries[currentLottery].blockHash = blockhash(
            lotteries[currentLottery].startBlock
        );
        // Set the next waiting time to apprx. 1 week.
        // This is not working since I couldn't find a good way to unit test this.
        lotteries[currentLottery].endBlock =
            block.number +
            NEXT_LOTTERY_WAIT_TIME_IN_BLOCKS;
    }

    function setParticipantsNumber(uint128 newNumber) public onlyOwner {
        maxParticipant = newNumber;
    }

    function setAffiliateRatio(uint16 newRatio) public onlyOwner {
        require(newRatio < 101);
        require(newRatio + donationRatio < 101);
        affiliateRatio = newRatio;
    }

    function setAffiliateAddress(address _newAffiliate) public onlyOwner {
        require(_newAffiliate != address(0));
        affiliateAddress = _newAffiliate;
    }

    function setCharityAddress(address _newCharityAddress) public onlyOwner {
        require(_newCharityAddress != address(0));
        charityAddress = _newCharityAddress;
    }

    function setDonationRatio(uint16 newRatio) public onlyOwner {
        require(newRatio < 101);
        require(newRatio + affiliateRatio < 101);
        donationRatio = newRatio;
    }

    function runLottery() public onlyOwner returns (uint256, address) {
        require(charityAddress != address(0));
        require(lotteries[currentLottery].participants.length >= 2);
        // Uncomment the line below, *if* you can find a way to unit test
        //    this logic.
        // require(lotteries[currentLottery].endBlock < block.number);
        _pause();

        // send money to charity account.
        uint256 charityAmount = (address(this).balance * donationRatio) / 100;
        payable(charityAddress).transfer(charityAmount);
        totalDonation += charityAmount;

        // send money to an affiliate address to cover the costs.
        uint256 affiliateAmount = (address(this).balance * affiliateRatio) / 100;
        payable(affiliateAddress).transfer(affiliateAmount);
        totalAffiliateAmount += affiliateAmount;

        // random winner.
        uint256 randomValue = random();
        address winner = lotteries[currentLottery]
            .participants[randomValue]
            .addr;

        // send the rest of the funds to the winner if anything is left.
        uint256 winningPrice = address(this).balance;
        if (winningPrice > 0) {
            payable(winner).transfer(winningPrice);
        }

        lotteries[currentLottery].winner = winner;
        totalGivenAmount += winningPrice;

        // initialise a new one.
        initialise();
        _unpause();
        emit LotteryRunFinished(
            winner,
            charityAmount,
            affiliateAmount,
            winningPrice
        );
        return (randomValue, winner);
    }

    // Helper functions

    function random() internal view returns (uint256) {
        // I know, I know. I should have use a proper off the chain random generator.
        // Why not implement oraclize and send a pull request?
        uint256 r1 = uint256(blockhash(block.number - 1));
        uint256 r2 = uint256(
            blockhash(lotteries[currentLottery].startBlock)
        );

        uint256 val;

        assembly {
            val := xor(r1, r2)
        }
        return val % lotteries[currentLottery].participants.length;
    }
}
