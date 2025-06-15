// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {EventEmitter} from "../src/EventEmitter.sol";

contract EventEmitterScript is Script {
    EventEmitter public eventEmitter;

    function setUp() public {}

    function getChainId() public view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", getChainId());
        console.log("Deploying");
        vm.startBroadcast(deployerPrivateKey);

        eventEmitter = new EventEmitter();

        vm.stopBroadcast();
    }
}
