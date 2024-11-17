// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Lottery
 * @dev A simple lottery contract where participants can buy tickets and a random winner is selected.
 */
contract Lottery is ReentrancyGuard {
    address public owner; // Address of the contract owner
    address[] public players; // List of players
    address public winner; // Address of the selected winner
    uint256 public ticketPrice; // Price of one lottery ticket
    bool public lotteryEnded; // Flag to track if the lottery has ended

    // Restrict access to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    // Ensure the lottery is still active
    modifier lotteryNotEnded() {
        require(!lotteryEnded, "The lottery has ended.");
        _;
    }

    /**
     * @dev Initializes the contract with a specified ticket price.
     * @param _ticketPrice The price of one lottery ticket in wei.
     */
    constructor(uint256 _ticketPrice) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
    }

    /**
     * @dev Allows a user to buy a ticket. Requires exact payment of the ticket price.
     */
    function buyTicket() external payable lotteryNotEnded {
        require(msg.value == ticketPrice, "Incorrect ticket price.");
        players.push(msg.sender);
    }

    /**
     * @dev Ends the lottery and selects a winner. Can only be called by the owner if there are players.
     */
    function endLottery() external onlyOwner lotteryNotEnded {
        require(players.length > 0, "No players in the lottery.");
        lotteryEnded = true;
        selectWinner();
    }

    /**
     * @dev Selects a random winner using pseudo-random data.
     */
    function selectWinner() internal {
        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, players)
            )
        ) % players.length;
        winner = players[randomIndex];
    }

    /**
     * @dev Allows the winner to withdraw the lottery prize.
     */
    function withdraw() external nonReentrant {
        require(lotteryEnded, "The lottery has not ended.");
        require(msg.sender == winner, "Only the winner can withdraw.");
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds to withdraw.");
        (bool sent, ) = payable(winner).call{value: amount}("");
        require(sent, "Failed to send ether.");
    }

    /**
     * @dev Resets the lottery for a new round. Can only be called by the owner after the lottery ends.
     */
    function resetLottery() external onlyOwner {
        require(lotteryEnded, "Cannot reset an active lottery.");
        delete players;
        winner = address(0);
        lotteryEnded = false;
    }

    /**
     * @dev Updates the ticket price. Can only be called by the owner.
     * @param _ticketPrice The new ticket price in wei.
     */
    function setTicketPrice(uint256 _ticketPrice) external onlyOwner {
        ticketPrice = _ticketPrice;
    }

    /**
     * @dev Returns the list of players in the lottery.
     */
    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    /**
     * @dev Prevents accidental Ether transfers to the contract.
     */
    receive() external payable {
        revert("Direct Ether transfers not allowed.");
    }
}
