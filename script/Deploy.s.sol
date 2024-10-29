// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/CoprocessorCaller.sol";

contract DeployScript is Script {
    function run() external {
        // Load environment variables
        address coprocessorAddress = vm.envAddress("COPROCESSOR_ADDRESS");
        bytes32 machineHash = vm.envBytes32("MACHINE_HASH");

        vm.startBroadcast();

        // Deploy the contract
        CoprocessorCaller caller = new CoprocessorCaller(coprocessorAddress, machineHash);

        console.log("CoprocessorCaller deployed at:", address(caller));

        vm.stopBroadcast();
    }
}
