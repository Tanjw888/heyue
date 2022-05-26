//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./lib/IBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/Callable.sol";

// adam 账户合约
contract AdamAccount is Callable {

    mapping(address => uint) private _actives;
    mapping(address => address) private _parent;

    IBEP20 USDT_TOKEN;
    uint private EFFECTIVE_OFFSET = 365 * 86400;
    uint private ACTIVE_FEE = 55 * (10 ** 18);

    //激活收U地址
    address private _recipient;

    event Active(address indexed account, uint from, uint to);
    event Bind(address indexed account, address indexed parent, uint timestamp);

    //address USDT = 0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684;        //test-net
    //address USDT = 0x55d398326f99059fF775485246999027B3197955;        //main-net
    //address USDT = 0x3eaf62Ee6a032249E3BC532DbD75E1261e987329;        //my-usdt
    constructor(address usdt, address rec){
        USDT_TOKEN = IBEP20(usdt);
        _recipient = rec;

        _parent[address(this)] = address(0);
        _parent[msg.sender] = address(this);

        emit Bind(address(this), address(0), block.timestamp);
        emit Bind(msg.sender, address(this), block.timestamp);
    }

    //账户信息，返回 [上级地址，账户到期时间]
    function info(address sender) view external returns (address, uint){
        return (_parent[sender], _actives[sender]);
    }

    //绑定用户关系，只能绑定一次
    function bind(address parent) external {
        _bind(msg.sender, parent);
    }

    //管理员绑定
    function bind(address account, address parent) external onlyPermitted() returns (bool) {
        if (_parent[account] != address(0)) {
            return false;
        }
        _bind(account, parent);
        return true;
    }

    //激活账户，需要每年激活一次
    function active() external {
        address sender = msg.sender;
        uint timestamp = block.timestamp;

        require(timestamp > _actives[sender], "Activated");

        require(USDT_TOKEN.allowance(sender, address(this)) >= ACTIVE_FEE, "Allowance not enough");
        require(USDT_TOKEN.balanceOf(sender) > ACTIVE_FEE, "Balance not enough");
        USDT_TOKEN.transferFrom(sender, _recipient, ACTIVE_FEE);

        _actives[sender] = timestamp + EFFECTIVE_OFFSET;
        emit Active(sender, timestamp, timestamp + EFFECTIVE_OFFSET);
    }

    //管理员激活
    function active(address account, uint time) external onlyPermitted() {
        _actives[account] = time;
        emit Active(account, 0, time);
    }

    //修改激活费用，激活有效期，收币地址
    function updateConfig(uint offset, uint fee, address rec) external onlyPermitted() {
        EFFECTIVE_OFFSET = offset;
        ACTIVE_FEE = fee;
        _recipient = rec;
    }

    //修改激活币种
    function changeCoin(address token) external onlyPermitted() {
        USDT_TOKEN = IBEP20(token);
    }

    function _bind(address sender, address parent) internal {
        require(parent != address(0), "Parent: Zero address");
        require(_parent[parent] != address(0), "Parent: Invalid");
        require(_parent[sender] == address(0), "Sender: Bind already");
        _parent[sender] = parent;
        emit Bind(sender, parent, block.timestamp);
    }

}
