// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title MockERC20
 * @notice 仅用于本地测试和 anvil 部署的最小化 ERC20 实现。
 * @dev `mint` 故意保持公开无权限，方便前端在 anvil 上自助领取测试代币。
 *      切勿用于任何主网或公开测试网部署。
 */
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        require(
            balanceOf[msg.sender] >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        require(
            balanceOf[from] >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        require(
            allowance[from][msg.sender] >= amount,
            "ERC20: insufficient allowance"
        );
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
