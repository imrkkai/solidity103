// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "ERC721.sol";
// 默克尔树
// Merkle Tree，也叫默克尔树或哈希树，是区块链的底层加密技术，被比特币和以太坊区块链广泛采用。
// Merkle Tree是一种自下而上构建的加密树，每个叶子是对应数据的哈希，而每个非叶子为它的2个子节点的哈希。
// https://www.wtf.academy/zh/course/solidity103/MerkleTree
// 默克尔树允许对大型数据结构的内容进行有效和安全的验证(Merkle Proof)。
// 对于有N个叶子节点的Merkle Tree，在已知root根值的情况下，验证某个数据是否有效（属于MerkleTree叶子节点）
// 只需要ceil(log2N)个数据（也叫proof）, 非常高效。
// 如果数据有误，或者给的proof错误，则无法还原出root根值。
// 下面的例子中。叶子L1的Merkle proof为Hash 0-1和Hash 1: 知道者两个值，就能验证L1的值是不是在
// MerkleTree的叶子中。为什么呢，因为通过叶子L1我就就可以算出Hash 0-0, 而我们又知道了Hash 0-1
// 那么Hash 0-0 和 Hash 0-1就可以联合算出Hash 0, 然后我们又知道Hash1 Hash0和Hash1就可以联合算出Top Hash，也就是root节点的hash。


// 生成merkle Tree
// 可以使用merkeltree.js来生成Merkle tree。
// 或通过网页https://lab.miguelmota.com/merkletreejs/example/生成

// 这里通过网页来生成4个地址作为叶子节点的Merkle Tree。叶子节点输入：
/*
[
  "0x4b20993bc481177ec7e8f571cecae8a9e22c02db",
  "0x5b38da6a701c568545dcfcb03fcb875f56beddc4",
  "0x78731d3ca6b7e34ac0f824c42a7cc18a495cabab",
  "0xab8483f64d9c6d1ecf9b849ae677dd3315835cb2"
]
*/

// 在菜单选择Keccak-256, hashLeaves和sortPairs选项，然后点击Compute。
// MerkleTree 就生成好了。Merkle Tree展开为:
/*
└─ 72066fb8c1630aa899ff153c790564a027aa1d8dafb1ea26e35eabb5f8b1c684
   ├─ d01f7f1130cd76674aa5de088ae3f127d431228785ba80cfd38ba829672e0988
   │  ├─ 04a10bfd00977f54cc3450c9b25c9b3a502a089eba0097ba35fc33c4ea5fcb54
   │  └─ 5931b4ed56ace4c46b68524cb5bcbf4195f1bbaacbe5228fbd090546c88dd229
   └─ 15741c8b25909041ecad0ee5d2f28d0e58d97827f3ec0f5c6b9ebdbb9a1c46ef
      ├─ 999bf57501565dbd2fdcea36efa2b9aef8340a8901e3459f4a4c926275d36cdb
      └─ dfbe3e504ac4e35541bebad4d0e7574668e16fefa26cd4172f93e18b59ce9486
*/


// Merkle Proof 验证
// 通过网站，可以得到地址0的proof如下：
/*
    5931b4ed56ace4c46b68524cb5bcbf4195f1bbaacbe5228fbd090546c88dd229
    15741c8b25909041ecad0ee5d2f28d0e58d97827f3ec0f5c6b9ebdbb9a1c46ef

*/

// 利用Merkle Proof来验证：

// MerkleProof库有三个函数：
// -  verify()函数：利用proof数来验证leaf是否属于根为root的Merkle Tree中，如果是，则返回true。它调用了processProof()函数。
// -  processProof()函数：利用proof和leaf依次计算出Merkle Tree的root。它调用了_hashPair()函数。
// -  _hashPair()函数：用keccak256()函数计算非根节点对应的两个子节点的哈希（排序后）。

// 我们将地址0的Hash，root和对应的proof输入到verify()函数，将返回true。
// 因为地址0的Hash在根为root的Merkle Tree中，且proof正确。
// 如果改变了其中任意一个值，都将返回false。



