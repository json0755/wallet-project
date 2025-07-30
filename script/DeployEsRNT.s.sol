// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {esRNT} from "../src/esRNT.sol";

contract DeployEsRNTScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        esRNT esrnt = new esRNT();
        
        console.log("esRNT deployed to:", address(esrnt));

        vm.stopBroadcast();
    }
}