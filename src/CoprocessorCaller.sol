// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@cartesi-coprocessor/ICoprocessor.sol";
import "@cartesi-coprocessor/ICoprocessorCallback.sol";

abstract contract CoprocessorCaller is ICoprocessorCallback {
    ICoprocessor public coprocessor;
    bytes32 public machineHash;

    error UnauthorizedCaller(address caller);
    error InvalidOutputLength(uint256 length);
    error ComputationNotFound(bytes32 payloadHash);
    error MachineHashMismatch(bytes32 current, bytes32 expected);
    error InvalidOutputSelector(bytes4 selector, bytes4 expected);

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

    function handleNotice(bytes calldata notice) internal virtual {}

    function coprocessorCallbackOutputsOnly(
        bytes32 _machineHash,
        bytes32 _payloadHash,
        bytes[] calldata outputs
    ) external override {
        if (msg.sender != address(coprocessor)) {
            revert UnauthorizedCaller(msg.sender);
        }

        if (_machineHash != machineHash) {
            revert MachineHashMismatch(_machineHash, machineHash);
        }

        if (!computationSent[_payloadHash]) {
            revert ComputationNotFound(_payloadHash);
        }

        for (uint256 i = 0; i < outputs.length; i++) {
            bytes calldata output = outputs[i];

            if (output.length <= 3) {
                revert InvalidOutputLength(output.length);
            }

            bytes4 selector = bytes4(output[:4]);
            bytes calldata arguments = output[4:];

            if (selector != ICoprocessorOutputs.Notice.selector) {
                revert InvalidOutputSelector(
                    selector,
                    ICoprocessorOutputs.Notice.selector
                );
            }

            handleNotice(arguments);
        }

        delete computationSent[_payloadHash];
    }
}
