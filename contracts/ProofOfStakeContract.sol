pragma solidity ^0.4.15;

interface ProofOfStakeContract {
    function mint() public returns (bool);
    function coinAge() public constant returns (uint);
    function annualInterest() public constant returns (uint);
    
    event Mint(address indexed stakeHolder, uint amount);
}