// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "hardhat/console.sol";

contract AntToken is ERC20, ERC20Burnable, Ownable {

    // @notice controllers means address to be able to call this contract's function.
    mapping(address => bool) controllers;

    error AntToken_OnlyControllersCanMint();

    // @notice ERC20(name, symbol)
    constructor() ERC20("My First Token", "AFT") {}

    modifier onlyController() {
        require (controllers[msg.sender], "Not authorized address!");
        _;
    }

    function mint(address to, uint256 amount) external onlyController{
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyController{
        _burn(account, amount);
    }

    function setController(address controller, bool _state) external payable onlyOwner{
        controllers[controller] = _state;
    }
}
