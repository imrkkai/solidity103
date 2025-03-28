// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 自动做市商
// 自动做市商（Automated Market Maker,简称AMM）是一种算法，或者说是一种
// 在区块链上运行的智能合约，它允许数字资产之间的去中心化交易
// AMM的引入开创了一种全新的交易方式, 无需传统的买家和卖家进行订单匹配，而是
// 通过一种预设的数学公司（比如常数乘积公司）创建一个流动性池，使得用户可以随时进行交易。

// 以可乐(COLA)和美元（USD）的市场为例，来介绍AMM的原理。
// 为了方便，规定一下符号：x和y分别表示市场中可乐喝美元的总量
// Δx 和 Δy 分别表示一笔交易中可乐和美元的变化量
// L 和 ΔL 分别表示总流动性和流动性的变化量。

// 恒定总和自动做市商
// 恒定总和自动做市商（Constant Sum Automated Market maker, CSAMM）是最简单的自动做市商模型
// 我们从他开始，来看看它是如何工作的，它在交易时的约束为:
// k = x + y

// 其中k为常数，也就是说，在交易前后市场中可乐喝美元数量的总和和保持不变。举个例子，
// 市场中流动性有10瓶可乐喝10美元，此时k=20，可乐的价格为1美元/瓶。
// 我很渴，想拿出2美元来交换可乐。交易后市场中的美元总和变为12
// 根据约束k=20，那么交易后市场中有8瓶可乐，价格为1美元/瓶。
// 我在交易中得到了2瓶可乐，价格为1美元/瓶。

// k = 10 + 10 = 20
// x + Δx + y' = 20, Δx = 2
// 10 + 2 + y' = 20, y' = 8
// Δy = y - y' = 10 - 8 = 2


// CSAMM的优点是可以保证代币的相对价格不变，这点在稳定币兑换中很重要, 大家都希望1USDT总能兑换处1USDC。
// 但它的缺点也很明显，它的流动性容易耗尽：我只要10美元，就可以把市场上可乐的流动性耗尽，其他想和可乐的用户就没法交易了。

// 1.零滑点但流动性有限：CSMM 的定价关系始终为 1:1（本例中 1 美元 = 1 瓶可乐），交易无滑点。但池中资产总和固定，当一方被兑换完时，流动性即枯竭
// 2.极端场景的局限性：若用户尝试购买超过池中现有可乐的数量（例如初始池为 10 瓶可乐和 10 美元，用户试图用 15 美元购买），CSMM 模型将无法完成交易，因为无法满足 
//  x' + y' = k

// 3.  CPMM 的对比：若本题采用 恒定乘积模型（CPMM）（如 Uniswap），用户用 10 美元购买可乐，实际可得约 5 瓶（因滑点影响），但流动性池仍可持续运作 
//   而 CSMM 的零滑点特性在单边大额交易中反而成为缺陷 



// 恒定乘积自动做市商
// 恒定乘积自动做市商(Constant Product Automated Market Maker, CPAMM)，具有“无限”的流动性，是
// 最流行的自动做市商模型，最早被Uniswap采用。它在交易时时的约束为:
// k = x * y

// 其中k为常数，也就是说，在交易前后市场中可乐喝美元数量的乘积保持不变。
// 同样的例子，市场中流动性有10瓶可乐和10美元，此时k = 100，可乐的价格为1美元/瓶。我很渴，想拿出10美元来换可乐.
// 如果CSAMM中，我的交易会换来10瓶可乐，并耗尽市场上可乐的流动性。
// 在在CPAMM中，交易后市场中的美元总量变量20，根据约束k = 100，交易后市场中有5瓶可乐
// 价格为20/5 = 4 美元/瓶。
// 我在交易中得到了5瓶可乐，价格为10/5 = 2美元/瓶

// k = 10 * 10 = 100
// 当用户用10美元（记为Δx）购买可乐时，池中美元数量变为 x + Δx = 10 + 10 = 20, 而可乐数量需调整为y以满足恒定乘积
// (x + Δx) * x = k   => 20 * y = 100 => y = 5

// 因此，Δy = 10 - 5 = 5


