// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Marketplace is ReentrancyGuard {
    address payable public immutable feeAccount;
    uint256 public immutable feePercent;
    uint256 public itemCount;

    struct Item {
        uint256 itemId;
        IERC721 nft;
        uint256 tokenId;
        uint256 price;
        address payable seller;
        bool sold;
    }

    event NFTItem(
        uint256 itemId,
        IERC721 nft,
        uint256 tokenId,
        uint256 price,
        address payable seller,
        bool sold
    );

    event Purchased(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    event Offered(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    constructor(uint256 _feePercent) {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
        itemCount = 0;
    }

    //table database for storing the nfts based on their id
    mapping(uint256 => Item) public items;

    //make item after minting and getting the tokenId
    function makeItem(
        IERC721 _nft,
        uint256 _tokenId,
        uint256 _price
    ) external nonReentrant {
        require(_price > 0, "Price must be greater than 0");
        itemCount++;
        _nft.transferFrom(msg.sender, address(this), _tokenId);

        items[itemCount] = Item(
            itemCount,
            _nft,
            _tokenId,
            _price,
            payable(msg.sender),
            false
        );
    }

    //list all the nfts
    function listNFTs() external {
        for (uint256 i = 0; i < itemCount; i++) {
            emit NFTItem(
                items[i].itemId,
                items[i].nft,
                items[i].tokenId,
                items[i].price,
                items[i].seller,
                items[i].sold
            );
        }
    }

    function purchaseNFT(uint _id) external payable nonReentrant {
        Item storage item = items[_id];
        require(!item.sold, "Item already sold");

        uint price = getTotalPrice(_id);
        require(msg.value >= price, "Not sufficient amount");

        //pay seller, feeAccount and transfer the ownership
        item.seller.transfer(item.price);
        feeAccount.transfer(price - item.price);
        payable(msg.sender).transfer(msg.value - price); //send back excess amount
        
        item.sold = true;
        item.seller = payable(msg.sender);
        item.nft.transferFrom(address(this), msg.sender, item.tokenId);

        emit Purchased(_id, address(item.nft), item.tokenId, item.price, item.seller, msg.sender);
    }

    function getTotalPrice(uint _itemId) view internal returns(uint) {
        return((items[_itemId].price*(100 + feePercent))/100);
    }

    function offerNFT(uint _id, uint _price) external payable nonReentrant {
        Item storage item = items[_id];
        require(item.seller == msg.sender, "You are not the owner");

        //make the item available with the new price
        item.price = _price;
        item.sold = false;
        item.nft.transferFrom(msg.sender, address(this), item.tokenId);
    
        emit Offered(_id, address(item.nft), item.tokenId, item.price, item.seller, msg.sender);
    }
}
