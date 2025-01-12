// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

// Custom errors for efficient error handling
error InvalidAddress();
error NotOwner(address nftAddress, uint256 tokenId, address seller);
error NotApproved(address nftAddress, uint256 tokenId, address owner);
error FloorPriceLessThanZero(uint256 startingPrice, uint256 discountRate, uint256 duration);
error AuctionAlreadyCreated(address nftAddress, uint256 tokenId);
error AuctionNotInProgress(address nftAddress, uint256 tokenId);
error InsufficientAmount(address nftAddress, uint256 tokenId, uint256 price);
error TransactionFailed();
error NotAuctionSeller(address seller);

/**
 * @title Dutch Auction Contract
 * @notice Implements a simple Dutch auction mechanism for ERC721 NFTs.
 * @dev Uses the OpenZeppelin IERC721 interface for interacting with NFTs.
 */
contract DutchAuction {
    enum AuctionStatus { NOT_CREATED, IN_PROGRESS, ENDED }

    event AuctionCreated(address indexed nftAddress, uint256 indexed tokenId);
    event AuctionEnded(address indexed nftAddress, uint256 indexed tokenId, address winner);

    uint256 private constant DURATION = 7 days;

    struct Auction {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 startingAt;
        uint256 endingAt;
        uint256 startingPrice;
        uint256 discountRate;
        AuctionStatus status;
    }

    mapping(address => mapping(uint256 => Auction)) public auctions;

    /**
     * @notice Modifier to ensure auction is not already created.
     */
    modifier auctionNotCreated(address _nftAddress, uint256 _tokenId) {
        if (auctions[_nftAddress][_tokenId].status != AuctionStatus.NOT_CREATED) {
            revert AuctionAlreadyCreated(_nftAddress, _tokenId);
        }
        _;
    }

    /**
     * @notice Modifier to ensure auction is in progress.
     */
    modifier auctionInProgress(address _nftAddress, uint256 _tokenId) {
        if (auctions[_nftAddress][_tokenId].status != AuctionStatus.IN_PROGRESS) {
            revert AuctionNotInProgress(_nftAddress, _tokenId);
        }
        _;
    }

    /**
     * @notice Creates a new auction for an NFT.
     */
    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _discountRate
    ) external auctionNotCreated(_nftAddress, _tokenId) {
        if (_nftAddress == address(0)) revert InvalidAddress();
        if (IERC721(_nftAddress).ownerOf(_tokenId) != msg.sender) {
            revert NotOwner(_nftAddress, _tokenId, msg.sender);
        }
        if (
            !(IERC721(_nftAddress).getApproved(_tokenId) == address(this) ||
              IERC721(_nftAddress).isApprovedForAll(msg.sender, address(this))
            )
        ) {
            revert NotApproved(_nftAddress, _tokenId, msg.sender);
        }
        if (_startingPrice < _discountRate * DURATION) {
            revert FloorPriceLessThanZero(_startingPrice, _discountRate, DURATION);
        }

        auctions[_nftAddress][_tokenId] = Auction({
            seller: msg.sender,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            startingAt: block.timestamp,
            endingAt: block.timestamp + DURATION,
            startingPrice: _startingPrice,
            discountRate: _discountRate,
            status: AuctionStatus.IN_PROGRESS
        });

        emit AuctionCreated(_nftAddress, _tokenId);
    }

    /**
     * @notice Purchases an NFT from the auction.
     */
    function buyItem(address _nftAddress, uint256 _tokenId)
        external
        payable
        auctionInProgress(_nftAddress, _tokenId)
    {
        Auction storage auction = auctions[_nftAddress][_tokenId];
        uint256 price = getPrice(_nftAddress, _tokenId);

        if (msg.value < price) revert InsufficientAmount(_nftAddress, _tokenId, price);

        // Refund excess payment
        if (msg.value > price) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - price}("");
            if (!refundSuccess) revert TransactionFailed();
        }

        // Transfer NFT and funds
        IERC721(_nftAddress).safeTransferFrom(auction.seller, msg.sender, _tokenId);
        (bool paymentSuccess, ) = payable(auction.seller).call{value: price}("");
        if (!paymentSuccess) revert TransactionFailed();

        // End auction
        auction.status = AuctionStatus.ENDED;

        emit AuctionEnded(_nftAddress, _tokenId, msg.sender);
    }

    /**
     * @notice Cancels an auction by the seller.
     */
    function cancelAuction(address _nftAddress, uint256 _tokenId)
        external
        auctionInProgress(_nftAddress, _tokenId)
    {
        Auction storage auction = auctions[_nftAddress][_tokenId];
        if (auction.seller != msg.sender) {
            revert NotAuctionSeller(auction.seller);
        }

        auction.status = AuctionStatus.ENDED;
        emit AuctionEnded(_nftAddress, _tokenId, address(0));
    }

    /**
     * @notice Retrieves the current price of the NFT in the auction.
     */
    function getPrice(address _nftAddress, uint256 _tokenId)
        public
        view
        auctionInProgress(_nftAddress, _tokenId)
        returns (uint256)
    {
        Auction storage auction = auctions[_nftAddress][_tokenId];
        uint256 elapsed = block.timestamp - auction.startingAt;
        uint256 discount = elapsed * auction.discountRate;
        return auction.startingPrice > discount ? auction.startingPrice - discount : 0;
    }

    /**
     * @notice Retrieves the details of an auction.
     */
    function getAuction(address _nftAddress, uint256 _tokenId)
        public
        view
        returns (Auction memory)
    {
        return auctions[_nftAddress][_tokenId];
    }

    /**
     * @notice Returns the duration of the auction (7 days).
     */
    function getDuration() public pure returns (uint256) {
        return DURATION;
    }
}
