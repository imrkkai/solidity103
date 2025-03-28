// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// ERC20Permit
// ERC20代币的一个扩展，支持使用签名进行授权，改善用户体验，它在EIP-2612中被提出，已奶如以太坊标准，并被USDC，ARB等代币使用。

// ERC20是以太坊最流行的代币标准，主要原因是approve和transferFrom两个函数搭配使用，使得代币不仅可以在外部拥有账号EOA之间转移，
// 还可以被其他合约使用

// 但是，ERC20的approve函数限制了只有代币所有者才能调用，这意味着所有ERC20代币的初始操作必须由EOA执行。
// 举个例子：
// 用户A在去中心化交易所使用USDT交换ETH，必须完成两个交易：
// - 1. 第一步用户A调用approve将USDT授权给合约
// - 2. 用户A调用合约进行交换。
// 非常麻烦，并且用户必须持有ETH用于支付交易的gas。

// ERC20Permit
// EIP-2612提出了ERC20Permit，扩展了ERC20标准，添加了一个permit函数，允许用户通过EIP-712签名修改授权，而不是通过msg.sender.
// 这有两点好处：
// 1.授权这步仅需用户在链下签名，减少一笔交易
// 2.签名后，用户可以委托第三方进行后续甲乙，不需要持有ETH。
// 用户A可以将签名发给拥有gas的第三方B，委托B来执行后续交易。



// ERC20Permit合约
// 写一个简单的ERC20Permit合约，它实现了IERC20Permit定义的所有接口。合约包含2个状态变量
// _nonces: address => uint 的映射，记录了所有用户当前的nonce值
// _PERMIT_TYPEHASH: 常量，记录了permi（）函数的类型哈希

// 包含5个函数
// 构造函数：初始化代币的name和symbol
// permit(): ERC20Permit最核心的函数，实现了IERC20Permit的permit（）。
// 它首先检查签名是否过期，然后用_PERMIT_TYPEHASH，owner,spender,value, nonce, deadline 还原签名消息
// 并验证签名是否有效，如果签名有效，则调用ERC20的_approve()函数进行授权操作

// nonces(): 实现了IERC20Permit的nonces函数
// DOMAIN_SEPARATOR(): 实现了IERC20Permit的DOMAIN_SEPARATOR()函数
// _useNonce(): 消费nonce的函数，返回用户当前的nonce，并增加1。


import "IERC20Permit.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract ERC20Permit is ERC20, IERC20Permit, EIP712{

    mapping (address => uint) private _nonces;

    bytes32 private constant _PERMIT_TYPEHASH = 
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");


    /**
     * @dev 初始化 EIP712 的 name 以及 ERC20 的 name 和 symbol
     */
    constructor(string memory name, string memory symbol) 
        EIP712(name, "1") 
        ERC20(name, symbol) {

        }


    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        // 检查 deadline
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        // 拼接hash
        bytes32 structHash = keccak256(abi.encode(
            _PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            _useNonce(owner),
            deadline
        ));

        bytes32 hash = _hashTypedDataV4(structHash);

        // 从签名和消息计算signer，并验证签名
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        // 授权
        _approve(owner, spender, value);


    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view virtual override returns(uint256) {
        return _nonces[owner];
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "消费nonce": 返回 `owner` 当前的 `nonce`，并增加 1。
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        current = _nonces[owner];
        _nonces[owner] += 1;
    }


    function mint(uint amount) external {
        _mint(msg.sender, amount);
    }

    function burn(uint amount) external {
        _burn(msg.sender, amount);
    }
}

// 演示
// 1. 部署ERC20Permit合约，将name和symbol都设置为TEST
// 2. 运行signERC20Permit.html，将Contract Address 改为部署的ERC20Permit合约地址
// 其他信息如下:
/*
owner: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4    
spender: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
value: 100
deadline: 115792089237316195423570985008687907853269984665640564039457584007913129639935
private_key: 503f38a9c967ed597e47fe25643985f032b072db8075426a92110f82df48dfcb

*/

// 然后依次点击Connect Metamask和Sign Permit按钮签名
// 并获取r,s,v,用于合约校验。
// 签名要使用部署合约的签名，比如remix测试钱包

// 3.调用合约的permit（）方法，输入相应的参数，进行授权

// 4. 调用合约的allowance()方法，输入相应的owner和spender 可以查看授权成功

// 安全事项
// ERC20Permit利用链下签名进行授权给用户带来了遍历，同时带来了风险。
// 一些黑客会利用这一特性进行钓鱼攻击，骗取用户签名并盗取资产。
// 2023年4月的一起针对USDC的签名钓鱼攻击让一位用户损失了228w u的资产。

// 签名时，一定要谨慎的阅读签名内容！
// 同时，一些合约在集成permit时，也会带来Dos的风险，因为
// permit在执行时会用掉当前的nonce值，如果合约的函数包含permit操作。
// 则攻击者可以通过抢跑执行permit从而使得目标交易因为nonce被占用而回滚

// 最后，介绍了ERC20Permit，一个ERC20代币标准的扩展，支持用户使用链下签名进行授权操作，改善用户体验
// 被很多项目采用。但同时，它也带来了更大的风险，一个签名就能将你的资产卷走，大家在签名时一定要更加谨慎。


