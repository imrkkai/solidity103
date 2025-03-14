// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 代币水龙头
// 代币水龙头就是让用户免费领代币的网站/应用。

// ERC20水龙头合约

// 将一下ERC20代币转到水龙头合约里，用户可以通过合约的requestToken()函数来领取100单位的代币，每个地址只能领取一次

// 状态变量
// 在水龙头合约中，定义三个状态变量
// - amountAllowed 设置每次能领取代币数量（默认:100）
// - tokenContract记录发放的ERC20代币合约的地址
// - requestedAddress 记录领取过代币的地址

// 事件
// 在水龙头合约中定义SendToken事件，记录每次领取代币的地址和睡了, 在requestToken（）函数被调用时释放

// 函数
// 在合约中定义两个函数
// - 构造函数: 初始化tokenContract状态变量，确定发放的ERC20代币地址
// - requestToken())函数，用户调用它可以领取ERC20代币

import "IERC20.sol";

contract Faucet {
    uint256 public amountAllowed = 100;
    address public tokenContract;
    mapping(address => bool) public requestedAddress; 

    event SendToken(address indexed receiver, uint indexed amount);


    constructor(address _tokenContract) {
        tokenContract = _tokenContract;
    }

    function requestToken() external {
        require(!requestedAddress[msg.sender], "Can't Request Multiple Times!");
        IERC20 token = IERC20(tokenContract);
        require(token.balanceOf(address(this)) > amountAllowed, "Faucet Empty!");

        token.transfer(msg.sender, amountAllowed);
        requestedAddress[msg.sender] = true;
        emit SendToken(msg.sender, amountAllowed); 
    }

}