// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 这里将介绍代理合约的选择器冲突（selector Clash）及其解决方案: 透明代理（Transparent Proxy）。

// 选择器冲突
// 智能合约中，函数选择器（selector）是函数签名的哈希的前4个字节。例如：
// mint(address account)的选择器为bytes4(keccak256("mint(address)"))，即0x6a627842

// 由于函数选择器仅有4个字节，范围很小，因此两个不同的函数可能会有相同的选择器，例如下面的两个函数：

contract Foo {
 //   function burn(uint256) {}
 //   function collate_propagate_storage(bytes16) external {}

    bytes4 public selector1 = bytes4(keccak256("burn(uint256)"));
    bytes4 public selector2 = bytes4(keccak256("collate_propagate_storage(bytes16)"));
}

// Foo示例中，函数burn()和collate_propagate_storage()的选择器都为0x42966c68，是一样的，
// 这种情况被称为“选择器冲突”。在这种情况下，EVM无法通过函数选择器分辨用户调用哪个函数，
// 因此该合约无法通过编译。

// 由于代理合约和逻辑合约是两个合约，就是他们之间存在选择器冲突也可以正常编译，
// 这可能会导致很严重的安全事故，举个例子，如果逻辑合约的a函数和代理合约的升级函数的选择器相同，那么
// 那么管理员就会在调用a函数时，将代理合约升级为一个黑洞合约，后果不堪设想。

// 目前有两个可升级合约标准解决了这个问题：
// - 透明代理 TransparentProxy
// - 通用可升级代理UUPS


// 透明代理
// 透明代理的逻辑非常简单：
// 管理员可能会因为函数选择器冲突，在调用逻辑合约的函数时，误调用代理合约的可升级函数，
// 那么限制管理员的权限，不让他调用任务逻辑合约的函数，就能解决冲突。

// - 管理员变为工具人，仅能调用代理合约的可升级函数对合约升级，不能通过回调函数调佣逻辑合约
// - 其它用户不能调用可升级函数，但是可以调佣逻辑合约的函数

// 透明代理合约
// 这里的代理合约和之前的代理合约非常相近，只是fallback()函数限制了管理员地址的调用
// 包含3个变量:
// - implementation：逻辑合约地址
// - admin: admin地址
// - words：字符串，可以通过逻辑合约的函数改变

// 它包含3个函数:
// - 构造函数：初始化admin和逻辑合约地址
// - fallback(): 回调函数，将调佣委托给逻辑合约，不能由admin调佣
// - upgrade()： 可升级函数，改变逻辑合约地址，只能由admin调用

contract TransparentProxy {
    address implementation; //logic合约地址
    address admin; // 管理员
    string public words; // 字符串，可以通过逻辑合约的函数改变


    // 构造函数，初始化admin和逻辑合约地址
    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    // fallback函数，将调用委托给逻辑合约
    // 不能被admin调用，避免选择器冲突引发意外

    fallback() external payable {
        require(msg.sender != admin);
        // 调用逻辑合约
        (bool success, bytes memory data) = implementation.delegatecall(msg.data);
    }

    // 升级函数, 改变逻辑合约地址，只能由amdin调佣
    function upgrade(address newImplementation) external {
        if(msg.sender != admin) revert();
        implementation = newImplementation;
    }

}

// 逻辑合约跟之前的logic1和logic2是一样的


// 演示
// 1.部署逻辑合约logic1
// 2.部署透明代理合约TransparentProxy, 将implementation地址指向旧逻辑合约地址
// 3. 利用选择器0xc2985578，通过代理合约调用逻辑合约logic1的foo函数。
//    调用将失败，因为管理员不能调用逻辑合约
// 4. 切换新钱包，利用选择器0xc2985578，通过代理合约调佣旧逻辑合约logic1的foo函数,
//    将words的值改为old, 调用成功

// 5. 切换回管理员钱包，调用upgrade()，将implementation地址指向新逻辑合约logic2
// 6.切换新钱包，利用选择0xc2985578，在代理合约中调用新逻辑合约logic2的foo()函数,将words的值改为“new”

// 这一部分介绍了代理合约中的选择器冲突，以及如何利用透明代理避免该问题。
// 透明代理的逻辑很简单，通过限制管理员调用逻辑合约来解决选择器冲突的问题
// 它也有缺点，每次用户调用函数时，都会多一步是否为管理员的检查
// 消耗更多gas。但瑕不掩瑜，透明代理仍是大多数项目方选择的方案。

// 那有没有既能解决选择器中途，又能省gas的解决方案呢?
// 答案是有的，通用可升级代理UUPS