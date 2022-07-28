// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract KriptoLottery is Ownable, Pausable {

    event LotteryRunFinished(
        address winner,
        uint256 affiliateAmount,
        uint256 jackpot
    );
    event ApplicationDone(uint256 applicationNumber);

    uint128 public maxParticipant;
    uint128 public minParticipant = 2;
    uint256 public lotteryAmount;
    address public affiliateAddress; // Hoa 
    uint256 public totalGivenAmount;
    uint256 public totalDonation;
    uint256 public totalAffiliateAmount;
    uint16 public affiliateRatio;
    uint16 public durationHours = 1; // will lock people join and submit secret after hour


    mapping(uint256 => LotteryPlay) public lotteries;
   
    uint16 public currentLottery;

    struct LotteryPlay {
        // uint256 endBlock;
        uint256 startBlock;
        bytes32 blockHash;
        address winner;
        uint256 endingTime;
        uint256 resultTime;
        
        Participant[] participants;
        mapping(address => uint256) secretHashes;
        mapping(address => uint256) submittedSecrets;
        uint submittedCount;
        uint256 XOR;
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
        affiliateRatio = 0;
    }

    // only owner
    function setMaxParticipant(uint128 val) public onlyOwner {
        maxParticipant = val;
    }

    // only owner
    function setMinParticipant(uint128 val) public onlyOwner {
        minParticipant = val;
    }

    // only owner
    function setLotteryAmount(uint256 val) public onlyOwner {
        lotteryAmount = val;
    }

    // only owner
    function setLotteryDurationHours(uint16 val) public onlyOwner {
        durationHours = val;
    }

    



    function join(uint256 nonce) public payable whenNotPaused returns (uint256) {
        // Anyone can apply as much as they want.
        require(
            lotteries[currentLottery].participants.length + 1 <= maxParticipant, "No more tickets available for current lottery"
        );
        require(
            block.timestamp <= lotteries[currentLottery].endingTime, ""
        );
        require(msg.value == lotteryAmount);
        require(nonce > 0, "secret nonce number is required");
        lotteries[currentLottery].secretHashes[msg.sender] = nonce;

        lotteries[currentLottery].participants.push(Participant(msg.sender));
        emit ApplicationDone(lotteries[currentLottery].participants.length - 1);
        return lotteries[currentLottery].participants.length - 1;
    }


    function submitSecret(uint secret) public payable whenNotPaused {
        if (uint256(keccak256(abi.encodePacked(secret))) == lotteries[currentLottery].secretHashes[msg.sender]){
            lotteries[currentLottery].submittedSecrets[msg.sender] = secret;
            lotteries[currentLottery].XOR = lotteries[currentLottery].XOR ^ secret;
            lotteries[currentLottery].submittedCount++;
        }

    }

    function getCurrentCount() public view returns (uint256) {
        return lotteries[currentLottery].participants.length;
    }

    function getAddressSecretHash() public view returns (uint256) {
        return lotteries[currentLottery].secretHashes[msg.sender];
    }

    function getCurrentSubmittedCount() public view returns (uint256) {
        return lotteries[currentLottery].submittedCount;
    }


    function getCurrentLottery()
        public
        view
        returns (
            // uint256 endBlock,
            uint256 resultTime,
            uint256 startBlock,
            bytes32 blockHash,
            address winner,
            uint256 participants
        )
    {
        LotteryPlay storage lottery = lotteries[currentLottery];
        return (
            // lottery.endBlock,
            lottery.resultTime,
            lottery.startBlock,
            lottery.blockHash,
            lottery.winner,
            lottery.participants.length
        );
    }

    function getLastLottery()
        public
        view
        returns (
            // uint256 endBlock,
            uint256 resultTime,
            uint256 startBlock,
            bytes32 blockHash,
            address winner,
            uint256 participants
        )
    {
        LotteryPlay storage lottery = lotteries[currentLottery - 1];
        return (
            // lottery.endBlock,
            lottery.resultTime,
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
        lotteries[currentLottery].submittedCount = 0;
        lotteries[currentLottery].endingTime = block.timestamp + durationHours * 1 hours;

    }

    function setParticipantsNumber(uint128 newNumber) public onlyOwner {
        maxParticipant = newNumber;
    }

    function setAffiliateRatio(uint16 newRatio) public onlyOwner {
        require(newRatio < 101);
        affiliateRatio = newRatio;
    }

    function setAffiliateAddress(address _newAffiliate) public onlyOwner {
        require(_newAffiliate != address(0));
        affiliateAddress = _newAffiliate;
    }



    function runLottery() public onlyOwner returns (uint256, address) {
        require(lotteries[currentLottery].participants.length >= minParticipant);
        // require(lotteries[currentLottery].endingTime <= block.timestamp)
        _pause();

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

        lotteries[currentLottery].resultTime = block.timestamp;
        lotteries[currentLottery].winner = winner;
        totalGivenAmount += winningPrice;

        // initialise a new one.
        initialise();
        _unpause();
        emit LotteryRunFinished(
            winner,
            affiliateAmount,
            winningPrice
        );
        return (randomValue, winner);
    }



    function random() internal view returns (uint256) {
        return lotteries[currentLottery].XOR % lotteries[currentLottery].participants.length;
    }
}
