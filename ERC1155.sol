
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "IERC1155.sol";
import "IERC1155Receiver.sol";
import "IERC1155MetadataURI.sol";

import "Strings.sol";
import "IERC165.sol";


//ERC1155标准
// 它支持一个合约包含多种代币。
// 不论是ERC20还是ERC721标准，每个合约都对应一个独立的代币。
// 假设我们要在以太坊上打造一个类似《魔兽世界》的大型游戏，这需要我们对每个装备都部署一个合约。
// 上千种装备就要部署和管理上千个合约，这非常麻烦。

//因此，以太坊EIP1155提出了一个多代币标准ERC1155，允许一个合约包含多个同质化和非同质化代币。ERC1155在GameFi应用最多，Decentraland、Sandbox等知名链游都使用它。

//简单来说，ERC1155与之前介绍的非同质化代币标准ERC721类似：在ERC721中，每个代币都有一个tokenId作为唯一标识，每个tokenId只对应一个代币；而在ERC1155中，每一种代币都有一个id作为唯一标识，每个id对应一种代币。这样，代币种类就可以非同质的在同一个合约里管理了，并且每种代币都有一个网址uri来存储它的元数据，类似ERC721的tokenURI。下面是ERC1155的元数据接口合约IERC1155MetadataURI：


// 那么怎么区分ERC1155中的某类代币是同质化还是非同质化代币呢？
// 其实很简单：如果某个id对应的代币总量为1，那么它就是非同质化代币，类似ERC721；
// 如果某个id对应的代币总量大于1，那么他就是同质化代币，因为这些代币都分享同一个id，类似ERC20。


// IERC1155接口合约
// IERC1155接口合约抽象了EIP1155需要实现的功能，其中包含4个事件和6个函数。与ERC721不同，因为ERC1155包含多类代币，它实现了批量转账和批量余额查询，一次操作多种代币。

// IERC1155事件
// TransferSingle事件：单类代币转账事件，在单币种转账时释放。
// TransferBatch事件：批量代币转账事件，在多币种转账时释放。
// ApprovalForAll事件：批量授权事件，在批量授权时释放。
// URI事件：元数据地址变更事件，在uri变化时释放。


// IERC1155函数

// balanceOf()：单币种余额查询，返回account拥有的id种类的代币的持仓量。
// balanceOfBatch()：多币种余额查询，查询的地址accounts数组和代币种类ids数组的长度要相等。
// setApprovalForAll()：批量授权，将调用者的代币授权给operator地址。。
// isApprovedForAll()：查询批量授权信息，如果授权地址operator被account授权，则返回true。
// safeTransferFrom()：安全单币转账，将amount单位id种类的代币从from地址转账给to地址。如果to地址是合约，则会验证是否实现了onERC1155Received()接收函数。
// safeBatchTransferFrom()：安全多币转账，与单币转账类似，只不过转账数量amounts和代币种类ids变为数组，且长度相等。如果to地址是合约，则会验证是否实现了onERC1155BatchReceived()接收函数。



// IERC1155MetadataURI 元数据合约
// ERC1155的可选接口，加入了uri()函数查询元数据

// ERC1155接收合约
// 与ERC721标准类似，为了避免代币被转入黑洞合约，ERC1155要求代币接收合约继承IERC1155Receiver并实现两个接收函数：

//  onERC1155Received()：单币转账接收函数，接受ERC1155安全转账safeTransferFrom 需要实现并返回自己的选择器0xf23a6e61。
//  onERC1155BatchReceived()：多币转账接收函数，接受ERC1155安全多币转账safeBatchTransferFrom 需要实现并返回自己的选择器0xbc197c81。


// ERC1155 主合约
// ERC1155主合约实现了IERC1155接口合约规定的函数，还有单币/多币的铸造和销毁函数。

// ERC1155变量

// ERC1155主合约包含4个状态变量：

// name：代币名称
// symbol：代币代号

// _balances：代币持仓映射，记录代币种类id下某地址account的持仓量balances。

// _operatorApprovals：批量授权映射，记录持有地址给另一个地址的授权情况。

// ERC1155函数

// ERC1155主合约包含16个函数：
// 构造函数：初始化状态变量name和symbol。

// supportsInterface()：实现ERC165标准，声明它支持的接口，供其他合约检查。
// balanceOf()：实现IERC1155的balanceOf()，查询持仓量。与ERC721标准不同，这里需要输入查询的持仓地址account以及币种id。

