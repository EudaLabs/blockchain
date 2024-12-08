// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Added for additional security

contract AdvancedERC1155 is
    ERC1155,
    Ownable,
    Pausable,
    ERC1155Burnable,
    ERC1155Supply,
    ReentrancyGuard
{
    // Events for better transparency and monitoring
    event URIUpdated(string newURI);
    event TokensMinted(address indexed to, uint256 indexed id, uint256 amount);
    event BatchMinted(address indexed to, uint256[] ids, uint256[] amounts);

    // Maximum supply per token ID
    mapping(uint256 => uint256) public maxSupply;
    
    // Mapping to track if a token ID has been initialized
    mapping(uint256 => bool) public tokenInitialized;

    /**
     * @param baseURI Initial NFT metadata URI
     * @dev Constructor initializes the contract with a base URI for metadata
     */
    constructor(string memory baseURI) ERC1155(baseURI) {
        require(bytes(baseURI).length > 0, "Base URI cannot be empty");
    }

    /**
     * @dev Updates the base URI for token metadata
     * @param newuri New base URI
     * Requirements:
     * - Only owner can call
     * - New URI cannot be empty
     */
    function setURI(string memory newuri) external onlyOwner {
        require(bytes(newuri).length > 0, "URI cannot be empty");
        _setURI(newuri);
        emit URIUpdated(newuri);
    }

    /**
     * @dev Sets maximum supply for a token ID
     * @param tokenId Token ID to set max supply for
     * @param max Maximum supply amount
     */
    function setMaxSupply(uint256 tokenId, uint256 max) external onlyOwner {
        require(!tokenInitialized[tokenId], "Max supply already set");
        maxSupply[tokenId] = max;
        tokenInitialized[tokenId] = true;
    }

    /**
     * @dev Pauses all token transfers
     * Requirements:
     * - Only owner can call
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses token transfers
     * Requirements:
     * - Only owner can call
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Mints new tokens
     * @param account Recipient address
     * @param id Token ID to mint
     * @param amount Amount to mint
     * @param data Additional data for receivers
     * Requirements:
     * - Only owner can mint
     * - Must not exceed max supply
     */
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner nonReentrant {
        require(account != address(0), "Cannot mint to zero address");
        require(tokenInitialized[id], "Token ID not initialized");
        require(
            totalSupply(id) + amount <= maxSupply[id],
            "Would exceed max supply"
        );
        
        _mint(account, id, amount, data);
        emit TokensMinted(account, id, amount);
    }

    /**
     * @dev Batch mints multiple token types
     * @param to Recipient address
     * @param ids Array of token IDs
     * @param amounts Array of amounts to mint
     * @param data Additional data for receivers
     * Requirements:
     * - Arrays must be same length
     * - Must not exceed max supply for any token
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner nonReentrant {
        require(to != address(0), "Cannot mint to zero address");
        require(ids.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            require(tokenInitialized[ids[i]], "Token ID not initialized");
            require(
                totalSupply(ids[i]) + amounts[i] <= maxSupply[ids[i]],
                "Would exceed max supply"
            );
        }

        _mintBatch(to, ids, amounts, data);
        emit BatchMinted(to, ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer
     * Includes batched transfers
     * Adds supply tracking and transfer pause functionality
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Prevents accidental ETH transfers to the contract
     */
    receive() external payable {
        revert("Contract does not accept ETH");
    }
}