library MerkleProof {
    /**
     * @dev 当通过`proof`和`leaf`重建出的`root`与给定的`root`相等时，返回`true`，数据有效。
     * 在重建时，叶子节点对和元素对都是排序过的。
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns 通过Merkle树用`leaf`和`proof`计算出`root`. 
     * 当重建出的`root`和给定的`root`相同时，`proof`才是有效的。
     * 在重建时，叶子节点对和元素对都是排序过的。
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

}



// 利用Merkle Tree发放NFT白名单

// 一份拥有800个地址的白名单，更新一次所需的gas fee很容易超过1个ETH。而由于Merkle Tree验证时，leaf和proof可以存在后端，链上仅需存储一个root的值，非常节省gas，项目方经常用它来发放白名单。很多ERC721标准的NFT和ERC20标准代币的白名单/空投都是利用Merkle Tree发出的，比如optimism的空投。

//如何利用MerkleTree合约来发放NFT白名单：

contract  MerkleTree is ERC721{
    bytes32 immutable public root; // Merkle树的根
    mapping (address => bool) public mintedAddress; // 记录已经mint的地址

    constructor(string memory name, string memory symbol, bytes32 merkleroot) 
    ERC721(name, symbol) {
        root = merkleroot;
    }

    // 利用Merkle树验证地址并完成mint
    function mint(address account, uint256 tokenId, bytes32[] calldata proof)external  {
        require(_verify(_leaf(account), proof), "Invalid merkle proof"); // Merkle检验通过
        mintedAddress[account] = true;
        _mint(account, tokenId); // mint
    }

    // 计算Merkle树叶子的哈希值
    function _leaf(address account) internal  pure returns(bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    // Merkle树验证，调用MerkleProof库的verify()函数
    function _verify(bytes32 leaf, bytes32[] memory proof) 
    internal view returns (bool){
        return MerkleProof.verify(proof, root, leaf);
    }


}

//MerkleTree合约继承了ERC721标准，并利用了MerkleProof库。


// 状态变量
// 合约中共有两个状态变量：
// - root 存储了merkle Tree的根，部署合约时赋值
// - mintedAddress 是一个mapping，记录了已经mint过的地址，某个地址mint成功后，进行赋值

// 函数
// 合约中共有4个函数：
// - 构造函数：初始化NFT的名称和代号，还有Merkle Tree的root。
// - mint()函数：利用白名单铸造NFT。参数为白名单地址account，铸造的tokenId，和proof。
//   首先验证地址account是否在白名单中，然后验证该地址是否还未铸造，
//   验证通过则先把该地址记录到mintedAddress中防止重入攻击，然后把序号为tokenId的NFT铸造给该地址。
//   此过程中调用了_leaf()和_verify()函数。

// - _leaf()函数：计算了Merkle Tree的叶子地址的哈希。
// - _verify()函数：调用了MerkleProof库的verify()函数，进行Merkle Tree验证。


// - 验证
// 利用之前4个地址作为白名单生成merkle tree。
// name: Merkle Tree Proof
// symbol: MTP
// merkleroot: 0x72066fb8c1630aa899ff153c790564a027aa1d8dafb1ea26e35eabb5f8b1c684


// mint 
// 给地址0铸造NFT，三个参数分别为：
/*
account = 0x4b20993bc481177ec7e8f571cecae8a9e22c02db
tokenId = 0
proof = [
    "0x5931b4ed56ace4c46b68524cb5bcbf4195f1bbaacbe5228fbd090546c88dd229",
    "0x15741c8b25909041ecad0ee5d2f28d0e58d97827f3ec0f5c6b9ebdbb9a1c46ef" 
]
*/


// 我们可以用ownerOf函数验证tokenId为0的NFT 已经铸造给了地址0，合约运行成功！

// 此时，若再次调用mint函数，虽然该地址能够通过Merkle Proof验证，但由于地址已经记录在mintedAddress中，因此该交易会由于"Already minted!"被中止。


// 在实际使用中，复杂的Merkle Tree可以利用javascript库merkletreejs来生成和管理，链上只需要存储一个根值，非常节省gas。很多项目方都选择利用Merkle Tree来发放白名单。