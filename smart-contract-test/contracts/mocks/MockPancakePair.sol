// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockPancakePair {
    mapping(address => uint256) public balanceOf;
    uint112 private reserve0 = 1000 ether;
    uint112 private reserve1 = 1000 ether;
    
    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, uint32(block.timestamp));
    }
    
    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function token0() external view returns (address) {
        return address(this);
    }

    function token1() external view returns (address) {
        return address(this);
    }
}