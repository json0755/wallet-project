// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/tokenbank/EIP2612TokenBank.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployTokenBank is Script {
    function run() external {
        vm.startBroadcast();

        // Sepolia Permit2 contract address
        address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        
        // Use the deployed EIP2612Token address
        address assetTokenAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        
        // Deploy TokenBank
        EIP2612TokenBank tokenBank = new EIP2612TokenBank(
            IERC20(assetTokenAddress),
            permit2Address
        );

        console2.log("TokenBank deployed at:", address(tokenBank));
        console2.log("Asset token address:", assetTokenAddress);
        console2.log("Permit2 address:", permit2Address);

        vm.stopBroadcast();
    }
}