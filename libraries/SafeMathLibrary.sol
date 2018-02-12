pragma solidity ^0.4.15;

// prevent common math bugs
library SafeMath {
    function add(uint a, uint b) internal constant returns (uint) {
        uint c = a + b;
        
        require(c >= a);

        return c;
    }
    function subtract(uint a, uint b) internal constant returns (uint) {
        require(b <= a);
        
        uint c = a - b;

        return c;
    }
    function multiply(uint a, uint b) internal constant returns (uint) {
        uint c = a * b;
        
        require(a == 0 || c / a == b);

        return c;
    }
    function divide(uint a, uint b) internal constant returns (uint) {
        require(b > 0);
        
        uint c = a / b;

        return c;
    }
    function power(uint a, uint b) internal constant returns (uint) {
        require(a > 0);
        require(b > 0);

        uint c = a ** b;

        return c;
    }
}