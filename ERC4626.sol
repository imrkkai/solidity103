// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {IERC4626} from "IERC4626.sol";
import {ERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


// ERC4626合约
// 实现一个简化的代币化金额合约
// - 构造函数初始化基础资产的合约地址，金额份额的代币名称和符号
//   注意，金库份额的代币名称和符号要和基础资产有关联，比如基础资产叫MKC，那么金额份额最好叫vMKC。
// - 存款时，当用户向金库存X单位的基础资产，会铸造X单位（等量）的金库份额。
// - 取款时，当用户销毁x单位的金库份额，会提取x单位（等量）的基础资产


// 注意：在实际使用时，要特别小心和会计逻辑相关函数的计算是向上取整还是向下取整
// 可以参考 openzeppelin 和 solmate 的实现。本节的教学例子中不考虑它。
//https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol


contract ERC4626 is ERC20, IERC4626 {

    ERC20 private immutable _asset;

    constructor(
        ERC20 asset,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _asset = asset;
    }



    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    function deposit(uint256 assets, address receiver) public virtual returns(uint256 shares) {
        // 利用previewDeposit() 计算将获得的金库份额
        shares = previewDeposit(assets);
        // 先transfer后mint，防止重入
        _asset.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        // 释放Deposit事件
        emit Deposit(msg.sender, receiver, assets, shares);

    }


    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        // 利用previewMint()计算需要存款的基础资产数额
        assets = previewMint(shares);

        // 先transfer后mint，防止重入
        _asset.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        // 释放Deposit事件
        emit Deposit(msg.sender, receiver, assets, shares);
    }


    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        // 利用 previewWithdraw() 计算将销毁的金库份额
        shares = previewWithdraw(assets);

        // 如果调用者不是 owner，则检查并更新授权
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // 先销毁后transfer，防止重入
        _burn(owner, shares);
        _asset.transfer(receiver, assets);

        // 释放 Withdraw 事件
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 assets) {
        // 利用 previewRedeem() 计算能赎回的基础资产数额
        assets = previewRedeem(shares);

        // 如果调用者不是 owner，则检查并更新授权
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // 先销毁后 transfer，防止重入
        _burn(owner, shares);
        _asset.transfer(receiver, assets);

        // 释放 Withdraw 事件       
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }


    function totalAssets() public view virtual returns (uint256){
        // 返回合约中基础资产持仓
        return _asset.balanceOf(address(this));
    }


    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        // 获取合约的代币的总供给
        uint256 supply = totalSupply();
        // 如果 supply 为 0，那么 1:1 铸造金库份额
        // 如果 supply 不为0，那么按比例铸造
        return supply == 0 ? assets : assets * supply / totalAssets();
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        // 获取合约的代币的总供给
        uint256 supply = totalSupply();
        // 如果 supply 为 0，那么 1:1 赎回基础资产
        // 如果 supply 不为0，那么按比例赎回
        return supply == 0 ? shares : shares * totalAssets() / supply;
    }


     function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf(owner);
    }

}


// 演示
// 1. 部署ERC20代币合约 TEST, 并给自己铸造10000代币

// 2. 不是ERC4626代币合约,将基础资产的合约地址设置为TEST合约地址
//   名称和符号均设置为vTEST

// 3.调用ERC20合约的approve函数，将代币授权给ERC4626合约

// 4. 调用ERC4626合约的deposit函数，存款1000枚代币，然后
// 调用balanceOf()函数，查看自己的金库分红变为1000


// 代币化金库标准 ERC4626，并写了一个简单的金库合约，可以将基础资产 1:1 的转换为金库份额代币。ERC4626 为 DeFi 提升流动性和可组合性，未来将逐渐普及。