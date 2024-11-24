// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockPancakeRouter {
    address public pair;
    
    function setPair(address _pair) external {
        pair = _pair;
    }
    
    function factory() external view returns (address) {
        return address(this);
    }
    
    function WETH() external view returns (address) {
        return address(this);
    }
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        require(token != address(0), "Invalid token");
        require(amountTokenDesired >= amountTokenMin, "Insufficient token amount");
        require(msg.value >= amountETHMin, "Insufficient ETH amount");
        require(to != address(0), "Invalid recipient");
        require(deadline >= block.timestamp, "Deadline expired");

        return (amountTokenDesired, msg.value, amountTokenDesired);
    }
}