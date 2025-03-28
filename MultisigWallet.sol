// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 多签钱包
// 多签钱包是一种电子钱包, 特点是交易被多个私钥持有者（多签人）授权后才能执行：
// 例如钱包由3个多签人管理，每笔交易至少需要2个人签名授权。
// 多签钱包可以防止单点故障（私钥丢失，单人作恶）, 更加去中心化，更加安全，被很多DAO采用。


// Gnosis Safe多签钱包是以太坊最流行的多签钱包，管理仅400亿美元资产，
// 合约经过审计和实战测试，支持多链（以太坊、BSC、Polygon等）, 并提供丰富的DAPP支持，



// 多签钱包合约
// 在以太坊的多签钱包其实是智能合约，属于合约钱包：我们将写一个简单的多签钱包MultisigWallet合约，其逻辑非常简单:
// 1. 设置多签人和门槛（链上）: 部署多签合约时，需要初始化多签人列表和执行门槛（至少n个多签人签名授权后，交易才能执行）
//    Gnosis Safe多签钱包支持增加/删除多签人以及改变执行门槛。但在我们的版本中不考虑这些功能

// 2. 创建交易（链下）: 一笔待授权的交易包含以下内容：
// to: 目标合约
// value: 交易发送的以太坊数量
// data: calldata，包含调佣函数的选择器和参数
// nonce: 初始为0，随着多签合约每笔成功执行的交易递增的值，可以防止签名重复攻击
// chainid: 链ID，防止不同链的签名重放攻击

// 3.收集多签签名（链下）: 将上一步的交易ABI编码并计算哈希,得到交易哈希，然后
// 让多签人签名，并拼接到一起得到打包签名

// 4. 执行交易（链上），调用多签合约的执行函数, 验证签名并执行交易.

// 事件：
// MultisigWallet合约有2个事件，ExecutionSuccess和ExecutionFailure, 分别在交易成功和失败时释放，参数为交易哈希。
// event ExecutionSuccess(bytes32 txHash)
// event ExceutionFailure(bytes32 txHash)

// 状态变量
// MutisigWallet 合约有5个状态变量：
// 1. owners : 多签持有人数组
// 2. isOwner: address => bool的映射，记录一个地址是否为多签持有人
// 3. ownerCount: 多签持有人数量
// 4. threshold: 多签执行门槛，交易至少有n个多签人签名才能被执行。
// 5. nonce: 初始化为0，随着多签合约每笔成功执行的交易递增的值，可以防止签名重放攻击

// 函数
// MutilsigWallet合约有6个函数：
// 1. 构造函数：调用_setupOwners(), 初始化和多签持有人、执行门槛相关的变量
// 2. _setupOwners(): 在部署合约时被构造函数调用，初始化owners，isOwner,ownerCount,threshold状态变量
//   传入的参数中，执行门槛需大于等于1且小于多签人数，多签地址不能为0地址且不能重复

// 3.executeTransaction(): 收集足够的多签签名后，验证签名并执行交易。
// 传入的参数为目标地址to，发送以太坊数量value, 数据data，以及打包签名signatures.
// 打包签名就是将收集的多签人对交易哈希的签名，按多签持有人地址从小到大顺序，打包到一个bytess数据中
// 这一步调用encodeTransactionData（）编码交易，调用了checkSignature()校验签名是否有效, 数量是否达到执行门槛.

// 4. checkSignatures(): 检查签名和交易数据的哈希是否对应，数量是否达到门槛，
// 若否，交易revert。单个签名长度为65个字节，因此打包签名的长度要大于或等于threshold * 65.
// 调用了signatureSplit()分离出当个签名，这个函数的大致思路：
// -- 用ecdsa获取签名地址
// -- 利用currentOwner > lastOwner 确定签名来自不同多签(多签地址递增）
// -- 利用isOwner[currentOwner] 确定签名者为多签持有人

// 5. signatureSplit(): 将单个签名从打包的签名分离出来，参数分别为打包签名signatures和要读取的签名位置pos
// 利用了内联汇编，将签名r，s,v三个值分离出来.

// 6. encodeTransactionData: 将交易数据打包并计算哈希，利用abi.encode()和keccak256()函数。这个函数
// 可以计算出一个交易的哈希，然后在链下让多签人签名并收集，在调用executeTransaction（）函数执行。


