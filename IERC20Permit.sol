// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
// 合约
// IERC20Permit接口合约
// ERC20Permit的接口合约，定义了3个函数:
// permit(): 根据owner的签名，将owner的ERC20代币余额授权给spender,数量为value。要求：
//  spender-不能是0地址
//  deadline- 必须是未来的时间戳
//  v,r,s必须是owner对EIP712格式的函数参数的有效keccak256签名
// 签名必须使用owner当前的nonce。

// nonces(): 返回owner当前的nonce。每次为permit（）函数生成签名时，都必须包括此值。
// 每次成功调用permit()函数都会将owner的nonce增加1，防止多次使用同一个签名


// DOMAIN_SEPARATOR(): 返回用于编码permit（）函数的签名的域分隔符，如EIP712所定义。


interface IERC20Permit {

    /**
     * @dev 根据owner的签名, 将 `owenr` 的ERC20余额授权给 `spender`，数量为 `value`
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external ;

    /**
     * @dev 返回 `owner` 的当前 nonce。每次为 {permit} 生成签名时，都必须包括此值。
     */
    function nonces(address owner) external view returns(uint256);


    /**
     * @dev 返回用于编码 {permit} 的签名的域分隔符（domain separator）
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns(bytes32);
    
}
