// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // 指定Solidity编译器版本

import "@openzeppelin/contracts/utils/Address.sol"; // 导入OpenZeppelin的Address工具库
import "@openzeppelin/contracts/utils/Context.sol"; // 导入OpenZeppelin的Context工具库
import "@openzeppelin/contracts/utils/Strings.sol"; // 导入OpenZeppelin的Strings工具库
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol"; // 导入ERC721接收者接口

contract BaseERC721 {
    using Strings for uint256; // 使用Strings库扩展uint256
    using Address for address; // 使用Address库扩展address

    // Token name
    string private _name; // 代币名称

    // Token symbol
    string private _symbol; // 代币符号

    // Token baseURI
    string private _baseURI; // 代币基础URI

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners; // tokenId到拥有者地址的映射

    // Mapping owner address to token count
    mapping(address => uint256) private _balances; // 拥有者地址到其持有token数量的映射

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals; // tokenId到被授权地址的映射

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals; // 拥有者到操作员的授权映射

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from, // 转出地址
        address indexed to,   // 转入地址
        uint256 indexed tokenId // 转移的tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner, // 拥有者地址
        address indexed approved, // 被授权地址
        uint256 indexed tokenId // 授权的tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner, // 拥有者地址
        address indexed operator, // 操作员地址
        bool approved // 是否授权
    );

    /**
     * @dev Initializes the contract by setting a `name`, a `symbol` and a `baseURI` to the token collection.
     */
    constructor(
        string memory name_, // 代币名称
        string memory symbol_, // 代币符号
        string memory baseURI_ // 代币基础URI
    ) {
        _name = name_; // 初始化名称
        _symbol = symbol_; // 初始化符号
        _baseURI = baseURI_; // 初始化基础URI
    }

    /**
     * @dev 判断合约是否支持某接口
     */
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f;   // ERC165 Interface ID for ERC721Metadata
    }
    
    /**
     * @dev 获取代币名称
     */
    function name() public view returns (string memory) {
        return _name; // 返回代币名称
    }

    /**
     * @dev 获取代币符号
     */
    function symbol() public view returns (string memory) {
        return _symbol; // 返回代币符号
    }

    /**
     * @dev 获取指定tokenId的URI
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token"); // 检查token是否存在
        return _baseURI; // 返回基础URI
    }

    /**
     * @dev 铸造新的NFT
     * @param to 接收者地址
     * @param tokenId 新NFT的ID
     */
    function mint(address to, uint256 tokenId) public {
        require(to != address(0), "ERC721: mint to the zero address"); // 不能铸造到0地址
        require(!_exists(tokenId), "ERC721: token already minted"); // tokenId不能已存在
        _owners[tokenId] = to; // 记录拥有者
        _balances[to] += 1; // 拥有者余额+1
        emit Transfer(address(0), to, tokenId); // 触发转移事件（铸造）
    }

    /**
     * @dev 查询某地址拥有的NFT数量
     * @param owner 拥有者地址
     * @return 拥有的NFT数量
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address"); // 不能查询0地址
        return _balances[owner]; // 返回余额
    }

    /**
     * @dev 查询某tokenId的拥有者
     * @param tokenId NFT的ID
     * @return 拥有者地址
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId]; // 获取拥有者
        require(owner != address(0), "ERC721: owner query for nonexistent token"); // 必须存在
        return owner; // 返回拥有者
    }

    /**
     * @dev 授权某地址可操作指定tokenId
     * @param to 被授权地址
     * @param tokenId NFT的ID
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId); // 获取token拥有者
        require(to != owner, "ERC721: approval to current owner"); // 不能授权给自己
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender), // 必须是拥有者或被授权操作员
            "ERC721: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId); // 内部授权
    }

    /**
     * @dev 查询某tokenId的被授权地址
     * @param tokenId NFT的ID
     * @return 被授权地址
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token"); // token必须存在
        return _tokenApprovals[tokenId]; // 返回被授权地址
    }

    /**
     * @dev 设置/取消操作员授权
     * @param operator 操作员地址
     * @param approved 是否授权
     */
    function setApprovalForAll(address operator, bool approved) public {
        address sender = msg.sender; // 获取调用者
        require(operator != sender, "ERC721: approve to caller"); // 不能授权给自己
        _operatorApprovals[sender][operator] = approved; // 设置授权
        emit ApprovalForAll(sender, operator, approved); // 触发事件
    }

    /**
     * @dev 查询操作员是否被授权
     * @param owner 拥有者地址
     * @param operator 操作员地址
     * @return 是否被授权
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view returns (bool) {
        return _operatorApprovals[owner][operator]; // 查询是否被授权
    }

    /**
     * @dev 普通转账（需权限）
     * @param from 转出地址
     * @param to 转入地址
     * @param tokenId NFT的ID
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(
            _isApprovedOrOwner(msg.sender, tokenId), // 必须是拥有者或被授权者
            "ERC721: transfer caller is not owner nor approved"
        );
        _transfer(from, to, tokenId); // 内部转账
    }

    /**
     * @dev 安全转账（无data）
     * @param from 转出地址
     * @param to 转入地址
     * @param tokenId NFT的ID
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, ""); // 调用带data的安全转账
    }

    /**
     * @dev 安全转账（带data）
     * @param from 转出地址
     * @param to 转入地址
     * @param tokenId NFT的ID
     * @param _data 附加数据
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public {
        require(
            _isApprovedOrOwner(msg.sender, tokenId), // 必须是拥有者或被授权者
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data); // 内部安全转账
    }

    /**
     * @dev 安全转账，检查目标是否支持ERC721
     * @param from 转出地址
     * @param to 转入地址
     * @param tokenId NFT的ID
     * @param _data 附加数据
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _transfer(from, to, tokenId); // 内部转账
        require(
            _checkOnERC721Received(from, to, tokenId, _data), // 检查目标是否实现了IERC721Receiver
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev 判断tokenId是否存在
     * @param tokenId NFT的ID
     * @return 是否存在
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0); // 判断token是否存在
    }

    /**
     * @dev 判断spender是否有权操作tokenId
     * @param spender 操作地址
     * @param tokenId NFT的ID
     * @return 是否有权
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token"); // token必须存在
        address owner = ownerOf(tokenId); // 获取拥有者
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender)); // 判断是否有权限
    }

    /**
     * @dev 转移NFT（不检查msg.sender权限）
     * @param from 转出地址
     * @param to 转入地址
     * @param tokenId NFT的ID
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner"); // 必须是拥有者
        require(to != address(0), "ERC721: transfer to the zero address"); // 不能转给0地址
        // Clear approvals from the previous owner
        _approve(address(0), tokenId); // 清除之前的授权
        _balances[from] -= 1; // 发送方余额-1
        _balances[to] += 1; // 接收方余额+1
        _owners[tokenId] = to; // 更新拥有者
        emit Transfer(from, to, tokenId); // 触发转移事件
    }

    /**
     * @dev 内部授权函数
     * @param to 被授权地址
     * @param tokenId NFT的ID
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to; // 设置授权
        emit Approval(ownerOf(tokenId), to, tokenId); // 触发授权事件
    }

    /**
     * @dev 判断合约是否为合约地址
     * @param account 要判断的地址
     * @return 是否为合约
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev 检查目标地址是否为合约且实现了IERC721Receiver
     * @param from 之前的拥有者
     * @param to 目标地址
     * @param tokenId NFT的ID
     * @param _data 附加数据
     * @return 是否支持ERC721Receiver
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (isContract(to)) { // 如果目标是合约
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender, // 操作发起者
                    from, // 之前的拥有者
                    tokenId, // tokenId
                    _data // 附加数据
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector; // 检查返回值
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true; // 不是合约直接返回true
        }
    }
}

contract BaseERC721Receiver is IERC721Receiver {
    constructor() {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector; // 返回选择器，表示支持接收ERC721
    }
}