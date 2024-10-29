// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./ICoprocessor.sol";
import "./ICoprocessorCallback.sol";

contract CoprocessorCaller is ICoprocessorCallback {
    ICoprocessor public coprocessor;
    bytes32 public machineHash;
    bytes public lastResult;

    mapping(bytes32 => bool) public computationSent;

    constructor(address _coprocessorAddress, bytes32 _machineHash) {
        coprocessor = ICoprocessor(_coprocessorAddress);
        machineHash = _machineHash;
    }

    function callCoprocessor(bytes calldata input) external {
        bytes32 inputHash = keccak256(input);

        computationSent[inputHash] = true;

        coprocessor.issueTask(machineHash, input, address(this));
    }

    function handleNotice(bytes calldata notice) internal {
        emit ResultReceived(notice);
    }

    function coprocessorCallbackOutputsOnly(bytes32 _machineHash, bytes32 _payloadHash, bytes[] calldata outputs)
        external
        override
    {
        require(msg.sender == address(coprocessor), "Unauthorized caller");

        require(_machineHash == machineHash, "Machine hash mismatch");

        require(computationSent[_payloadHash] == true, "Computation not found");

        for (uint256 i = 0; i < outputs.length; i++) {
            bytes calldata output = outputs[i];

            require(output.length > 3, "Too short output");
            bytes4 selector = bytes4(output[:4]);
            bytes calldata arguments = output[4:];

            require(selector == ICoprocessorOutputs.Notice.selector);

            // can do for example (foo, bar) = abi.decode(arguments, [address, uint256]); here
            handleNotice(arguments);
        }

        // clean up the mapping
        delete computationSent[_payloadHash];
    }

    event ResultReceived(bytes output);
}
