// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// ERC20
// ERC20是以太坊上的代币标准，它实现了代币转账的基本逻辑:
// balanceOf(): 账户余额
// transfer(): 转账
// transferFrom(): 授权转账
// approve(): 授权
// totalSupply(): 代币总供给
// allowance(): 授权转账额度

// 代币信息:
// name(): 名称
// symbol(): 代号
// decimals(): 小数位数


// IERC20
// IERC20是ERC20代币标准的接口合约,规定了ERC20代币需要实现的函数和事件。
// 之所以需要定义接口，是因为有了规范后，就存在所有的ERC20代币都通用的函数名称，输入参数，输出参数。
// 在接口函数中，只需要定义函数名称，输入参数，输出参数，并不关心函数内部如何实现。
// 由此，函数就分为内部和外部两个内容，一个重点是实现，另一个是对外接口，约定共同数据
// 这就是为什么需要ERC20.sol和IERC20.sol两个文件实现一个合约

// 事件
// IERC20定义了2个事件：
// - Transfer事件： 在转账时发布
// - Approval事件: 在授权时发布
////////
/**
 * @dev 释放条件：当 `value` 单位的货币从账户 (`from`) 转账到另一账户 (`to`)时.
 */
//event Transfer(address indexed from, address indexed to, uint256 value);

/**
 * @dev 释放条件：当 `value` 单位的货币从账户 (`owner`) 授权给另一账户 (`spender`)时.
 */
//event Approval(address indexed owner, address indexed spender, uint256 value);

////

// 函数
//IERC20定义了6个函数，提供了 转移代币的基本功能，并允许代币获得批准，以便其他链上第三方使用。

// ## totalSupply()返回代币总供给
/**
 * @dev 返回代币总供给.
 */
//function totalSupply() external view returns (uint256);

// ##  balanceOf()返回账户余额
/**
 * @dev 返回账户`account`所持有的代币数.
 */
//function balanceOf(address account) external view returns (uint256);

// ##  transfer()转账
/**
 * @dev 转账 `amount` 单位代币，从调用者账户到另一账户 `to`.
 *
 * 如果成功，返回 `true`.
 *
 * 释放 {Transfer} 事件.
 */
//function transfer(address to, uint256 amount) external returns (bool);

// ## allowance()返回授权额度
/**
 * @dev 返回`owner`账户授权给`spender`账户的额度，默认为0。
 *
 * 当{approve} 或 {transferFrom} 被调用时，`allowance`会改变.
 */
// function allowance(address owner, address spender) external view returns (uint256);

// ##  approve()授权
/**
 * @dev 调用者账户给`spender`账户授权 `amount`数量代币。
 *
 * 如果成功，返回 `true`.
 *
 * 释放 {Approval} 事件.
 */
// function approve(address spender, uint256 amount) external returns (bool);


// ##  transferFrom()授权转账
/**
 * @dev 通过授权机制，从`from`账户向`to`账户转账`amount`数量代币。转账的部分会从调用者的`allowance`中扣除。
 *
 * 如果成功，返回 `true`.
 *
 * 释放 {Transfer} 事件.
 */

// function transferFrom(
//     address from,
//     address to,
//     uint256 amount
// ) external returns (bool);


// 实现ERC20

// 状态变量
// 我们需要状态变量记录账户余额、授权额度和代币信息
// - 使用public修饰变量，会自动生成一个同名的getter函数
// - 使用override修饰public变量，会重写继承字父合约的与变量同名的getter函数

import "./IERC20.sol";

contract ERC20 is IERC20{
    
    mapping(address => uint256) public override balanceOf;

    mapping(address => mapping(address => uint256)) public override allowance;

    uint256 public override totalSupply;   // 代币总供给

    string public name;   // 名称
    string public symbol;  // 代号
    uint8 public decimals = 18; // 小数位数

    // 构造函数,初始化代币名称、代号
    constructor(string memory name_, string memory symbol_){
        name = name_;
        symbol = symbol_;
    }


    // transfer()函数：实现IERC20中的transfer函数，代币转账逻辑。
    // 调用方扣除amount数量代币，接收方增加相应代币。
    // 土狗币会魔改这个函数，加入税收、分红、抽奖等逻辑。

    function transfer(address to, uint amount) public override returns (bool) {
        balanceOf[msg.sender] -= amount; // 减少调用方余额
        balanceOf[to] += amount;  // 增加接收方余额
        // 发布 Transfer 事件
        emit Transfer(msg.sender, to, amount);
        return true;
    }

     // approve()函数：实现IERC20中的approve函数，代币授权逻辑。
     // 被授权方spender可以支配授权方的amount数量的代币。
     // spender可以是EOA账户，也可以是合约账户。
     // 当你用uniswap交易代币时，你需要将代币授权给uniswap合约。


    function approve(address spender, uint amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;  // 授权给spender amount数量的代币。
        emit Approval(msg.sender, spender, amount); // 发布授权事件
        return true;
    }

    // transferFrom()函数：实现IERC20中的transferFrom函数，授权转账逻辑。
    // 被授权方将授权方owner的amount数量的代币转账给接收方to。

    function transferFrom(
        address owner,
        address to,
        uint amount
    ) public override returns (bool) {
        allowance[owner][msg.sender] -= amount; // 减少owner给msg.sender的授权额度 
        balanceOf[owner] -= amount; // 减少授权方的额度
        balanceOf[to] += amount; // 增加接收方的额度
        emit Transfer(owner, to, amount);
        return true;
    }

    //mint()函数：铸造代币函数，不在IERC20标准中。
    // 这里为了方便，任何人可以铸造任意数量的代币，实际应用中会加权限管理，只有owner可以铸造代币：
    function mint(uint amount) external {
        balanceOf[msg.sender] += amount; // 给调用方增加余额
        totalSupply += amount; // 增加代币总供给量
        emit Transfer(address(0), msg.sender, amount);
    }

    //  burn()函数：销毁代币函数，不在IERC20标准中。
    function burn(uint amount) external {
        balanceOf[msg.sender] -= amount; // 减少调用方余额
        totalSupply -= amount; // 减少代币总供给量
        emit Transfer(msg.sender, address(0), amount);
    }

}


// 发行ERC20代币
// 有了ERC20标准后，在ETH发行代币变得非常简单。现在，我们发行属于我们的第一个代币
// 在remix上编译好ERC20合约，在部署栏里输入构造函数的参数，name和symbol都是设置为SEX
// 然后点击transact按钮进行部署

// 运行mint函数，给自己铸币，1000000
// 使用balanceOf查询余额

// 
// 我们学习了以太坊上的ERC20标准及其实现，并且发行了我们的测试代币。2015年底提出的ERC20代币标准极大的降低了以太坊上发行代币的门槛，并开启了ICO大时代。在投资时，仔细阅读项目的代币合约，可以有效避开貔貅，增加投资成功率。