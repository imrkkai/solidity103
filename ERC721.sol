// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 同质化代币
// BTC和ETH这类代币都属于同质化代币，矿工挖出的第1枚BTC与第10000枚BTC并没有不同，是等价的。

// 但世界中很多物品是不同质的，其中包括房产、古董、虚拟艺术品等等。
// 这类物品无法用同质化代币抽象。
// 因此，以太坊EIP721提出了ERC721标准，来抽象非同质化的物品。

//EIP和ERC

// EIP全称是Ethereum Improvement Proposals（以太坊改进建议）, 是以太坊开发者社区提出的改进建议, 是一系列已编号排定的文件,类似互联网上IETF的RFC。
// EIP可以是Ethereum 生态中任意领域的改进、比如新特性、ERC、协议改进、编程工具等等。

// ERC全称Ethereum Request For Comment（以太坊意见征求稿），泳衣记录以太坊应用级的各种开发标准和协议。
// 如典型的Token标准（ERC20、ERC721）、名字注册（ERC26、ERC13），URI范式（ERC67），Library/Package格式（EIP82）、钱包格式（EIP75、EIP85）。

// ERC协议标准是影响以太坊发展的重要因素，像ERC20、ERC223，ERC721、ERC777等，都对以太坊生态产生了很大影响。

// 所以最终结论：EIP包含ERC。


// ERC165
// 通过ERC165标准、智能合约可以声明它支持的接口，供其它合约检查。
// 简单的说，ERC165就是检查一个智能合约是不是支持了ERC721、ERC1155的接口

// IERC165接口合约只声明了一个supportsInterface函数，输入要检查的interface接口id，若合约实现了该接口id，则返回true:
// 参考IERC165.sol

// 我们可以看下ERC721是如何实现supportsInterface()函数的：
/*
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
*/

// 当查询的是IERC721或IERC165的接口id时，返回true；反之返回false。


// IERC721
// IERC721是ERC721标准的接口合约，规定了ERC721要实现的基本函数。
// 它利用tokenId来表示特定的非同质化代币，授权或转账都要明确tokenId；
// 而ERC20只需要明确转账的数额即可。

// 接口定义参考: IERC721.sol

// IERC721事件

// IERC721包含3个事件，其中Transfer和Approval事件在ERC20中也有。
// - Transfer事件：在转账时被释放，记录代币的发出地址from，接收地址to和tokenid。
// - Approval事件：在授权时释放，记录授权地址owner，被授权地址approved和tokenid。
// - ApprovalForAll事件：在批量授权时释放，记录批量授权的发出地址owner，被授权地址operator和授权与否的approved。


// IERC721函数

// balanceOf：返回某地址的NFT持有量balance。
// ownerOf：返回某tokenId的主人owner。
// transferFrom：普通转账，参数为转出地址from，接收地址to和tokenId。
// safeTransferFrom：安全转账（如果接收方是合约地址，会要求实现ERC721Receiver接口）。参数为转出地址from，接收地址to和tokenId。
// approve：授权另一个地址使用你的NFT。参数为被授权地址approve和tokenId。
// getApproved：查询tokenId被批准给了哪个地址。
// setApprovalForAll：将自己持有的该系列NFT批量授权给某个地址operator。
// isApprovedForAll：查询某地址的NFT是否批量授权给了另一个operator地址。
// safeTransferFrom：安全转账的重载函数，参数里面包含了data。


// IERC721Receiver

// 如果一个合约没有实现相关ERC721的相关函数，转入的NFT就进入了 黑洞，永远转不出来了。
// 为了防止误转账，ERC721实现了safeTransferFrom()安全转账函数,目标合约必须实现了IERC721Receiver接口才能接收
// ERC721代币，不会会revert。
// IERC721Receiver接口只包含一个onERC721Received函数。

// 参考：IERC721Receiver.sol


//ERC721实现
/*

function _checkOnERC721Received(
    address operator,
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
) internal {
    if (to.code.length > 0) {
        try IERC721Receiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 retval) {
            if (retval != IERC721Receiver.onERC721Received.selector) {
                // Token rejected
                revert IERC721Errors.ERC721InvalidReceiver(to);
            }
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                // non-IERC721Receiver implementer
                revert IERC721Errors.ERC721InvalidReceiver(to);
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }
}

*/

// IERC721Metadata

// IERC721Metadata是ERC721的扩展接口，实现了3个查询metadata元数据的常用函数:
// - name(): 返回代币名称
// - symbol(): 返回代币符号
// - tokenURI(): 通过tokenId查询meta的链接url，ERC721特有的函数

