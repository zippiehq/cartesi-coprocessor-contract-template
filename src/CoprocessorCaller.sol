// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibError} from "./library/LibError.sol";
import {ICoprocessor} from "./ICoprocessor.sol";
import {LibAddress} from "./library/LibAddress.sol";
import {ICoprocessorOutputs} from "./ICoprocessorOutputs.sol";
import {ICoprocessorCallback} from "./ICoprocessorCallback.sol";

abstract contract CoprocessorCaller is ICoprocessorCallback {
    using LibError for bytes;
    using LibAddress for address;

    bytes32 public machineHash;
    ICoprocessor public coprocessor;

    error UnauthorizedCaller(address caller);
    error InvalidOutputLength(uint256 length);
    error ComputationNotFound(bytes32 payloadHash);
    error InsufficientFunds(uint256 value, uint256 balance);
    error MachineHashMismatch(bytes32 current, bytes32 expected);
    error InvalidOutputSelector(bytes4 selector, bytes4 expected);

    mapping(bytes32 => bool) public computationSent;

    /// @notice Initializes the contract with the coprocessor address and machine hash
    /// @param _coprocessorAddress Address of the coprocessor
    /// @param _machineHash Initial machine hash
    constructor(address _coprocessorAddress, bytes32 _machineHash) {
        coprocessor = ICoprocessor(_coprocessorAddress);
        machineHash = _machineHash;
    }

    /// @notice Issues a task to the coprocessor
    /// @param input ABI-encoded input data for the coprocessor
    function callCoprocessor(bytes calldata input) external {
        bytes32 inputHash = keccak256(input);
        computationSent[inputHash] = true;
        coprocessor.issueTask(machineHash, input, address(this));
    }

    /// @notice Handles notices sent back from the coprocessor
    /// @dev This function should be overridden by child contracts to define specific behavior
    /// @param notice ABI-encoded notice data
    function handleNotice(bytes calldata notice) internal virtual {}

    /// @notice Callback function invoked by the coprocessor with computation outputs
    /// @param _machineHash The hash of the machine that processed the task
    /// @param _payloadHash The hash of the input payload
    /// @param outputs Array of ABI-encoded outputs from the coprocessor
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

            if (selector == ICoprocessorOutputs.Notice.selector) {
                handleNotice(arguments);
            } else if (selector == ICoprocessorOutputs.Voucher.selector) {
                _executeVoucher(arguments);
            } else {
                revert InvalidOutputSelector(
                    selector,
                    ICoprocessorOutputs.Notice.selector
                );
            }
        }
        delete computationSent[_payloadHash];
    }

    /// @notice Executes a voucher
    /// @dev This function decodes and executes a voucher with the specified parameters
    /// @param arguments ABI-encoded arguments containing the destination, value, and payload
    function _executeVoucher(bytes calldata arguments) internal {
        address destination;
        uint256 value;
        bytes memory payload;

        (destination, value, payload) = abi.decode(
            arguments,
            (address, uint256, bytes)
        );

        bool enoughFunds;
        uint256 balance;

        (enoughFunds, balance) = destination.safeCall(value, payload);

        if (!enoughFunds) {
            revert InsufficientFunds(value, balance);
        }
    }
}
