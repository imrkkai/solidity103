// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 我们魔改下ERC721标准的无聊猿BAYC，创建一个免费铸造的BAYC1155。我们修改_baseURI()函数，使得BAYC1155的uri和BAYC的tokenURI一样。这样，BAYC1155元数据会与无聊猿的相同：

import "ERC1155.sol";

contract BAYC1155 is ERC1155 {

    uint256 constant MAX_ID = 10000;

    // 构造函数
    constructor() ERC1155("BAYC1155", "BAYC1155"){
    }

     //BAYC的baseURI为ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/ 
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/";
    }

    // 铸造函数
    function mint(address to, uint256 id, uint256 amount) external {
        // id 不能超过10,000
        require(id < MAX_ID, "id overflow");
        _mint(to, id, amount, "");
    }


    // 批量铸造函数
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external {
        // id 不能超过10,000
        for (uint256 i = 0; i < ids.length; i++) {
            require(ids[i] < MAX_ID, "id overflow");
        }
        _mintBatch(to, ids, amounts, "");
    }

}


//这一讲我们学习了以太坊EIP1155提出的ERC1155多代币标准，它允许一个合约中包含多个同质化或非同质化代币。并且，我们创建了魔改版无聊猿 - BAYC1155：一个包含10,000种代币且元数据与BAYC相同的ERC1155代币。目前，ERC1155主要应用于GameFi中。但我相信随着元宇宙技术不断发展，这个标准会越来越流行。