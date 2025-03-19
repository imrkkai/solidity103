// 时间锁
// 时间锁（Timelock）是银行金库和其他高安全性容器中常见的锁定机制。它是一种计时器，旨在防止保险箱或保险库在预设时间之前被打开，即便开锁的人知道正确密码。

// 在区块链，时间锁被DeFi和DAO大量采用。它是一段代码，他可以将智能合约的某些功能锁定一段时间。它可以大大改善智能合约的安全性，举个例子，假如一个黑客黑了Uniswap的多签，准备提走金库的钱，但金库合约加了2天锁定期的时间锁，那么黑客从创建提钱的交易，到实际把钱提走，需要2天的等待期。在这一段时间，项目方可以找应对办法，投资者可以提前抛售代币减少损失。




// 时间锁合约

// 我们介绍一下时间锁Timelock合约。它的逻辑并不复杂：

//  - 在创建Timelock合约时，项目方可以设定锁定期，并把合约的管理员设为自己。
//  - 时间锁主要有三个功能：
//     -- 创建交易，并加入到时间锁队列。
//     -- 在交易的锁定期满后，执行交易。
//     -- 后悔了，取消时间锁队列中的某些交易。
//  - 项目方一般会把时间锁合约设为重要合约的管理员，例如金库合约，再通过时间锁操作他们。
//  - 时间锁合约的管理员一般为项目的多签钱包，保证去中心化。


// 事件
// Timelock合约中共有4个事件。
// - QueueTransaction：交易创建并进入时间锁队列的事件。
// - ExecuteTransaction: 锁定期满后交易执行的事件。
// - CancelTransaction: 交易取消事件
// - NewAdmin：修改管理员地址的事件。


// 状态变量
// Timelock合约中共有4个状态变量。
// - admin: 管理员地址
// - delay: 锁定期
// - GRACE_PERIOD: 宽限期，如果交易到了执行的时间点，但在GRACE_PERIOD没有被执行，就会过期。
// - queuedTransactions: 进入时间锁队列交易的标识符txHash到bool的映射, 记录所有在时间锁队列中的交易

// 修饰器
// Timelock合约中共有2个modifier。
// - onlyOwner()：被修饰的函数只能被管理员执行。
// - onlyTimelock()：被修饰的函数只能被时间锁合约执行。


// 函数

// Timelock合约中共有7个函数。
// 构造函数：初始化交易锁定时间（秒）和管理员地址。

//queueTransaction()：创建交易并添加到时间锁队列中。参数比较复杂，因为要描述一个完整的交易：
// - target: 目标合约地址
// - value: 发送ETH数额
// - signature: 调用函数的签名（function signature）
// - data: 交易的call data
// - executeTime: 交易执行的区块链时间戳

// 调用这个函数时，要保证交易预计执行的时间executeTime大于当前区块链的时间戳+锁定时间delay。
// 交易的唯一标识符为所有参数的哈希值，利用getTxHash()函数计算。进入队列的交易会更新queuedTransactions变量中，并释放QueueTransaction事件


// executeTransaction()：执行交易。它的参数与queueTransaction()相同。
// 要求被执行的交易在时间锁队列中，达到交易的执行时间，且没有过期。
// 执行交易时用到了solidity的低级成员函数call，在第22讲中有介绍。

// cancelTransaction()：取消交易。它的参数与queueTransaction()相同。
// 它要求被取消的交易在队列中，会更新queuedTransactions并释放CancelTransaction事件。

// changeAdmin()：修改管理员地址，只能被Timelock合约调用。

//getBlockTimestamp()：获取当前区块链时间戳。

// getTxHash()：返回交易的标识符，为很多交易参数的hash。