// ERC721主合约

// ERC721主合约实现了IERC721，IERC165和IERC721Metadata定义的所有功能，
// 包含4个状态变量和17个函数。实现都比较简单，每个函数的功能见代码注释：

import "IERC165.sol";
import "IERC721.sol";
import "IERC721Receiver.sol";
import "IERC721Metadata.sol";
import "Strings.sol";

contract ERC721 is IERC721, IERC721Metadata {
    using Strings for uint256; // 使用Strings库
    // token名称
    string public override  name;
    string public override symbol;
    // tokenId到 owner 的持有人映射
    mapping(uint => address) private _owners;
    // address 到持仓数量的 持仓量映射
    mapping(address => uint) private _balances;

    // tokenId到 授权地址的授权映射
    mapping(uint => address) private _tokenApprovals;
    // owner到operator的批量授权映射
    mapping(address => mapping(address => bool)) private _operatorApprovals;


    // 定义error 无效的接受者
    error ERC721InvalidReceiver(address receiver);

    // 构造函数，初始化name和symbol
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // 实现ERC165节supportsInterface
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return 
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    // 实现IERC721的balanceOf，利用_balances变量查询owner地址的balance。
    function balanceOf(address owner) external view override returns (uint) {
        require(owner != address(0), "owner = zero address");
        return _balances[owner];
    }

     // 实现IERC721的ownerOf，利用_owners变量查询tokenId的owner。
    function ownerOf(uint tokenId) public view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "token doesn't exist");
        return owner;
     }


    // 实现IERC721的isApprovedForAll，利用_operatorApprovals变量查询owner地址是否将所持NFT批量授权给了operator地址。
    function isApprovedForAll(address owner, address operator) 
    external 
    view
    override 
    returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    // 实现IERC721的setApprovalForAll，将持有代币全部授权给operator地址。
    // 调用_setApprovalForAll函数。
    function setApprovalForAll(address operator, bool approved)
    external override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // 实现IERC721的getApproved，利用_tokenApprovals变量查询tokenId的授权地址。
    function getApproved(uint tokenId) external view override returns (address) {
        require(_owners[tokenId] != address(0), "token doesn't exist");
        return _tokenApprovals[tokenId];
    }

    // 授权函数。通过调整_tokenApprovals来，授权 to 地址操作 tokenId，同时释放Approval事件。
    function _approve(
        address owner,
        address to,
        uint tokenId
    ) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    // 实现IERC721的approve，将tokenId授权给 to 地址。
    // 条件：to不是owner，且msg.sender是owner或授权地址。调用_approve函数。

    function approve(address to, uint tokenId) external override {
        // 获取tokenId的 owner
        address owner = _owners[tokenId];
        // 调用者是tokenId的owner，或者是tokenId已被批量授权给调用者
        // 这里为什么没有通过_tokenApprovals去校验授权呢? 猜测：当前函数是授权操作，授权未完成。
        require(
            msg.sender == owner || _operatorApprovals[owner][msg.sender],
            "not owner nor approved for all"
        );

        _approve(owner, to, tokenId);
    }

    // 查询 spender地址是否可以使用tokenId（需要是owner或被授权地址）
    function _isApprovedOrOwner(
        address owner,
        address spender,
        uint tokenId
    ) private view returns (bool) {
        return (spender == owner ||
                _tokenApprovals[tokenId] == spender ||
                _operatorApprovals[owner][spender]
            );
     }
    

    /*
     * 转账函数。通过调整_balances和_owner变量将 tokenId 从 from 转账给 to，同时释放Transfer事件。
     * 条件:
     * 1. tokenId 被 from 拥有
     * 2. to 不是0地址
     */

     function _transfer(
        address owner,
        address from,
        address to,
        uint tokenId
     ) private {
        // 判断所有者权限，from必须是owner
        require(from == owner, 'not owner');
        // 接受者不能是黑洞地址0
        require(to != address(0), "transfer to the zero address");
        
        // 将tokenId授权给黑洞地址0，即撤销之前的授权
        _approve(owner, address(0), tokenId);

        // 减少from的数量
        _balances[from] -= 1;
        // 增加接受者的数量
        _balances[to] += 1;
        
        // 设置tokenId的所有者为to地址
        _owners[tokenId] = to;

        // 发布Transfer事件
        emit Transfer(from, to, tokenId);

     }

    // 实现IERC721的transferFrom，非安全转账，不建议使用。调用_transfer函数
    function transferFrom(
        address from,
        address to,
        uint tokenId
    ) external override {
        // 获取tokenId的所有者，不能是地址0
        address owner = ownerOf(tokenId);
        // 需要调用者msg.sender是tokenId的owner，或者已被授权使用tokenId
        require(
            _isApprovedOrOwner(owner, msg.sender, tokenId),
            "not owner nor approved"
        );

           // 调用内部转账方法
        _transfer(owner, from, to, tokenId);

    }

    /**
     * 安全转账，安全地将 tokenId 代币从 from 转移到 to，
       会检查合约接收者是否了解 ERC721 协议，以防止代币被永久锁定。
       调用了_transfer函数和_checkOnERC721Received函数。
     * 如果 to 是智能合约, 他必须支持 IERC721Receiver-onERC721Received.
     */

     function _safeTransfer(
        address owner,
        address from,
        address to,
        uint tokenId,
        bytes memory data
     ) private  {
        _transfer(owner, from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
     }

     /**
     * 实现IERC721的safeTransferFrom，安全转账，调用了_safeTransfer函数。
     * 条件：
     * from 不能是0地址.
     * to 不能是0地址.
     * tokenId 代币必须存在，并且被 from拥有.
     */

     function safeTransferFrom(
        address from,
        address to,
        uint tokenId,
        bytes memory data
     ) public override {
        address owner = ownerOf(tokenId);
        require(
            _isApprovedOrOwner(owner, msg.sender, tokenId),
            "Not owner nor approved"
        );
        _safeTransfer(owner, from, to, tokenId, data);
     }


     function safeTransferFrom(
        address from,
        address to,
        uint tokenId
     ) external override {
        safeTransferFrom(from, to, tokenId, "");
     }

      /** 
        * 铸造函数。通过调整_balances和_owners变量来铸造tokenId并转账给 to，
        * 同时释放Transfer事件。铸造函数。
        * 这个mint函数所有人都能调用，实际使用需要开发人员重写，加上一些条件。
        * 条件:
        * 1. tokenId尚不存在。
        * 2. to不是0地址.
        */

        function _mint(address to, uint tokenId) internal  virtual {
            require(to != address(0), "mint to zero address");
            require(_owners[tokenId] == address(0), "token already minted");

            _balances[to] += 1;
            _owners[tokenId] = to;

            emit Transfer(address(0), to, tokenId);
        }

        // 销毁函数，通过调整_balances和_owners变量来销毁tokenId，同时释放Transfer事件。条件：tokenId存在。

        function _burn(uint tokenId) internal virtual {
            address owner = ownerOf(tokenId);
            require(msg.sender == owner, "not owner of token");
            // 授权给地址0
            _approve(owner, address(0), tokenId);
            // 数量+1
            _balances[owner] -= 1;
            // 删除所有者
            delete _owners[tokenId];
            // 发布转账
            emit Transfer(owner, address(0), tokenId);

        }


        // _checkOnERC721Received：函数，用于在 to 为合约的时候调用IERC721Receiver-onERC721Received, 以防 tokenId 被不小心转入黑洞。

        function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
            if (to.code.length > 0) { /*判断是否为合约地址*/
                try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                    if (retval != IERC721Receiver.onERC721Received.selector) {
                        revert ERC721InvalidReceiver(to);
                    }
                } catch (bytes memory reason) {
                    if (reason.length == 0) {
                        revert ERC721InvalidReceiver(to);
                    } else {
                        /// @solidity memory-safe-assembly
                        assembly {
                            revert(add(32, reason), mload(reason))
                        }
                    }
                }
            }
        }


        // 实现IERC721Metadata的tokenURI函数，查询metadata。
        function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
            require(_owners[tokenId] != address(0), "Token Not Exist");

            string memory baseURI = _baseURI();
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
        }

      /**
        * 计算{tokenURI}的BaseURI，tokenURI就是把baseURI和tokenId拼接在一起，需要开发重写。
        * BAYC的baseURI为ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/ 
        */
        function _baseURI() internal view virtual returns (string memory) {
            return "";
        }

}


