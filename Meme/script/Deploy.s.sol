// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MemeFactory
        MemeFactory factory = new MemeFactory();
        
        console.log("=== Meme Factory Deployment Complete ===");
        console.log("MemeFactory deployed at:", address(factory));
        console.log("Owner:", factory.owner());
        console.log("Platform Fee:", factory.PLATFORM_FEE_BPS(), "basis points (5%)");
        console.log("Uniswap Router:", address(factory.UNISWAP_ROUTER()));
        console.log("Uniswap Factory:", address(factory.UNISWAP_FACTORY()));
        console.log("WETH Address:", factory.WETH());
        console.log("Contract Paused:", factory.paused());
        
        vm.stopBroadcast();
    }
}