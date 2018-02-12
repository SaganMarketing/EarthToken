pragma solidity ^0.4.15;

contract Owned {
    address public owner;

    event OwnershipTransferred(address indexed from, address indexed to);

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwnerAllowed {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwnerAllowed {
        owner = newOwner;
    }
}