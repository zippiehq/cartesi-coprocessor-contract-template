//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../src/CoprocessorCaller.sol";

contract CoprocessorCallerSample is CoprocessorCaller {
    constructor(
        address _coprocessorAddress,
        bytes32 _machineHash
    ) CoprocessorCaller(_coprocessorAddress, _machineHash) {}

    function handleNotice(bytes calldata notice) internal override {
        bytes memory rawPayload = abi.decode(notice, (bytes));

        address destination;
        bytes memory decodedPayload;

        (destination, decodedPayload) = abi.decode(
            rawPayload,
            (address, bytes)
        );

        bool success;
        bytes memory returndata;

        (success, returndata) = destination.call(decodedPayload);
    }
}