// ERC165与ERC721详解
// 上面说到,为了防止NFT被转到一个没有能力操作NFT的合约中去,目标必须正确实现ERC721TokenReceiver接口：

/*
interface ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) external returns(bytes4);
}
*/
/*
拓展到编程语言的世界中去，无论是Java的interface，还是Rust的Trait(当然solidity中和trait更像的是library)，只要是和接口沾边的，都在透露着一种这样的意味：接口是某些行为的集合(在solidity中更甚，接口完全等价于函数选择器的集合)，某个类型只要实现了某个接口，就表明该类型拥有这样的一种功能。因此，只要某个contract类型实现了上述的ERC721TokenReceiver接口(更具体而言就是实现了onERC721Received这个函数),该contract类型就对外表明了自己拥有管理NFT的能力。当然操作NFT的逻辑被实现在该合约其他的函数中。 ERC721标准在执行safeTransferFrom的时候会检查目标合约是否实现了onERC721Received函数,这是一种利用ERC165思想进行的操作。

那究竟什么是ERC165呢?

ERC165是一种对外表明自己实现了哪些接口的技术标准。就像上面所说的，实现了一个接口就表明合约拥有种特殊能力。有一些合约与其他合约交互时，期望目标合约拥有某些功能，那么合约之间就能够通过ERC165标准对对方进行查询以检查对方是否拥有相应的能力。
以ERC721合约为例，当外部对某个合约进行检查其是否是ERC721时，怎么做？ 。按照这个说法，检查步骤应该是首先检查该合约是否实现了ERC165, 再检查该合约实现的其他特定接口。此时该特定接口是IERC721. IERC721的是ERC721的基本接口(为什么说基本，是因为还有其他的诸如ERC721Metadata ERC721Enumerable 这样的拓展)：

*/



