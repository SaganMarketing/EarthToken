pragma solidity ^0.4.15;

interface ERC20 {
    /// @notice Info: universal total `uint` amount of token
    /// @return Total amount of tokens
    function totalSupply() public constant returns (uint);

    /// @notice Info: `uint` token balance of `address`
    /// @return The balance of the provided address
    function balanceOf(address) public constant returns (uint);

    /// @notice Event: approve to transfer `uint` amount of `msg.sender` token to `address`
    /// @return Whether the approval was successful
    function approve(address, uint) public returns (bool);

    /// @notice Info: remaining amount of token approved by 1st `address` to 2nd `address`
    /// @return Amount of remaining tokens allowed to be received
    function allowance(address, address) public constant returns (uint);

    /// @notice Event: send `uint` amount of approved token to `address` from `msg.sender`
    /// @return Whether the transfer was successful
    function transfer(address, uint) public returns (bool);

    /// @notice Event: send `uint` amount of token from 1st `address` to 2nd `address`
    /// @return Whether the transfer was successful
    function transferFrom(address, address, uint) public returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);
}