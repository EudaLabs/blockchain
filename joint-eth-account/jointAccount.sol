// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract JointAccount {
    address public owner1; // Address of the first account owner
    address public owner2; // Address of the second account owner
    uint public balance; // Tracks the balance of the contract

    mapping(address => bool) public withdrawalApproval; // Keeps track of approvals

    // Modifier to restrict access to only owners
    modifier onlyOwners() {
        require(msg.sender == owner1 || msg.sender == owner2, "Not authorized");
        _;
    }

    // Event declarations
    event Deposit(address indexed sender, uint amount);
    event WithdrawRequest(address indexed requester, uint amount);
    event WithdrawApproved(address indexed approver);
    event FundsWithdrawn(address indexed receiver, uint amount);

    // Constructor sets the owners of the account
    constructor(address _owner1, address _owner2) {
        owner1 = _owner1;
        owner2 = _owner2;
    }

    // Function to deposit funds into the account
    function deposit() external payable {
        balance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // Function to request withdrawal
    function requestWithdrawal() external onlyOwners {
        withdrawalApproval[msg.sender] = true; // Mark the caller's approval
        emit WithdrawApproved(msg.sender);
    }

    // Function to withdraw funds after both owners approve
    function withdraw(uint _amount) external onlyOwners {
        require(withdrawalApproval[owner1], "Owner1 approval required");
        require(withdrawalApproval[owner2], "Owner2 approval required");
        require(_amount <= balance, "Insufficient balance");

        // Reset approvals after successful withdrawal
        withdrawalApproval[owner1] = false;
        withdrawalApproval[owner2] = false;

        balance -= _amount; // Deduct amount from balance
        payable(msg.sender).transfer(_amount); // Transfer funds
        emit FundsWithdrawn(msg.sender, _amount);
    }

    // Fallback function to receive Ether
    receive() external payable {
        balance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}
