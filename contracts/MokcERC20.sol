// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract MockERC20 {
    string public constant name = "Mock ERC20 Token";
    string public constant symbol = "MCK";
    uint8 public constant decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    uint256 totalSupply_;

    constructor(uint256 initialSupply) {
        totalSupply_ = initialSupply;
        balances[msg.sender] = totalSupply_;
        emit Transfer(address(0), msg.sender, totalSupply_);
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function increaseTotalSupply(uint256 additionalAmount) public {
        totalSupply_ += additionalAmount;
        balances[msg.sender] += additionalAmount;
        emit Transfer(address(0), msg.sender, additionalAmount);
    }

    function balanceOf(address tokenOwner) public view returns (uint256) {
        return balances[tokenOwner];
    }

    function allowance(address owner, address delegate) public view returns (uint256) {
        return allowed[owner][delegate];
    }

    function approve(address delegate, uint256 numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function transfer(address receiver, uint256 numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] -= numTokens;
        balances[receiver] += numTokens;
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function transferFrom(address owner, address buyer, uint256 numTokens) public returns (bool) {
        require(numTokens <= balances[owner], "Insufficient balance");
        require(numTokens <= allowed[owner][msg.sender], "Insufficient allowance");

        balances[owner] -= numTokens;
        allowed[owner][msg.sender] -= numTokens;
        balances[buyer] += numTokens;
        emit Transfer(owner, buyer, numTokens);
        return true;
    }

    function mint(address account, uint256 amount) public {
        require(account != address(0), "Mint to the zero address");
        totalSupply_ += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}