// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
// 可升级合约

// 可升级合约（Upgradeable Contract）。
// 教学用的合约由OpenZeppelin中的合约简化而来，可能有安全问题，不要用于生产环境。

// 如何你了解了代理合约，就很容易理解可升级合约.它就是一个可以更改逻辑合约的代理合约。

// 简单实现
// 实现一个简单的可升级合约，它包含3个合约：代理合约、旧的逻辑合约和新的逻辑合约。

// 代理合约
// 这个代理合约相对简单，并没有在它的fallback（）函数中使用内联汇编，而仅仅用了implementation.delegatecall(msg.data)
// 因此，回调函数没有返回值, 足够用于演示。
// 包含3个变量：

// implementation：逻辑合约地址。
// admin：admin地址。
// words：字符串，可以通过逻辑合约的函数改变。

// 它包含3个函数：
// 构造函数：初始化admin和逻辑合约地址。
// fallback()：回调函数，将调用委托给逻辑合约。
// upgrade()：升级函数，改变逻辑合约地址，只能由admin调用。



contract SimpleUpgrade {
    address public implementation; // 逻辑合约地址
    address public admin; // admin地址
    string public words; // 字符串，可以通过逻辑合约的函数来改变

    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    //fallback函数，将调用委托给逻辑合约
    fallback() external payable {
        (bool success, bytes memory data) = implementation.delegatecall(msg.data);
    }
    
    
    receive() external payable { }

    // 升级函数，改变逻辑合约地址，只能由admin调用
    function upgrade(address newImplementation) external  {
        require(msg.sender == admin);
        implementation = newImplementation;
    }

}


// 旧逻辑合约

contract Logic1 {
    // 状态变量和proxy合约一致，防止插槽冲突
    address public implementation;
    address public admin;
    string public words; // 字符串，可以通过逻辑合约的函数改变

    function foo() public {
        words = "old";
    }

}

// 新逻辑合约
contract Logic2 {
    // 状态变量和proxy合约一致，防止插槽冲突
    address public implementation;
    address public admin;
    string public words; // 字符串，可以通过逻辑合约的函数改变

    function foo() public {
        words = "new";
    }

}

// 演示
// 1.部署新旧逻辑合约 Logic1和Logic2
// 2.部署可升级合约，将implementation指向旧逻辑合约
// 3.利用选择器0xc2985578，在合约中调佣旧逻辑合约Logic1的foo（）函数
//   将words的值改为"old"

// 4. 调用upgrade()函数，将implementation地址指向新的逻辑合约Logic2
// 5.利用选择器0xc2985578，在合约中调佣旧逻辑合约Logic1的foo（）函数
//   将words的值改为"new"


// 总结：介绍一个简单的可升级合约。
// 它是一个可以改变逻辑合约的代理合约，
// 给不可更改的智能合约增加了升级功能。
//但是，这个合约有选择器冲突的问题，存在安全隐患。
// 后面将会会介绍解决该隐患的可升级合约标准：透明代理和UUPS。