contract TimeLock {
    // 交易取消事件
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value, 
        string signature,
        bytes data, uint executeTime
    );

    // 交易执行事件
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data,
        uint executeTime
    );

    // 交易创建并进入队列事件
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed  target,
        uint value,
        string signature,
        bytes data,
        uint executeTime
    );

    // 修改管理员地址
    event NewAdmin(address indexed newAdmin);




    address public admin; // 管理员地址
    uint public constant GRACE_PERIOD = 7 days; // 交易宽限期
    uint public delay; // 交易锁定时间（秒）
    mapping(bytes32 => bool) public queuedTransactions; // txHash到bool的映射



    // onlyOwner 修饰器
    modifier onlyOwner() {
        require(msg.sender == admin, "TimeLock: caller not admin");
        _;
    }

    // onlyTimelock 修饰器
    modifier  onlyTimelock() {
        require(msg.sender == address(this), "Timelock: caller not Timelock");
        _;
    }


    /**
    *@dev 构造函数，初始化交易锁定时间（秒）和管理员地址
    */
    constructor(uint _delay) {
        delay = _delay;
        admin = msg.sender;
    }

    /**
    *@dev 改变管理员地址，调用者必须是Timelock合约。
    */
    function changeAdmin(address newAdmin) public onlyTimelock {
        admin = newAdmin;
        emit NewAdmin(newAdmin);
    }

    function getBlockTimestamp() public  view returns(uint256) {
        return block.timestamp;
    }

    /**
     * @dev 创建交易并添加到时间锁队列中。
     * @param target: 目标合约地址
     * @param value: 发送eth数额
     * @param signature: 要调用的函数签名（function signature）
     * @param data: call data，里面是一些参数
     * @param executeTime: 交易执行的区块链时间戳
     *
     * 要求：executeTime 大于 当前区块链时间戳+delay
     */
    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 executeTime) public onlyOwner returns (bytes32) {
        // 检查交易时间满足锁定时间
        require(executeTime > getBlockTimestamp() + delay, "Timelock::queueTransaction: Estimated execution time must satisfy delay.");
        // 计算交易唯一的识别符
        bytes32 txHash = getTxHash(target, value, signature, data, executeTime);
        // 将交易加入到时间锁队列中
        queuedTransactions[txHash] = true;

        // 发布事件
        emit QueueTransaction(txHash, target, value, signature, data, executeTime);
        return txHash;
    }


    /**
     * @dev 取消特定交易。
     *
     * 要求：交易在时间锁队列中
     */
    function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 executeTime) public onlyOwner{
        // 计算交易标识符
        bytes32 txHash = getTxHash(target, value, signature, data, executeTime);
        // 需要交易在时间锁队列中
        require(queuedTransactions[txHash], "Timelock::cancelTransaction Transaction hasn't been queued.");
        // 取消交易，将交易从队列中剔除
        queuedTransactions[txHash] = false;

        // 发布取消事件
        emit CancelTransaction(txHash, target, value, signature, data, executeTime);

    }


    function executeTransaction(
        address target, 
        uint256 value, 
        string memory signature,
        bytes memory data,
        uint256 executeTime
    ) public payable  onlyOwner returns(bytes memory){

        // 计算交易标识符
        bytes32 txHash = getTxHash(target, value, signature, data, executeTime);
        // 需要交易已经在队列中
        require(queuedTransactions[txHash], "Timelock::executeTransaction Transaction hasn't been queued");
        // 校验交易时间已达到锁定期
        require(getBlockTimestamp() >= executeTime, "Timelock::executeTransaction hasn't surpassed timelock");
        // 检查交易未过期
        require(getBlockTimestamp() <= executeTime + GRACE_PERIOD, "Timelock::executeTransaction: Transaction is stale.");

        // 将交易移出队列
        queuedTransactions[txHash] = false;

        // 获取calldata
        bytes memory callData;

        if(bytes(signature).length == 0) {
            callData = data;
        }else{
            // selector + data
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // 利用call执行交易
        (bool success, bytes memory returnData) = target.call{value: value}(callData);

        // 检查交易成功
        require(success, "Timelock::executeTransaction: Transacation execution reverted");

        // 发布执行事件
        emit ExecuteTransaction(txHash, target, value, signature, data, executeTime);

        return returnData;
    }

    function getTxHash(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint executeTime
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(target, value, signature, data, executeTime)
        );
    }

}


// 部署演示

// 部署合约

// 1.尝试调用changeAdmin // 报错

// 2.构建更改管理员的交易
//为了构造交易，我们要分别填入以下参数： address target, uint256 value, string memory signature, bytes memory data, uint256 executeTime

// target: 因为调用的是Timelock自己的函数，填入合约地址。
// value: 不用传入ETH, 所以这里填0
// signature: changeAdmin()的函数签名为: changeAdmin(address)

// data: 这里填要传入的参数, 也就是新管理员的地址
// 但需要把地址填充为32字节的数据, 以满足以太坊ABI编码标准
// 可以使用可以使用hashex网站进行参数的ABI编码
// https://abi.hashex.org/

//编码前：0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
//编码后: 0x000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2

// executeTime: 执行时间，先调用getBlockTimestamp（）获取到当前区块链的时间戳，
// 再在其基础加上个150秒

// 3.调用queueTransaction，将交易放入时间锁队列。

// 4. 在锁定期内调用executeTransaction，调用失败。


// 5. 在锁定期满调用executeTransaction，交易成功。


// 6. 查看新的admin地址。

//时间锁可以将智能合约的某些功能锁定一段时间，
// 大大减少项目方rug pull和黑客攻击的机会，增加去中心化应用的安全性。它被DeFi和DAO大量采用，
//其中包括Uniswap和Compound。你投资的项目有使用时间锁吗？