// 1. 无手续费简化计算：假设不扣除手续费（即手续费比例 ρ = 0）直接通过恒定乘积公式计算
// 2. 价格滑点：由于大额交易（用户投入金额占池中美元总量的 50%），导致实际成交价格与初始价格（1 美元/瓶）偏离，最终实际兑换率为 10 美元 → 5 瓶，即 2 美元/瓶（远高于初始价格） 
// 3. 流动性池变化：交易后池中资产变为 20 美元和 5 瓶可乐，仍满足 20 * 5 = 100 = k


// CPAMM的优点是拥有"无限"流动性：代币相对价格会随着买卖而变化，越稀缺的代币相对价格会越高,避免流动性被耗尽.
// 上面的例子中，交易让可乐从1美元/瓶 上涨到4美元/瓶，从而避免市场上的可乐被买断


// 去中心化交易所
// 建立一个基于CPAMM的简单的去中心化交易所

// 使用智能合约写一个去中心化交易所SimpleSwap,支持用户交易一对代币.
// SimpleSwap继承了ERRC20代币标准, 方便记录流动性提供者提供的流动性。
// 在构造器中，我们制定了一对代币地址token0和token1, 交易所仅支持这对代币。
// reserve0 和reserve1记录了合约中代币的存储量。


        
// 交易所主要有两类参与者: 流动性提供者（Liquidity Provider, LP） 和 交易者（Trader）
// 我们将分别实现这两部分的功能

// 流动性提供者
//  流动性提供者给市场提供流动性，让交易者获得更好的报价和流动性，并收取一定费用。
// 首先，我们需要实现添加流动性的功能，当用户向代币池添加流动性时，合约会记录添加的LP份额。
// 根据UniswapV2，LP份额如下计算:
// 1.代币池被首次添加流动性时，LP份额ΔL由添加代币数量乘积的平方根决定
// ΔL = squrt(Δx ∗ Δy)

// 2.非首次添加流动性时，LP份额由添加代币数量占池子代币储备量的比例决定
// ΔL = L * min(Δx/x, Δy/y)

// 因为SimpleSwap合约继承了ERC20代币标准，在计算好LP份额后，可以将份额以代币的形式铸造给用户

// 下面的addLiquidity()函数实现了添加流动性的功能, 主要步骤如下：
// 1. 将用户添加的代币转入合约，需要用户事先给合约授权.
// 2. 根据公式计算添加的流动性份额，并检查铸造的LP数量
// 3. 更新合约的代币储备量
// 4. 给流动性提供者铸造LP代币
// 5. 释放Mint事件

// 移除流动性
// 当用户从池子中移除流动性ΔL时，合约要销毁LP份额代币，并按照比例将代币返还给用户。返还代币的计算公式如下：
// Δx = ΔL/L * x
// Δy = ΔL/L * y

// removeLiquidity()函数将实现移除流动性的功能，主要步骤如下:
// 1. 获取合约中的代币余额
// 2. 按LP的比例计算要转出的代币数量
// 3. 检查代币数量
// 4.销毁LP份额
// 5.将相应的代币转给用户
// 6.更新储备量
// 7. 释放Burn事件




// 交易
// 在Swap合约中，用户可以使用一种代币交易另一种代币，那么我用Δx单位的token0，可以换多少单位的token1呢，下面我们来简单推导一下:
// 根据恒定乘积公式，交易钱
// k = x * y

// 交易后，有：
// k = (x + Δx) * (y + Δy)

// 交易前后k值不变，联立上面等式，可以得到:
// Δy = -(Δx * y)/(x + Δx)

// 因此，可以交换到的代币数量Δy有Δx、x和y决定,注意Δx和Δy的符号想法，
// 因为转入会增加代币储备量，而转出会减少

// getAmountOut()函数实现了给定一个资产的数量和代币对的储备，计算交换另一个代币的数量

