//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Counter} from "./utils/Counter.sol";
import {console} from "forge-std/console.sol";
import {CoprocessorMock} from "./mock/CoprocessorMock.sol";
import {CoprocessorCallerSample} from "./utils/CoprocessorCallerSample.sol";

contract TestCoprocessorCallerSample is Test {
    address caller = vm.addr(4);

    bytes32 machineHash = bytes32(0);

    Counter counter;
    CoprocessorMock mock;
    CoprocessorCallerSample sample;

    event TaskIssued(bytes32 machineHash, bytes input, address callback);

    function setUp() public {
        counter = new Counter();
        mock = new CoprocessorMock();
        sample = new CoprocessorCallerSample(address(mock), machineHash);
    }

    function testCallCoprocessorCallerSampleWithValidInput() public {
        bytes memory encoded_tx = abi.encodeWithSignature(
            "setNumber(uint256)",
            1596
        );

        bytes memory payload = abi.encode(address(counter), encoded_tx);

        sample.callCoprocessor(payload);

        bytes memory notice = abi.encodeWithSignature("Notice(bytes)", payload);

        bytes[] memory outputs = new bytes[](1);
        outputs[0] = notice;

        vm.expectEmit();

        emit TaskIssued(machineHash, payload, address(sample));

        sample.callCoprocessor(payload);

        vm.prank(address(mock));

        sample.coprocessorCallbackOutputsOnly(
            machineHash,
            keccak256(payload),
            outputs
        );

        uint256 balance = counter.number();
        assertEq(balance, 1596);
    }

    function testCallCoprocessorCallerSampleWithInvalidMachineHash() public {
        bytes memory encoded_tx = abi.encodeWithSignature(
            "setNumber(uint256)",
            1596
        );

        bytes memory payload = abi.encode(address(counter), encoded_tx);

        sample.callCoprocessor(payload);

        bytes memory notice = abi.encodeWithSignature("Notice(bytes)", payload);

        bytes[] memory outputs = new bytes[](1);
        outputs[0] = notice;

        vm.expectEmit();

        emit TaskIssued(machineHash, payload, address(sample));

        sample.callCoprocessor(payload);

        vm.prank(address(mock));

        bytes32 invalidMachineHash = keccak256("1596");

        vm.expectRevert();

        sample.coprocessorCallbackOutputsOnly(
            invalidMachineHash,
            keccak256(payload),
            outputs
        );
    }

    function testCallCoprocessorCallerSampleWithInvalidPayloadHash() public {
        bytes memory encoded_tx = abi.encodeWithSignature(
            "setNumber(uint256)",
            1596
        );

        bytes memory payload = abi.encode(address(counter), encoded_tx);

        sample.callCoprocessor(payload);

        bytes memory notice = abi.encodeWithSignature("Notice(bytes)", payload);

        bytes[] memory outputs = new bytes[](1);
        outputs[0] = notice;

        vm.expectEmit();

        emit TaskIssued(machineHash, payload, address(sample));

        sample.callCoprocessor(payload);

        vm.prank(address(mock));

        bytes32 invalidPayloadHash = keccak256("1596");

        vm.expectRevert();

        sample.coprocessorCallbackOutputsOnly(
            machineHash,
            invalidPayloadHash,
            outputs
        );
    }
}
