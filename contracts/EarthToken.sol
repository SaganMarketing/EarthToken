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

    uint public chainStartTime;
    uint public chainStartBlockNumber;

    uint public stakeStartTime;
    uint public stakeMinimumAge;
    uint public annualInterestYield;

    struct TransferIn {
        uint128 amount;
        uint64 time;
    }

    mapping(address => uint) userBalances;
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
        version = "0.3";
         // 1 million
        totalInitialSupply = uint(1000000).multiply(uint(10).power(decimals));
        totalSupply = totalInitialSupply;
         // 10 million
        maxTotalSupply = uint(10000000).multiply(uint(10).power(decimals));

        chainStartTime = now;
        chainStartBlockNumber = block.number;

        stakeMinimumAge = 30 days;

        // default 10% annual interest yield
        annualInterestYield = uint(10).power(decimals.subtract(1));

        userBalances[owner] = totalSupply;

        Transfer(address(0), owner, totalSupply);
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
        return userBalances[holder];
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
        
        userBalances[msg.sender] = userBalances[msg.sender].subtract(amount);
        userBalances[to] = userBalances[to].add(amount);

        Transfer(msg.sender, to, amount);

        if (transferIns[msg.sender].length > 0) 
            delete transferIns[msg.sender];

        var time = uint64(now);
        transferIns[msg.sender].push(TransferIn(uint128(userBalances[msg.sender]), time));
        transferIns[to].push(TransferIn(uint128(amount), time));

        return true;
    }

    function transferFrom(address from, address to, uint amount) onlyPayloadSize(3 * 32) public returns (bool) {
        require(to != address(0));

        userBalances[from] = userBalances[from].subtract(amount);
        userBalances[to] = userBalances[to].add(amount);

        allowed[from][msg.sender] = allowed[from][msg.sender].subtract(amount);

        Transfer(from, to, amount);

        if (transferIns[from].length > 0) 
            delete transferIns[from];

        var time = uint64(now);
        transferIns[from].push(TransferIn(uint128(userBalances[from]), time));
        transferIns[to].push(TransferIn(uint128(amount), time));
        
        return true;
    }

    function mint() canMintProofOfStake public returns (bool) {
        if (userBalances[msg.sender] <= 0) 
            return false;

        if (transferIns[msg.sender].length <= 0) 
            return false;

        uint reward = getProofOfStakeReward(msg.sender);

        if (reward <= 0) 
            return false;

        totalSupply = totalSupply.add(reward);

        userBalances[msg.sender] = userBalances[msg.sender].add(reward);

        delete transferIns[msg.sender];

        transferIns[msg.sender].push(TransferIn(uint128(userBalances[msg.sender]), uint64(now)));

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
    }

    /* @dev allow owner to burn a certain amount of token */
    function ownerBurnToken(uint amount) public onlyOwnerAllowed {
        require(amount > 0);

        userBalances[msg.sender] = userBalances[msg.sender].subtract(amount);
        
        delete transferIns[msg.sender];
        
        transferIns[msg.sender].push(TransferIn(uint128(userBalances[msg.sender]), uint64(now)));

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
        require(total <= userBalances[msg.sender]);

        uint64 time = uint64(now);

        for (uint j = 0; j < recipients.length; j++) {
            userBalances[recipients[j]] = userBalances[recipients[j]].add(amounts[j]);

            transferIns[recipients[j]].push(TransferIn(uint128(amounts[j]), time));
            
            Transfer(msg.sender, recipients[j], amounts[j]);
        }

        userBalances[msg.sender] = userBalances[msg.sender].subtract(total);

        if (transferIns[msg.sender].length > 0) 
            delete transferIns[msg.sender];

        if (userBalances[msg.sender] > 0) 
            transferIns[msg.sender].push(TransferIn(uint128(userBalances[msg.sender]), time));

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