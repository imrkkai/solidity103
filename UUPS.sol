// SPDX-License-Identifier: MIT
pragma solidity > 0.8.4 <0.9.0;

// 通用可升级代理
// 通用可升级代理是解决代理合约中选择器冲突的另一个解决方案
// Universal upgradeable proxy standard
// 参考于openZeppelin的UUPSUpgradeable

// UUPS
// 选择器冲突（selector clash），即合约存在两个选择器相同的函数，可能会造成严重的后果。
// 作为透明代理的替代方案，UUPS也能够解决这一问题

// UUPS将升级函数防止逻辑合约中，这样一来，如果有其他函数与升级函数存在选择器冲突，编译时就会报错。

// 下表概括了普通可升级合约、透明代理和UUPS的不同:
// 标准         升级函数位置        是否存在选择器冲突          缺点
// 可升级代理   Proxy合约           是                         选择器冲突
// 透明代理     Proxy合约           否                         费gas 
// UUPS        Logic合约            否                        更复杂


// UUPS合约
// 如果用户A通过合约B（代理合约）去delegatecall合约C（逻辑合约）,上下文仍是合约B，
// msg.sender仍是用户A而不是合约B。因此，UUPS合约可以将升级函数防止逻辑合约中，并检查调用者是否为管理员

// UUPS的代理合约
// UUPS的代理合约看起来像是个不可升级的代理合约，非常简单，因为升级函数被放到了逻辑合约中，它包含3个变量
// - implementation：逻辑合约地址
// - admin: admin地址
// - words: 字符串，可以通过逻辑合约的函数改变
// 它包含2个函数：
// 构造函数: 初始化admin和逻辑合约地址
// fallback(): 回调函数，将调用委托给逻辑合约


contract UUPSProxy {
    address public implementation; // 逻辑合约
    address public admin; // admin地址
    string public words; // 字符串，可以通过逻辑合约的函数改变

    // 构造函数、初始化admin和逻辑合约地址
    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    receive() external payable { }

    // fallback函数，将调用委托给逻辑合约
    fallback() external payable {
        (bool success, bytes memory data) = implementation.delegatecall(msg.data);
    }

}


// UUPS的逻辑合约
// UUPS的逻辑合约与透明代理的逻辑合约的不同是多了个升级函数
// UUPS逻辑合约包含3个状态变量，与代理合约保持一致，防止插槽冲突，它包含2个函数:
// - upgrade(): 升级函数，将改变逻辑合约地址implementation, 只能由admin调用
// - foo(): 旧UUPS逻辑合约会将words的值改为“old”，新的会改为“new”


contract UUPSLogic1 {
    // 状态变量与proxy合约一致，防止插槽冲突
    address public implementation; // 逻辑合约
    address public admin; // admin地址
    string public words; // 字符串，可以通过逻辑合约的函数改变

    // 改变proxy中的状态变量，selector：0xc2985578
    function foo() public {
        words = "old";
    }

    // 升级函数，改变逻辑合约地址，只能由admin调用，选择器：0x0900f010
    // UUPS中，逻辑合约中必须包含升级函数，不然就不能再升级了
    function upgrade(address newImplementation) external  {
        require(msg.sender == admin);
        implementation = newImplementation;
    }
}


contract UUPSLogic2 {
    // 状态变量与proxy合约一致，防止插槽冲突
    address public implementation; // 逻辑合约
    address public admin; // admin地址
    string public words; // 字符串，可以通过逻辑合约的函数改变

    // 改变proxy中的状态变量，selector：0xc2985578
    function foo() public {
        words = "new";
    }

    // 升级函数，改变逻辑合约地址，只能由admin调用，选择器：0x0900f010
    // UUPS中，逻辑合约中必须包含升级函数，不然就不能再升级了
    function upgrade(address newImplementation) external  {
        require(msg.sender == admin);
        implementation = newImplementation;
    }
}


//演示
// 1.部署UUPS的逻辑合约UUPSLogic1和UUPSLogic2
// 2.部署UUPS代理合约UUPSProxy, 将implementation地址指向旧逻辑合约UUPSLogic1
// 3.利用选择器0xc2985578,通过代理合约调用旧逻辑合约UUPSLogic1的foo函数, 将words的值改为“old”
// 4.利用在线abi编码器HashEx获得二进制编码,调用升级函数upgrade（）,将implementation地址指向新逻辑合约UUPSLogic2
//   0900f010000000000000000000000000ed34ee41ca84042b619e9aebf6175bb4a0069a05


// 总结
// 我们介绍了代理合约中选择器冲突的另一个解决方案：UUPS
// 通用可升级代理标准
// 与透明代理不同，UUPS将升级函数放在了逻辑合约中，从而使得“选择器中途”
// 不能通过编译。相比于透明代理，UUPS更省gas,但也更复杂