// balanceOfBatch()：实现IERC1155的balanceOfBatch()，批量查询持仓量。
// setApprovalForAll()：实现IERC1155的setApprovalForAll()，批量授权，释放ApprovalForAll事件。
// isApprovedForAll()：实现IERC1155的isApprovedForAll()，查询批量授权信息。

// safeTransferFrom()：实现IERC1155的safeTransferFrom()，单币种安全转账，释放TransferSingle事件。与ERC721不同，这里不仅需要填发出方from，接收方to，代币种类id，还需要填转账数额amount。

// safeBatchTransferFrom()：实现IERC1155的safeBatchTransferFrom()，多币种安全转账，释放TransferBatch事件。


// _mint()：单币种铸造函数。
// _mintBatch()：多币种铸造函数。
// _burn()：单币种销毁函数。
// _burnBatch()：多币种销毁函数。

// _doSafeTransferAcceptanceCheck：单币种转账的安全检查，被safeTransferFrom()调用，确保接收方为合约的情况下，实现了onERC1155Received()函数。


// _doSafeBatchTransferAcceptanceCheck：多币种转账的安全检查，，被safeBatchTransferFrom调用，确保接收方为合约的情况下，实现了onERC1155BatchReceived()函数。

// uri()：返回ERC1155的第id种代币存储元数据的网址，类似ERC721的tokenURI。

// baseURI()：返回baseURI，uri就是把baseURI和id拼接在一起，需要开发重写。


/**
 * @dev ERC1155多代币标准
 * 见 https://eips.ethereum.org/EIPS/eip-1155
 */
contract ERC1155 is IERC165, IERC1155, IERC1155MetadataURI {
    //using Address for address; // 使用Address库，用isContract来判断地址是否为合约
    using Strings for uint256; // 使用Strings库
    // Token名称
    string public name;
    // Token代号
    string public symbol;
    // 代币种类id 到 账户account 到 余额balances 的映射
    mapping(uint256 => mapping(address => uint256)) private _balances;
    // address 到 授权地址 的批量授权映射
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * 构造函数，初始化`name` 和`symbol`, uri_
     */
    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 持仓查询 实现IERC1155的balanceOf，返回account地址的id种类代币持仓量。
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    /**
     * @dev 批量持仓查询
     * 要求:
     * - `accounts` 和 `ids` 数组长度相等.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public view virtual override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    /**
     * @dev 批量授权，调用者授权operator使用其所有代币
     * 释放{ApprovalForAll}事件
     * 条件：msg.sender != operator
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(msg.sender != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev 查询批量授权.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev 安全转账，将`amount`单位的`id`种类代币从`from`转账到`to`
     * 释放 {TransferSingle} 事件.
     * 要求:
     * - to 不能是0地址.
     * - from拥有足够的持仓量，且调用者拥有授权
     * - 如果 to 是智能合约, 他必须支持 IERC1155Receiver-onERC1155Received.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        address operator = msg.sender;
        // 调用者是持有者或是被授权
        require(
            from == operator || isApprovedForAll(from, operator),
            "ERC1155: caller is not token owner nor approved"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");
        // from地址有足够持仓
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        // 更新持仓量
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        // 释放事件
        emit TransferSingle(operator, from, to, id, amount);
        // 安全检查
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);    
    }

    /**
     * @dev 批量安全转账，将`amounts`数组单位的`ids`数组种类代币从`from`转账到`to`
     * 释放 {TransferSingle} 事件.
     * 要求:
     * - to 不能是0地址.
     * - from拥有足够的持仓量，且调用者拥有授权
     * - 如果 to 是智能合约, 他必须支持 IERC1155Receiver-onERC1155BatchReceived.
     * - ids和amounts数组长度相等
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        address operator = msg.sender;
        // 调用者是持有者或是被授权
        require(
            from == operator || isApprovedForAll(from, operator),
            "ERC1155: caller is not token owner nor approved"
        );
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        // 通过for循环更新持仓  
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);
        // 安全检查
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);    
    }

    /**
     * @dev 铸造
     * 释放 {TransferSingle} 事件.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = msg.sender;

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev 批量铸造
     * 释放 {TransferBatch} 事件.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev 销毁
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = msg.sender;

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    /**
     * @dev 批量销毁
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    // @dev ERC1155的安全转账检查
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0 /*to.isContract()*/) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    // @dev ERC1155的批量安全转账检查
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0 /*to.isContract() */) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @dev 返回ERC1155的id种类代币的uri，存储metadata，类似ERC721的tokenURI.
     */
    function uri(uint256 id) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, id.toString())) : "";
    }

    /**
     * 计算{uri}的BaseURI，uri就是把baseURI和tokenId拼接在一起，需要开发重写.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
}