// 有了这一个核心公式后，我们就实现交易功能了，swap()函数实现了交易代币的功能，主要步骤如下
// 1.用户调用函数时，指定哟几个与交换的代币数量, 交换代币的地址，已经换出另一种代币的最低数量
// 2.判断是token0交换token1, 还是token1交换token0
// 3. 利用上面的公式，计算交换出代币的数量
// 4. 判断交换出的代币是否达到了用户指定的最低数量，这里类似于交易滑点
// 5. 将用户的代币转入合约
// 6. 将交互的代币从合约转给用户
// 7. 更新合约代币的储备量
// 8. 释放swap事件


contract SimpleSwap is ERC20 {
    IERC20 public token0;
    IERC20 public token1;

    uint public reserve0;
    uint public reserve1;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1);

    event Swap(
        address indexed sender,
        uint amountIn,
        address tokenIn,
        uint amountOut,
        address tokenOut
    );

    constructor(IERC20 _token0, IERC20 _token1) ERC20("Simple Swap", "SS") {
        token0 = _token0;
        token1 = _token1;
    }

    // 取两个数的最小值
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

     // 计算平方根 babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }




    // 添加流动性，转进代币，铸造LP
    // @param amount0Desired 添加的token0数量
    // @param amount1Desired 添加的token1数量
    function addLiquidity(uint amount0Desired, uint amount1Desired) public returns (uint liquidity) {
        // 将添加的流动性转入swapo合约，需事先给swap合约授权
        token0.transferFrom(msg.sender, address(this), amount0Desired);
        token1.transferFrom(msg.sender, address(this), amount1Desired);
        
        // 计算添加的流动性
        uint _totalSupply = totalSupply();
        if(_totalSupply == 0) {
            // 如果时第一次添加流动性,铸造L = sqrt(x * y) 单位的LP（流动性提供者）代币;
            liquidity = sqrt(amount0Desired * amount1Desired);
        }else {
            // 如果不是第一次添加流动性，按照添加代币的数量比例铸造LP，取两个代币更小的那个比例
            liquidity = min(amount0Desired * _totalSupply / reserve0, amount1Desired * _totalSupply / reserve1);
        }

        // 检查铸造的LP数量
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        // 更新储备量
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
        // 给流动性提供者铸造LP代币，代币其提供的流动性的份额
        _mint(msg.sender, liquidity);

        // 释放事件
        emit Mint(msg.sender, amount0Desired, amount1Desired);

    }


    //移除流动性，销毁LP，转出代币
    // 转出数量= (liquidity / totalSupply) * reserve
    // @param liquidity 移除的流动性数量
     function removeLiquidity(uint liquidity) external returns(uint amount0, uint amount1) {
        // 获取余额
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        // 按照LP比例计算要转出的代币数量
        uint _totalSupply = totalSupply();
        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;

        // 检查代币数量
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        // 销毁LP代币
        _burn(msg.sender, liquidity);

        // 转出代币
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        // 更新储备量
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Burn(msg.sender, amount0, amount1);
        
    }

    // 给定一个资产的数量和代币对的储备，计算交换另一个代币的数量
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns(uint amountOut) {
        require(amountIn > 0, "INSUFFICIENT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        amountOut = amountIn * reserveOut / (reserveIn + amountIn);
    }


    // swap 代币
    // @param amountIn 用于交换的代币数量
    // @param tokenIn 用于交换的代币合约地址
    // @param amountOutMin 交换出另一种代币的最低数量
    function swap(uint amountIn, IERC20 tokenIn, uint amountOutMin) external returns (uint amountOut, IERC20 tokenOut) {
        require(amountIn > 0, "INSUFFICIEnT_OUTPUT_AMOUNT");
        require(tokenIn == token0 || tokenIn == token1 , "INVALID_TOKEN");

        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        if(tokenIn == token0) {
            // token0 换token1
            tokenOut = token1;
            // 计算能交换出的token1数量
            amountOut = getAmountOut(amountIn, balance0, balance1);
            require(amountOut > amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");

            //进行交换
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut);

        }else{
            // token1 换token0
            tokenOut = token0;
            // 计算能交换出的token1数量
            amountOut = getAmountOut(amountIn, balance1, balance0);
            require(amountOut > amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');

            // 进行交换
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut);

        }

        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Swap(msg.sender, amountIn, address(tokenIn), amountOut, address(tokenOut));


    } 

}