// 代码
contract MultisigWallet {

    event ExecutionSuccess(bytes32 txHash);    // 交易成功事件
    event ExecutionFailure(bytes32 txHash);    // 交易失败事件

    address[] public owners;       // 多签持有人列表
    mapping(address => bool) public isOwner;         // 是否为多签持有人
    uint ownerCount;               // 多签人数
    uint threshold;                // 执行门槛，交易至少有n个多签人签名才能被执行。
    uint public nonce;                    // 初始化为0，随着多签合约每笔成功执行的交易递增的值，可以防止签名重放攻击
    

    // 构造函数，初始化owners, isOwner, ownerCount, threshold 
    constructor(
        address[] memory _owners,
        uint256 _threshold
    ) {
        _setupOwners(_owners, _threshold);
    }

    receive() external payable {}

    /// @dev 初始化owners, isOwner, ownerCount,threshold 
    /// @param _owners: 多签持有人数组
    /// @param _threshold: 多签执行门槛，至少有几个多签人签署了交易
    function _setupOwners(address[] memory _owners, uint256 _threshold) internal {
        // threshold 没有被初始化过
        require(threshold == 0, "err5000");
        // 多签执行门槛 小于或等于多签人数
        require(_threshold <= _owners.length, "err5001");
        // 多签执行门槛至少为1
        require(_threshold >= 1, "err5002");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            // 多签人不能为0地址，本合约地址，不能重复
            require(owner != address(0) && owner != address(this) 
            && !isOwner[owner], "err5003");
            owners.push(owner);
            isOwner[owner] = true;
        }

        ownerCount = _owners.length;
        threshold = _threshold;
    }


    function executeTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bytes memory signatures
    ) public payable virtual returns (bool success) {
        // 计算交易哈希
        bytes32 txHash = encodeTransactionData(to, value, data, nonce, block.chainid);
        nonce ++;

        // 校验签名
        checkSignatures(txHash, signatures);

        // 利用call执行交易，并获取结果
        (success, ) = to.call{value: value}(data);

        require(success, "err5008");
        
        if(success) {
            emit ExecutionSuccess(txHash);
        } else {
            emit ExecutionFailure(txHash);
        }

    }

    /**
    * @dev 检查签名和交易数据是否对应。如果是无效签名，交易会revert
    * @param dataHash 交易数据哈希
    * @param signatures 几个多签签名打包在一起
    */
    function checkSignatures(
        bytes32 dataHash,
        bytes memory signatures
    ) public view {
        // 判断多签执行门槛
        uint256 _threshold = threshold;
        require(_threshold > 0, "err5005");

        // 检查签名长度满足门槛设置
        require(signatures.length >= _threshold * 65, "err5006");

        // 通过循环，检查收集到的签名是否都有效
        // 大致思路：
        // 1.用ecdsa先验证签名是否有效
        // 2.利用currentOwner > lastOwner确定签名来自不同的多签（多签地址递增）
        // 3.利用isOwner[currentOwner]确定签名者为多签持有人

        address lastOwner = address(0);
        address currentOwner;
        bytes32 r;
        bytes32 s;
        uint8   v;
        
        for (uint256 i; i < _threshold; i++) 
        {
            (r,s,v) = signatureSplit(signatures, i);
            currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), v, r, s);
            require(currentOwner > lastOwner && isOwner[currentOwner], "err5007");
            lastOwner = currentOwner;
        }

    }



    /// 将单个签名从打包的签名分离出来
    /// @param signatures 打包签名
    /// @param pos 要读取的多签index
    function signatureSplit(bytes memory signatures, uint256 pos) 
    internal pure returns(bytes32 r, bytes32 s, uint8 v){
        // 签名的格式：{bytes32 r}{bytes32 s}{uint8 v}

        assembly {
            //动态数组在内存中前32字节存储长度，实际数据从0x20开始 
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20))) // 需要加上数组长度
            s := mload(add(signatures, add(signaturePos, 0x40))) 
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }


    }


    ///@dev 编码交易数据
    ///@param to 目标合约地址
    ///@param value msg.value 支付的以太坊
    ///@param data calldata
    ///@param _nonce 交易的nonce
    ///@param chainid 链ID
    ///@return 交易哈希bytes
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes memory data,
        uint256 _nonce,
        uint256 chainid
    ) public pure returns(bytes32) {
        bytes32 safeTxHash = 
        keccak256(
            abi.encode(
                to,
                value,
                keccak256(data),
                _nonce,
                chainid
            )
        );
        return safeTxHash;
    }


}


// 演示
// 1.部署多签合约, 2个多签地址，交易执行门槛设置为2
// 多签地址1: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// 多签地址2: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2

// 2.转账1ETH到多签合约地址

// 3. 调用encodeTransactionData()，编码并计算多签地址1转账1ETH的哈希交易

/*
参数
to: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
value: 1000000000000000000
data: 0x
_nonce: 0
chainid: 1

结果
交易哈希： 0xb43ad6901230f2c59c3f7ef027c9a372f199661c61beeec49ef5a774231fc39b
*/

// 4. 利用Remix中ACCOUNT旁边的笔记图标的按钮进行签名，内容输入上面的交易哈希，获取签名，两个钱包都要

/*
多签地址1的签名: 0xa3f3e4375f54ad0a8070f5abd64e974b9b84306ac0dd5f59834efc60aede7c84454813efd16923f1a8c320c05f185bd90145fd7a7b741a8d13d4e65a4722687e1b

多签地址2的签名: 0x6b228b6033c097e220575f826560226a5855112af667e984aceca50b776f4c885e983f1f2155c294c86a905977853c6b1bb630c488502abcc838f9a225c813811c

将两个签名拼接到一起，得到打包签名:  0xa3f3e4375f54ad0a8070f5abd64e974b9b84306ac0dd5f59834efc60aede7c84454813efd16923f1a8c320c05f185bd90145fd7a7b741a8d13d4e65a4722687e1b6b228b6033c097e220575f826560226a5855112af667e984aceca50b776f4c885e983f1f2155c294c86a905977853c6b1bb630c488502abcc838f9a225c813811c
*/

// 5. 调用executeTransaction()函数执行交易，将第三步中的交易参数和打包签名作为参数传入。可以看到交易执行成功，ETH被出多签


// 总结 
// 我们介绍了多签钱包，并写一个简单的多签钱包合约，仅用不到150行代码
