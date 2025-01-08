// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract Marketplace is ReentrancyGuard, Ownable {
    constructor() Ownable(msg.sender) {}
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingCounter;
    uint256 public platformFeePercent = 2;

    event ItemListed(
        uint256 indexed listingId, 
        address indexed seller, 
        address nftContract, 
        uint256 tokenId, 
        uint256 price
    );
    event ItemSold(
        uint256 indexed listingId, 
        address indexed buyer, 
        uint256 price
    );

    function listItem(
        address _nftContract, 
        uint256 _tokenId, 
        uint256 _price
    ) external nonReentrant {
        require(_price > 0, "Price must be above zero");
        
        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId) == msg.sender, "Not token owner");
        require(
            nft.getApproved(_tokenId) == address(this) || 
            nft.isApprovedForAll(msg.sender, address(this)), 
            "Contract not approved"
        );

        uint256 listingId = listingCounter++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            active: true
        });

        emit ItemListed(listingId, msg.sender, _nftContract, _tokenId, _price);
    }

    function buyItem(uint256 _listingId) external payable nonReentrant {
        Listing storage listing = listings[_listingId];
        require(listing.active, "Item not listed");
        require(msg.value >= listing.price, "Insufficient funds");

        uint256 platformFee = (listing.price * platformFeePercent) / 100;
        uint256 sellerProceeds = listing.price - platformFee;

        listing.active = false;
        
        IERC721 nft = IERC721(listing.nftContract);
        nft.safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        payable(listing.seller).transfer(sellerProceeds);
        payable(owner()).transfer(platformFee);

        emit ItemSold(_listingId, msg.sender, listing.price);

        // Refund excess payment
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
    }
}