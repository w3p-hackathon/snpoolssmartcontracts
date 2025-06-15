// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract EventEmitter {
    event metricsAvailiable(bytes32 proof, bytes32[3] metrics);

    function emitMetricAvailiable(
        bytes32 proof,
        bytes32[3] memory metrics
    ) public {
        emit metricsAvailiable(proof, metrics);
    }
}
