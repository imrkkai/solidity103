// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 代理模式
// Solidity合约部署在链上之后，代码是不可变的（immutable）。这样既有优点也有缺点：
// - 优点：安全、用户知道会发生什么(大部分时候)
// - 坏处：就算合约中存在bug，也不能修改或升级。只能部署新合约。但是
//   新合约的地址与旧的不一样，且合约的数据也需要花费大量的gas进行迁移。

// 有没有办法在合约部署之后，进行修改或升级呢？答案肯定是有的，那就是代理模式。

//调用链： caller ->(call) proxy contract ->(delegate) implementation(Logic contract)

// 代理模式主要两个好处:
// 1.可升级：当我们需要升级合约的逻辑时，只需要将代理合约指向新的逻辑合约
// 2. 省gas：如果多个合约复用一套逻辑，只需部署一个逻辑合约，然后在部署多个只保存数据的代理合约，指向逻辑合约

// 代理合约
// 实现一个代理合约，它有三个部分组成:
// - 代理合约proxy
// - 逻辑合约logic
// - 一个调用caller
// 其逻辑并不复杂。
// 首先部署逻辑合约logic
// 创建代理合约proxy，状态变量implementation 记录logic合约地址
// proxy合约利用 回调函数fallback，将所有调佣委托给logic合约
// 最后部署调用示例caller合约，调用proxy合约

// 需要注意：logic合约和proxy合约的状态变量存储结果要相同，不然delegatecall会产生意想不到的行为,有安全隐患

// 代理合约 proxy

contract Proxy {
    address public  implementation; // 逻辑合约地址

    constructor(address _implementation) {
        implementation = _implementation;
    }

    receive() external payable { }

    // proxy回调函数将外部对本合约的调用委托给logic合约。
    // 这个回调函数很别致，它利用内联汇编，让本来不能有返回值的回调函数有了返回值，其中用到的内联汇编版操作码：
    // - calldatacopy(t, f, s): 将calldata从位置f开始复制s个字节到mem的位置t.
    // - delegatecall(g, a, in , insize, out, outsize):
    //调用地址a的合约，输入mem[in ... (int + insize)]，输出为mem[out .. (out+outsize)]
    // 提供g wei的以太坊gas，操作码在错误时返回0，在成功时返回1.
    // - reutrndatacopy(t, f, s): 将returndata（输出数据）从位置f开始复制s字节到mem（内存）的位置t。
    // - switch: 基础版if/elsek, 不同的情况case返回不同的值，可以有一个默认的default情况
    // - return（p, s）: 终止函数执行，返回数据mem[p..(p+s)]
    // - revert(p, s): 终止函数执行，回滚状态，返回数据mem[p..(p+s)]

    fallback() external payable  {
        address _implementation = implementation;
        assembly {
            // 将msg.data拷贝到内存
            // calldatacopcy 操作码参数:
            // - 内存起始位置，
            // - calldata起始位置
            // - calldata的长度， 通过calldatasize()获取
            calldatacopy(0, 0, calldatasize())

            // 利用delegatecall调用implementation合约
            // delegatecall操作码的参数：
            // - gas
            // - 目标合约地址
            // - input mem起始位置
            // - input mem长度
            // - output area mem起始位置
            // - output area mem长度
            // delegatecall成功返回1，失败返回0
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // 将输出数据从0位置复制到mem位置0
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            case 1 {
                return(0, returndatasize())
            }
        }
    }
}



    contract Logic {
        address public implementation;
        uint public x = 99;
        event CallSuccess(); // 调用成功事件
        // 函数selector = bytes4(keccak256("increment()"))
        function increment() external returns(uint) {
            emit CallSuccess();
            return x + 1;
        }
    }


    // 调用者合约
    // Caller合约会演示如何调用一个代理合约，它也非常简单.
    // 它有一个变量，2个函数
    // proxy： 状态变量，记录代理合约地址
    // 构造函数：部署合约时初始化proxy变量

    // increment(): 利用call来调用代理合约的increment()函数，并返回一个uint。
    // 在调用时，利用abi.encodeWithSignature()获取了increment（）函数的selector。
    // 在返回时，利用abi.decode()将返回值解码为uint类型

    contract Caller {
        address public proxy; // 代理合约地址

        constructor(address _proxy) {
            proxy = _proxy;
        }

        function increment() external returns(uint) {
            (, bytes memory data) = proxy.call(abi.encodeWithSignature("increment()"));
            return abi.decode(data, (uint));
        }
    }


    // 演示
    // 1. 部署logic合约
    // 2. 调用logic合约的increment()函数，返回100

    // 3. 部署proxy合约, 初始化填入logic合约地址
    // 4. 调用proxy合约的increment()函数，无返回值.
    // 调用方式: 在refix部署面板中点proxy合约，在最下面的
    // Low level interaction中填入increment() 函数的选择器
    // 0xd09de08a 并点击Transact

    // 5. 部署Caller合约，并初始化填入Proxy合约地址
    // 6. 调用Caller合约increment() 函数，返回 1
    

    // 代理模式和简单的代理合约。
    // 代理合约利用delegatecall将函数调用委托给了另一个逻辑合约，使得数据和逻辑分别由不同合约负责。
    // 并且，它利用内联汇编黑魔法，让没有返回值的回调函数也可以返回数据。
    // 前面留给大家的问题是：为什么通过Proxy调用increment()会返回1呢？
    // 按照我们在第23讲Delegatecall中所说的，
    // 当Caller合约通过Proxy合约来delegatecall Logic合约的时候，
    // 如果Logic合约函数改变或读取一些状态变量的时候都会在Proxy的对应变量上操作，
    // 而这里Proxy合约的x变量的值是0
    //（因为从来没有设置过x这个变量，即Proxy合约的storage区域所对应位置值为0），
    // 所以通过Proxy调用increment()会返回1。

    
    // 代理合约虽然很强大，但是它非常容易出bug，用的时候最好直接复制OpenZeppelin的模版合约。
