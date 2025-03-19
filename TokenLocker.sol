// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "IERC20.sol";
// 代币锁
// 代币锁(Token Locker)是一种简单的时间锁合约，它可以把合约中的代币锁仓一段时间，受益人在锁仓期满后可以取走代币。代币锁一般是用来锁仓流动性提供者LP代币的。

// 什么是LP代币
// 区块链中，用户在去中心化交易所DEX上交易代币，例如Uniswap交易所。DEX和中心化交易所(CEX)不同，去中心化交易所使用自动做市商(AMM)机制，需要用户或项目方提供资金池，以使得其他用户能够即时买卖。简单来说，用户/项目方需要质押相应的币对（比如ETH/DAI）到资金池中，作为补偿，DEX会给他们铸造相应的流动性提供者LP代币凭证，证明他们质押了相应的份额，供他们收取手续费。

// 为什么要锁定流动性？
// 如果项目方毫无征兆的撤出流动性池中的LP代币，那么投资者手中的代币就无法变现，直接归零了。这种行为也叫rug-pull，仅2021年，各种rug-pull骗局从投资者那里骗取了价值超过28亿美元的加密货币。

// 但是如果LP代币是锁仓在代币锁合约中，在锁仓期结束以前，项目方无法撤出流动性池，也没办法rug pull。因此代币锁可以防止项目方过早跑路（要小心锁仓期满跑路的情况）。

// 代币锁合约
// 下面，我们就写一个锁仓ERC20代币的合约TokenLocker。它的逻辑很简单：

// - 开发者在部署合约时规定锁仓的时间，受益人地址，以及代币合约。
// - 开发者将代币转入TokenLocker合约。
// - 在锁仓期满，受益人可以取走合约里的代币。


// 事件
// TokenLocker合约中共有2个事件。
// TokenLockStart：锁仓开始事件，在合约部署时释放，记录受益人地址，代币地址，锁仓起始时间，和结束时间。
// Release：代币释放事件，在受益人取出代币时释放，记录记录受益人地址，代币地址，释放代币时间，和代币数量。

// 状态变量
// TokenLocker合约中共有4个状态变量。
// token：锁仓代币地址。
// beneficiary：受益人地址。
// locktime：锁仓时间(秒)。
// startTime：锁仓起始时间戳(秒)。

// TokenLocker合约中共有2个函数。
// 构造函数：初始化代币合约，受益人地址，以及锁仓时间。
// release()：在锁仓期满后，将代币释放给受益人。需要受益人主动调用release()函数提取代币。




contract TokenLocker {

    // 事件
    event TokenLockStart(address indexed beneficiary, address indexed token, uint256 startTime, uint256 lockTime);
    event Release(address indexed beneficiary, address indexed token, uint256 releaseTime, uint256 amount);

    // 被锁仓的ERC20代币合约
    IERC20 public immutable token;
    // 受益人地址
    address public immutable beneficiary;
    // 锁仓时间(秒)
    uint256 public immutable lockTime;
    // 锁仓起始时间戳(秒)
    uint256 public immutable startTime;


    /**
     * @dev 部署时间锁合约，初始化代币合约地址，受益人地址和锁仓时间。
     * @param token_: 被锁仓的ERC20代币合约
     * @param beneficiary_: 受益人地址
     * @param lockTime_: 锁仓时间(秒)
     */
    constructor(
        IERC20 token_,
        address beneficiary_,
        uint256 lockTime_
    ) {
        require(lockTime_ > 0, "TokenLock: lock time should greater than 0");
        token = token_;
        beneficiary = beneficiary_;
        lockTime = lockTime_;
        startTime = block.timestamp;

        emit TokenLockStart(beneficiary_, address(token_), block.timestamp, lockTime_);
    }


     /**
     * @dev 在锁仓时间过后，将代币释放给受益人。
     */
    function release() public {
        require(block.timestamp >= startTime+lockTime, "TokenLock: current time is before release time");

        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "TokenLock: no tokens to release");

        token.transfer(beneficiary, amount);

        emit Release(msg.sender, address(token), block.timestamp, amount);
    }


}