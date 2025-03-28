// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//MultiCall

// 在Solidity中，Multicall（多重调用）合约的设计能让我们在一次交易中执行多个函数调用.
// 其优点如下：
// 1. 方便性：MultiCall能让你在一次交易中对不同合约的不同函数进行调用,
//    同时这些调用还可以使用不同的参数，比如你可以一次性查询多个地址的ERC20代币的余额

// 2. 节省gas: MultiCall能将多个交易合并成一次交易中的多个调用，从而节省gas。
// 3. 原子性：MultiCall能让用户在一笔交易中执行所有的操作，保证所有的操作要么全部成功，要么全部失败,这样就保证了原子性。
//    比如你可以按照特定的顺序进行一系列的代币交易

// MultiCall合约

// 接下来让我们一起来研究一下MultiCall合约，它由 MakerDAO 的 MultiCall 简化而成。
// https://github.com/mds1/multicall/blob/main/src/Multicall3.sol

// MultiCall合约定义了两个结构体：
// - Call: 这是一个调用结构体，包含要调用的目标合约target，指示是否允许调用失败的标记allowFailure,和要调用的字节码calldata
// - Result: 这是一个结果结构体，包含了指示调用是否成功的标记success和调用返回的字节码return data。
// 该合约只包含了一个函数，用于执行多重调用

// multicall(): 这个函数的参数是一个由Call结构体组成的数组，这样可以确保传入的target和data的长度一致，函数通过一个循环来执行多个调用，并在调用失败时回滚交易。


contract  Multicall {

    struct Call{
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result{
        bool success;
        bytes returnData;
    }

    function multicall(Call[] calldata calls) public returns(Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata calli;

        for(uint256 i = 0; i < length; i++) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.call(calli.callData);

            // 如果 calli.allowFailure 和 result.success 均为 false，则 revert
            if(!(calli.allowFailure || result.success)) {
                revert("Multicall: call failed");
            }
        }
    }
    
}



contract MCERC20 is ERC20{
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_){}
    function mint(address to, uint amount) external {
        _mint(to, amount);
    }
}



// 演示
// 1.先部署一个MCERC20合约，名名称和symbol分别为TEST和TEST。记录合约地址: 
/*
0x2A778f111db48Ff42c243076d09a0966F65ADB17
*/

// 2. 部署MultiCall合约

// 3. 获取要调用的calldata。分别给两个2地址铸造50和100单位的代币
// 可以在remix调用页面将mint（）的参数填入，然后点击Calldata按钮
// 将编码好的calldata赋值下来:
/*
to：0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
amount: 50
calldata: 0x40c10f190000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000000000000000000000000000000000000000000000000000032

to: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
amount: 100
calldata: 0x40c10f19000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb20000000000000000000000000000000000000000000000000000000000000064

*/

// 4. 利用MultiCall的multicall（）函数调用ERC20代币合约的mint（）函数
//    给2个地址分别铸造50和100单位的代币

/*
calls: [["0x2A778f111db48Ff42c243076d09a0966F65ADB17", true, "0x40c10f190000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000000000000000000000000000000000000000000000000000032"], ["0x2A778f111db48Ff42c243076d09a0966F65ADB17", false, "0x40c10f19000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb20000000000000000000000000000000000000000000000000000000000000064"]]

*/

// 5.利用MultiCall合约的multicall（）函数调用ERC20代币合约的balanceOf()函数
// 查询刚刚铸造2个地址的余额，
// balanceOf()函数的selector为0x70a08231

/*
calls: [["0x2A778f111db48Ff42c243076d09a0966F65ADB17", false, "0x70a082310000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc4"],["0x2A778f111db48Ff42c243076d09a0966F65ADB17", false, "0x70a08231000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2"]]
*/


// 我们介绍了 MultiCall 多重调用合约，允许你在一次交易中执行多个函数调用。要注意的是，不同的 MultiCall 合约在参数和执行逻辑上有一些不同，使用时要仔细阅读源码。