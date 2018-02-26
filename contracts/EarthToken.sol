pragma solidity ^0.4.15;

import "./ERC20Contract.sol";
import "./OwnedContract.sol";
import "./ProofOfStakeContract.sol";
import "../libraries/SafeMathLibrary.sol";

// ----------------------------------------------------------------------------
// 'Earth' token contract, based on Proof Of Stake
// Symbol               : RTH
// Name                 : Earth Token
// Total Initial Supply : 1,000,000 * (+18 decimal places)
// Total Maximum Supply : 10,000,000 * (+18 decimals places)
// Decimal Places       : 18
//
//
// Previous DEV Deploy  : 0xD52193f518619aaa043F2A112717C7A2FD1e35E9
// Previous PROD Deploy : N/A
// Based on: https://github.com/PoSToken/PoSToken/blob/master/contracts/PoSToken.sol
//
// Other samples: 
// https://github.com/OpenZeppelin/zeppelin-solidity/tree/master/contracts
//
// (c) Atova, Inc.
// ----------------------------------------------------------------------------

// !!!!!!

    //todo: add Crowdsale

// !!!!!!

contract EarthToken is ERC20, Owned, ProofOfStakeContract {
    using SafeMath for uint;
    using SafeMath for uint128;
    using SafeMath for uint64;
    using SafeMath for uint32;
    using SafeMath for uint16;
    using SafeMath for uint8;

    string public name;
    string public symbol;
    uint8 public decimals;
    string public version;
    
    uint public totalSupply;
    uint public totalInitialSupply;
    uint public maxTotalSupply;
    uint private onePercentOfMaxTotalSupply;

    uint public icoStartTime;
    uint public chainStartTime;
    uint public chainStartBlockNumber;
    
    uint public stakeStartTime;
    bool private isStakeStartTimeSet;
    uint public stakeMinimumAge;
    uint public annualInterestYield;

    struct TransferIn {
        uint128 amount;
        uint64 time;
    }

    mapping(address => uint) founderBalances;
    mapping(address => uint) preIcoBalances;
    mapping(address => uint) regularBalances;
    mapping(address => mapping(address => uint)) allowed;
    mapping(address => TransferIn[]) transferIns;

    event Burn(address indexed burner, uint256 value);

    modifier canMintProofOfStake() {
        require(totalSupply < maxTotalSupply);
        _;
    }

    function EarthToken() public {
        name = "Earth Token";
        symbol = "RTH";
        decimals = 18;
        version = "0.4";

        stakeMinimumAge = 30 days;

        // default 10% annual interest yield
        annualInterestYield = uint(10).power(decimals.subtract(1));
        
        // 10 trillion (10,000,000,000,000)
        maxTotalSupply = uint(10000000000000).multiply(uint(10).power(decimals));
        
        onePercentOfMaxTotalSupply = maxTotalSupply.divide(100);

        chainStartTime = now;
        chainStartBlockNumber = block.number;

        founderBalances[this] = onePercentOfMaxTotalSupply;
        Transfer(address(0), this, onePercentOfMaxTotalSupply);

        preIcoBalances[this] = onePercentOfMaxTotalSupply;
        Transfer(address(0), this, onePercentOfMaxTotalSupply);
    }

    function name() public constant returns (string) {
        return name;
    }

    function symbol() public constant returns (string) {
        return symbol;
    }

    function decimals() public constant returns (uint) {
        return decimals;
    }

    function version() public constant returns (string) {
        return version;
    }

    function totalSupply() public constant returns (uint) {
        return totalSupply;
    }

    function balanceOf(address holder) public constant returns (uint) {
        return regularBalances[holder];
    }

    function allowance(address approver, address approvee) public constant returns (uint) {
        return allowed[approver][approvee];
    }

    function approve(address requester, uint amount) public returns (bool) {
        require((amount == 0) || (allowed[msg.sender][requester] == 0));

        allowed[msg.sender][requester] = amount;
        
        Approval(msg.sender, requester, amount);
        
        return true;
    }

    function transfer(address to, uint amount) onlyPayloadSize(2 * 32) public returns (bool) {
        if (msg.sender == to) 
            return mint();
        
        regularBalances[msg.sender] = regularBalances[msg.sender].subtract(amount);
        regularBalances[to] = regularBalances[to].add(amount);

        Transfer(msg.sender, to, amount);

        if (transferIns[msg.sender].length > 0) 
            delete transferIns[msg.sender];

        var time = uint64(now);
        transferIns[msg.sender].push(TransferIn(uint128(regularBalances[msg.sender]), time));
        transferIns[to].push(TransferIn(uint128(amount), time));

        return true;
    }

    function transferFrom(address from, address to, uint amount) onlyPayloadSize(3 * 32) public returns (bool) {
        require(to != address(0));

        regularBalances[from] = regularBalances[from].subtract(amount);
        regularBalances[to] = regularBalances[to].add(amount);

        allowed[from][msg.sender] = allowed[from][msg.sender].subtract(amount);

        Transfer(from, to, amount);

        if (transferIns[from].length > 0) 
            delete transferIns[from];

        var time = uint64(now);
        transferIns[from].push(TransferIn(uint128(regularBalances[from]), time));
        transferIns[to].push(TransferIn(uint128(amount), time));
        
        return true;
    }

// 
    function mint() canMintProofOfStake public returns (bool) {
        if (regularBalances[msg.sender] <= 0) 
            return false;

        if (transferIns[msg.sender].length <= 0) 
            return false;

        uint reward = getProofOfStakeReward(msg.sender);

        if (reward <= 0) 
            return false;

// !!!!!!!!

        // todo: take from regularBalances[this] (instead of minting more) while regularBalances[this] has any money
        // we should only mint the annual 1%, and rewards are first come first served while regularBalances[this] has anything available???

// !!!!!!!!

        totalSupply = totalSupply.add(reward);

        regularBalances[msg.sender] = regularBalances[msg.sender].add(reward);

        delete transferIns[msg.sender];

        transferIns[msg.sender].push(TransferIn(uint128(regularBalances[msg.sender]), uint64(now)));

        Mint(msg.sender, reward);
        
        return true;
    }

    function getBlockNumber() public constant returns (uint) {
        return block.number.subtract(chainStartBlockNumber);
    }

    function coinAge() public constant returns (uint) {
        return getCoinAge(msg.sender, now);
    }

    function annualInterest() public constant returns(uint) {
        return annualInterestYield;
    }

    function getProofOfStakeReward(address holder) internal constant returns (uint) {
        var time = now;
        
        require((time >= stakeStartTime) && (stakeStartTime > 0));

        uint age = getCoinAge(holder, time);
        
        if (age <= 0) 
            return 0;

        uint fullDecimals = uint(10).power(decimals);

        return (age).multiply(annualInterest()).divide(uint(365).multiply(fullDecimals));
    }

    // todo: really understand this
    function getCoinAge(address holder, uint time) internal constant returns (uint) {
        if (transferIns[holder].length <= 0) 
            return 0;

        uint age = 0;
        for (uint i = 0; i < transferIns[holder].length; i++) {
            if (time < uint(transferIns[holder][i].time).add(stakeMinimumAge))
                continue;

            uint nCoinSeconds = time.subtract(uint(transferIns[holder][i].time));

            age = age.add(uint(transferIns[holder][i].amount) * nCoinSeconds.divide(1 days));
        }

        return age;
    }

    /* !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Fixes and Owner Stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  */
    /* @dev allows owner to start the time ticking on the proof of stake rewards  */
    function ownerSetStakeStartTime(uint timestamp) public onlyOwnerAllowed {
        require((stakeStartTime <= 0) && (timestamp >= chainStartTime));

        stakeStartTime = timestamp;
        
        regularBalances[this] = onePercentOfMaxTotalSupply;
        Transfer(address(0), this, onePercentOfMaxTotalSupply);

        totalInitialSupply = onePercentOfMaxTotalSupply;
        totalSupply = onePercentOfMaxTotalSupply;
    }

    /* @dev allows owner can set founders  */
    function ownerSetFounders(address[] founders, uint[] percent) public onlyOwnerAllowed {
        require(founderBalances[this] > 0);
        
        uint totalPercent = 0;
        for (uint iPercent = 0; iPercent < percent.length; iPercent++) {
            totalPercent += percent[iPercent];
        }
        require(totalPercent == 100);

        var availableBalance = founderBalances[this];

        for (uint iFounders = 0; iFounders < founders.length; iFounders++) {
            var amount = availableBalance.divide(uint(100).divide(percent[iFounders]));

            founderBalances[founders[iFounders]] = amount;
            founderBalances[this] -= amount;

            Transfer(this, founders[iFounders], amount);
        }

        if (founderBalances[this] != 0) {
            founderBalances[owner] += founderBalances[this];

            // todo: do this at specified time intervals, timed release 25% each quarter for a year, with a start date of ICO date)
            // Transfer(this, owner, amount);
        }

        founderBalances[this] = 0;
    }

    function ownerAddPreIcoHolder(address preIcoHolder, uint amount)  onlyPayloadSize(2 * 32) public onlyOwnerAllowed returns (bool) {
        require(preIcoBalances[this] > amount);

        preIcoBalances[preIcoHolder] = amount;
        preIcoBalances[this] -= amount;

        // todo: do this at specified time intervals, timed release (50% each 30 days and 60 days from ICO date)
        // Transfer(this, founders[iFounders], amount);
    }


// !!!!!!!!!!!!!!!!!!!!!!!

    // todo: do the timed releases of:
    // founders: 1% founders tokens timed release 25% each quarter for a year, with a start date TBD (start time = ico date)
    // preIco: 1% pre-ico token timed release (50% each 30 days and 60 days from ICO)
    // annual 1 % until we hit maxTotalSupply

// !!!!!!!!!!!!!!!!!!!!!!!



    /* @dev allow owner to burn a certain amount of token */
    function ownerBurnToken(uint amount) public onlyOwnerAllowed {
        require(amount > 0);

        regularBalances[msg.sender] = regularBalances[msg.sender].subtract(amount);
        
        delete transferIns[msg.sender];
        
        transferIns[msg.sender].push(TransferIn(uint128(regularBalances[msg.sender]), uint64(now)));

        totalSupply = totalSupply.subtract(amount);

        totalInitialSupply = totalInitialSupply.subtract(amount);
        maxTotalSupply = maxTotalSupply.subtract(amount.multiply(10));

        Burn(msg.sender, amount);
    }

    /* @dev batch token transfer. Used by owner to distribute tokens to multiple holders */
    function batchTransfer(address[] recipients, uint[] amounts) public onlyOwnerAllowed returns (bool) {
        require(recipients.length > 0 && recipients.length == amounts.length);

        uint total = 0;
        for (uint i = 0; i < amounts.length; i++) {
            total = total.add(amounts[i]);
        }
        require(total <= regularBalances[msg.sender]);

        uint64 time = uint64(now);

        for (uint j = 0; j < recipients.length; j++) {
            regularBalances[recipients[j]] = regularBalances[recipients[j]].add(amounts[j]);

            transferIns[recipients[j]].push(TransferIn(uint128(amounts[j]), time));
            
            Transfer(msg.sender, recipients[j], amounts[j]);
        }

        regularBalances[msg.sender] = regularBalances[msg.sender].subtract(total);

        if (transferIns[msg.sender].length > 0) 
            delete transferIns[msg.sender];

        if (regularBalances[msg.sender] > 0) 
            transferIns[msg.sender].push(TransferIn(uint128(regularBalances[msg.sender]), time));

        return true;
    }

    /* @dev fix for the ERC20 short address attack */
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    /* @dev if ETH is sent to this address, send it back */
    function () public payable { 
        revert(); 
    }

    /* @dev owner can transfer out any accidentally sent ERC20 tokens */
    function transferAnyERC20Token(address from, uint amount) public onlyOwnerAllowed returns (bool success) {
        return ERC20(from).transfer(owner, amount);
    }
}