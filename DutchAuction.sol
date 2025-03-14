// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "ERC721.sol";


// 荷兰拍卖
// 荷兰拍卖（Dutch Auction）是一种特殊的拍卖形式。 亦称“减价拍卖”，它是指拍卖标的的竞价由高到低依次递减直到第一个竞买人应价（达到或超过底价）时击槌成交的一种拍卖。
// 在币圈，很多NFT通过荷兰拍卖发售，其中包括Azuki和World of Women，其中Azuki通过荷兰拍卖筹集了超过8000枚ETH。

// 项目方非常喜欢这种拍卖形式，主要有两个原因
// - 荷兰拍卖的价格由最高慢慢下降，能让项目方获得最大的收入。
// -  拍卖持续较长时间（通常6小时以上），可以避免gas war。


// DutchAuction合约
// 代码基于Azuki的代码简化而成。DucthAuction合约继承了之前介绍的ERC721和Ownable合约：

// DutchAuction状态变量
// 合约中一共有9个状态变量，其中有6个和拍卖相关，他们是：
// COLLECTION_SIZE：NFT总量。
// AUCTION_START_PRICE：荷兰拍卖起拍价，也是最高价。
// AUCTION_END_PRICE：荷兰拍卖结束价，也是最低价/地板价。
// AUCTION_TIME：拍卖持续时长。
// AUCTION_DROP_INTERVAL：每过多久时间，价格衰减一次。
// auctionStartTime：拍卖起始时间（区块链时间戳，block.timestamp）。





contract DutchAuction is Ownable, ERC721 {
    uint256 public constant COLLECTION_SIZE = 100000; //NFT总数
    uint256 public constant AUCTION_START_PRICE = 1 ether; // 起拍价（最高价）
    uint256 public constant AUCTION_END_PRICE = 0.1 ether; // 结束加（最低价/地板价）
    uint256 public constant AUCTION_TIME = 10 minutes; // 拍卖时间，为了测试方便设为10分钟
    uint256 public constant AUCTION_DROP_INTERVAL = 1 minutes; // 每过多久时间，价格衰减一次
    uint256 public constant AUCTION_DROP_PER_STEP =
        (AUCTION_START_PRICE - AUCTION_END_PRICE) /
        (AUCTION_TIME / AUCTION_DROP_INTERVAL); // 每次价格衰减步长
    
    uint256 public auctionStartTime; // 拍卖开始时间戳
    string private _baseTokenURI;   // metadata URI
    uint256[] private _allTokens; // 记录所有存在的tokenId

    // 设置拍卖其实时间：在构造函数中声明当前区块时间为起始时间
    // 项目方也可以通过setAuctionStartTime(uint32)函数来调整
    // 
    constructor() Ownable(msg.sender) ERC721("DutchAuction", "DNTA") {
        auctionStartTime = block.timestamp;
    }

    // 设置起始拍卖时间
    function setAuctionStartTime(uint32 timestamp) external onlyOwner {
        auctionStartTime = timestamp;
    }

    // 返回总的token数量
    function totalSupply() public view virtual returns(uint256) {
        return _allTokens.length;
    }

    // 添加新的token到_allToken中
    function _addTokenToAllTokens(uint256 tokenId) private{
        _allTokens.push(tokenId);
    }

    // 获取实时拍卖价格
    function getAuctionPrice() 
        public 
        view 
        returns(uint256)
    {
        if(block.timestamp < auctionStartTime) {
            // 如果拍卖还未开始，则为最高价
            return AUCTION_START_PRICE;
        }else if(block.timestamp - auctionStartTime >= AUCTION_TIME) {
            // 拍卖结束，则为最低价
            return AUCTION_END_PRICE;
        }else{
            // 如果拍卖中，则计算出当前衰减价格
            uint256 steps = (block.timestamp - auctionStartTime) / AUCTION_DROP_PER_STEP;
            return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
        }
    }


    // 拍卖mint函数
    function auctionMint(uint256 quantity) external  payable {
        uint256 _saleStartTime = uint256(auctionStartTime); // 建立local变量，减少gas花费

        require(
            _saleStartTime != 0 && block.timestamp >= _saleStartTime,
            "sale has not started yet"
        ); // 检查拍卖是否开始

        require(
            totalSupply() + quantity <= COLLECTION_SIZE,
            "not enough remaining reserved for auction to support desired mint amount"
        ); // 检查是否超过NFT上限

        uint256 totalCost = getAuctionPrice() * quantity; // 计算拍卖mint成本
        require(msg.value >= totalCost, "Need to send more ETH."); // 检查ETH是否足够

        // mint NFT
        for(uint256 i = 0; i < quantity; i++) {
            uint256 mintIndex = totalSupply();
            _mint(msg.sender, mintIndex);
            _addTokenToAllTokens(mintIndex);
        }

        // 剩余eth退款
        if(msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost); //注意一下这里是否有重入的风险
        }
    

    }
    

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

     // BaseURI setter函数, onlyOwner
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    //项目方取出筹集的ETH：项目方可以通过withdrawMoney()函数提走拍卖筹集的ETH。
    function withdrawMoney() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}(""); // call函数的调用方式
    }
    
    
}

// 演示
//