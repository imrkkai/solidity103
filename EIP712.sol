// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// EIP712

// EIP191签名标准（peronal sign）, 它可以给一段消息签名。
// 但是它过于简单，当签名数据比较复杂时，用户 只能看到一串十六进制字符串（数据的哈希）,
// 无法核实签名内容是否与预期相符

// EIP712类型化数据签名是一个更高级、更安全的签名方法，当支持EIP712的Dapp请求签名时，钱包会展示签名消息的原始数据，
// 用户可以验证数据符合预期之后签名。


// EIP712使用方法
// EIP712的应用一般包含链下签名（前端或脚本）和链上验证（合约）两部分，
// 下面我们用一个简单的例子EIP712Storage来介绍EIP712的使用方法，
// EIP712Storage合约有一个状态变量number，需要验证EIP712签名才可以更改。

// 链下签名
// 1.EIP712签名必须包含一个EIP712Domain部分，它包含了合约的name，version（一般约定为1）、chainId
// 和VerifyingContract(验证签名的合约地址)。
/*
EIP712Domain: [
    { name: "name", type: "string" },
    { name: "version", type: "string" },
    { name: "chainId", type: "uint256" },
    { name: "verifyingContract", type: "address" },
]
*/

// 这些信息会在用户签名时显示，并确保只有特定链的特定合约才能验证签名，你需要再脚本中传入响应的参数.
/*
const domain = {
    name: "EIP712Storage",
    version: "1",
    chainId: "1",
    verifyingContract: "0xf8e81D47203A594245E36C48e151709F0C19fBe8",
};

*/

// 2. 需要根据使用场景自定义一个签名的数据类型，他要与合约匹配，在EIP712Storage例子中，
// 我们定义了一个Storage类型，它有两个成员：
// address类型spender，指定了可以修改变量的调用者; uint256类型的number，指定了变量修改后的值。
/*
const types = {
    Storage: [
        { name: "spender", type: "address" },
        { name: "number", type: "uint256" },
    ],
};

*/

// 3. 创建一个message变量，传入要被签名的类型化数据
/*
const message = {
    spender: "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    number: "100",
};

*/

// 4.调用钱包对象的signTypedData()方法，传入前面步骤中的domain、types和message变量进行签名
// (这里使用ethersjs v6)
/*
// 获得provider
const provider = new ethers.BrowserProvider(window.ethereum)
// 获得signer后调用signTypedData方法进行eip712签名
const signature = await signer.signTypedData(domain, types, message);
console.log("Signature:", signature);

*/


// 链上验证
// 加下来就是EIP712Storage合约部分，它需要验证签名，如果通过，则修改number状态变量。它有5个状态变量
// - EIP712Domain_TYPEHASH: EIP712Domain的类型哈希，为常量。
// - STORAGE_TYPEHASH: Storage的类型哈希，为常量
// - DOMAIN_SEPARATOR: 这是混合在签名中的每个域（Dapp）的唯一值，
//   由EIP712DOMAIN_TYPEHASH以及EIP712DOMAIN(name, version, chainId, verifyingContract)组成
//   在constructor（）中初始化
// - number: 合约中存储的状态变量，可以被permiStore()方法修改
// - owner: 合约所有者，在constructor（）中初始化，在permiStore（）方法中验证签名的有效性。


// EIP712Storage合约有3个函数
// 1.构造函数：初始化DOMAIN_SEPARATOR和Owner
// 2. retrieve(): 读取number的值
// 3. permitStore: 验证EIP712签名，并修改number的值，首先，它先将签名拆解为r，s，v。然后用DOMAIN_SEPARATOR, 
// STORAGE_TYPEHASH，调用者地址，和输入的_num参数拼出签名的消息文本digest。最后利用ECDSA的recover方法恢复出签名者地址
// 如果签名有效，则更新number的值

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract EIP712Storage {
    using ECDSA for bytes32;
    bytes32 private constant EIP712DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant STORAGE_TYPEHASH = keccak256("Storage(address spender,uint256 number)");
    bytes32 private DOMAIN_SEPARATOR;
    uint256 number;
    address owner;

    constructor(){
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH, // type hash
            keccak256(bytes("EIP712Storage")), // name
            keccak256(bytes("1")), // version
            block.chainid, // chain id
            address(this) // contract address
        ));
        owner = msg.sender;
    }


    function permitStore(uint256 _num, bytes memory _signature) public {
        // 检查签名长度，65是标准r,s,v签名的长度
        require(_signature.length == 65, "invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        // 目前只能用assembly (内联汇编)来从签名中获得r,s,v的值
        assembly {
            /*
            前32 bytes存储签名的长度 (动态数组存储规则)
            add(sig, 32) = sig的指针 + 32
            等效为略过signature的前32 bytes
            mload(p) 载入从内存地址p起始的接下来32 bytes数据
            */
            // 读取长度数据后的32 bytes
            r := mload(add(_signature, 0x20))
            // 读取之后的32 bytes
            s := mload(add(_signature, 0x40))
            // 读取最后一个byte
            v := byte(0, mload(add(_signature, 0x60)))
        }

        // 获取签名消息hash
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(STORAGE_TYPEHASH, msg.sender, _num))
        )); 
        
        address signer = digest.recover(v, r, s); // 恢复签名者
        require(signer == owner, "EIP712Storage: Invalid signature"); // 检查签名

        // 修改状态变量
        number = _num;
    }

     /**
     * @dev Return value 
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256){
        return number;
    }    


}


// 演示
// 1. 在remix部署EIP712Storage合约
// 2. 运行eip712storage.html
//    根据浏览器的内容安全策略（Content Security Policy）的要求，MetaMask 不能通过打开的本地文件（file:// 协议）与 DApp 通信。 可以使用 Node 静态文件服务器 http-server 启动本地服务，在包含 eip712storage.html 文件的目录下执行以下命令：
/*
npm install -g http-server
http-server
*/

// 在浏览器中打开 http://127.0.0.1:8080 就可以访问了。 
//然后将 Contract Address 改为部署的 EIP712Storage 合约地址，
// 然后依次点击 Connect Metamask 和 Sign Permit 按钮签名。签名要使用部署合约的钱包，
// 比如 Remix 测试钱包：
/*
public_key: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
private_key: 503f38a9c967ed597e47fe25643985f032b072db8075426a92110f82df48dfcb
*/

// 3. 调用合约的 permitStore() 方法，输入相应的 _num 和签名，修改 number 的值。

// 4. 调用合约的 retrieve() 方法，看到 number 的值已经改变。


// 介绍了 EIP712 类型化数据签名，一种更先进、安全的签名标准。在请求签名时，钱包会展示签名消息的原始数据，用户可以在验证数据后签名。该标准应用广泛，在 Metamask，Uniswap 代币对，DAI 稳定币等场景均有使用，希望大家好好掌握。