/// 注意这个**0x80ac58cd**
///  **⚠⚠⚠ Note: the ERC-165 identifier for this interface is 0x80ac58cd. ⚠⚠⚠**
// interface ERC721 /* is ERC165 */ {
//     event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

//     event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

//     event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

//     function balanceOf(address _owner) external view returns (uint256);

//     function ownerOf(uint256 _tokenId) external view returns (address);

//     function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;

//     function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

//     function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

//     function approve(address _approved, uint256 _tokenId) external payable;

//     function setApprovalForAll(address _operator, bool _approved) external;

//     function getApproved(uint256 _tokenId) external view returns (address);

//     function isApprovedForAll(address _owner, address _operator) external view returns (bool);
// }


// 0x80ac58cd= bytes4(keccak256(ERC721.Transfer.selector) ^ keccak256(ERC721.Approval.selector) ^ ··· ^keccak256(ERC721.isApprovedForAll.selector))，这是ERC165规定的计算方式。

// 那么，类似的，能够计算出ERC165本身的接口(它的接口里只有一个 function supportsInterface(bytes4 interfaceID) external view returns (bool); 函数，对其进行bytes4(keccak256(supportsInterface.selector)) 得到0x01ffc9a7。此外，ERC721还定义了一些拓展接口，比如ERC721Metadata ，长这样：

///  Note: the ERC-165 identifier for this interface is 0x5b5e139f.
// interface ERC721Metadata /* is ERC721 */ {
//     function name() external view returns (string _name);
//     function symbol() external view returns (string _symbol);
//     function tokenURI(uint256 _tokenId) external view returns (string); // 这个很重要，前端展示的小图片的链接都是这个函数返回的
// }

// 这个0x5b5e139f 的计算就是:

// IERC721Metadata.name.selector ^ IERC721Metadata.symbol.selector ^ IERC721Metadata.tokenURI.selector

// solmate实现的ERC721.sol是怎么完成这些ERC165要求的特性的呢？

/*
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
}
*/

/*
没错就这么简单。当外界按照link1 的步骤去做检查的时候，如果外界想检查这个合约是否实现了165,好说，就是supportsInterface函数在入参是0x01ffc9a7时必须返回true，在入参是0xffffffff时，返回值必须是false。上述实现完美达成要求。

当外界想检查这个合约是否是ERC721的时候，好说，入参是0x80ac58cd 的时候表明外界想做这个检查。返回true。

当外界想检查这个合约是否实现ERC721的拓展ERC721Metadata接口时，入参是0x5b5e139f。好说，返回了true。

并且由于该函数是virtual的。因此该合约的使用者可以继承该合约，然后继续实现ERC721Enumerable 接口。实现完里面的什么totalSupply 啊之类的函数之后，把继承的supportsInterface重实现为

*/
/*
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f || // ERC165 Interface ID for ERC721Metadata
            interfaceId == 0x780e9d63;   // ERC165 Interface ID for ERC721Enumerable
}
*/

// 优雅，简洁，可拓展性拉满。

// ERC721标准、接口及其实现，并在合约代码进行了中文注释。并且我们利用ERC721做了一个免费铸造的WTF APE NFT，元数据直接调用于BAYC。ERC721标准仍在不断发展中，目前比较流行的版本为ERC721Enumerable（提高NFT可访问性）和ERC721A（节约铸造gas）。

