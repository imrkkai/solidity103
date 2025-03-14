// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 空投



// 空投合约
// 空投合约的逻辑很简单: 使用循环向多个地址发送代币
// 有两个函数
// - getSum()函数：返回uint数组的和值
// - multiTransferToken()函数： 发送ERC20代币空投，包含了三个参数
// _token： 代币合约地址
// _addresses: 接收空投的地址数组
// _amounts: 空投地址对应的空投数量的数组

import "IERC20.sol";

contract Airdrop {
    function getSum(uint256[] calldata _arr) public pure returns(uint sum) {
        for(uint i = 0; i < _arr.length; i++) {
            sum = sum + _arr[i];
        }
    }

    function multiTransferToken(address _token, address[] calldata _addresses, uint256[] calldata _amounts) external {
        // 地址数组的长度和金额数组的长度要一致
        require(_addresses.length == _amounts.length, "Lengths of Addresses and Amounts NOT EQUAL");
        // 通过合约地址获取合约接口变量
        IERC20 token = IERC20(_token);
        // 累计空投总额
        uint _amountSum = getSum(_amounts);
        // 判断授权数量是否大于等于要空投的数量
        require(token.allowance(msg.sender, address(this)) >= _amountSum, "Need Approve ERC20 token");

        // 使用循环，发送空投
        for(uint8 i; i < _addresses.length; i++) {
            token.transferFrom(msg.sender, _addresses[i], _amounts[i]);
        }
    }


    //以太坊空投
    // multiTransferETH()函数：发送ETH空投, 有两个参数
    // _addresses: 接收空投的地址数组
    // _amounts: 空投数量的数组，对应_addresses地址中的每个地址的数量

    function multiTransferETH(
        address payable[] calldata _addresses,
        uint256[] calldata _amounts
    ) public  payable {
        
        // 检查地址数组和金额数组，它们的长度是否一致
        require(_addresses.length == _amounts.length, "Lengths of Addresses and Amounts NOT EQUAL");
        // 累计总空投数量
        uint _amountSum = getSum(_amounts);

        // 转账的ETH应该等于总空投数量
        require(msg.value == _amountSum, "Transfer amount error");

        // 空投转账
        for(uint256 i = 0; i < _addresses.length; i++) {
            _addresses[i].transfer(_amounts[i]);
        }

    }
    


}



// 1.部署空投合约
// 2.使用ERC20合约的approve()函数授权空投合约10000单位代币
// 
