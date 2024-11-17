//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AutomataDcapAttestation } from "./AutomataDcapAttestation.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ZK8SVerifier is AutomataDcapAttestation {
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(address risc0Verifier, bytes32 imageId) AutomataDcapAttestation(risc0Verifier, imageId) {
    }

    mapping(address => EnumerableSet.UintSet) orchestratorIdsOf;
    mapping(uint256 => EnumerableSet.UintSet) workerIdsOf;
    mapping(uint256 => EnumerableSet.UintSet) taskIdsOf;

    event OrchestratorRegistered(address indexed wallet, uint256 indexed orchestratorId);
    event WorkerRegistered(address indexed wallet, uint256 indexed orchestratorId, uint256 indexed workerId);
    event TaskRegistered(address indexed wallet, uint256 indexed workerId, uint256 indexed taskId);

    // TODO - Input validation
    function registerOrchestrator(uint256 orchestratorId) public returns (uint256) {
        orchestratorIdsOf[msg.sender].add(orchestratorId);
        emit OrchestratorRegistered(msg.sender, orchestratorId);
        return orchestratorId;
    }

    function registerWorker(uint256 orchestratorId) public returns (uint256) {
        uint256 newWorkerId = uint256(
            keccak256(
                abi.encode(
                    block.timestamp, 
                    block.chainid, 
                    orchestratorId
        )));
        workerIdsOf[orchestratorId].add(newWorkerId);
        emit WorkerRegistered(msg.sender, orchestratorId, newWorkerId);
        return newWorkerId;
    }

    function registerTask(uint256 workerId) public returns (uint256) {
        uint256 newTaskId = uint256(
            keccak256(
                abi.encode(
                    block.timestamp, 
                    block.chainid, 
                    workerId
        )));
        taskIdsOf[workerId].add(newTaskId);
        emit TaskRegistered(msg.sender, workerId, newTaskId);
        return newTaskId;
    }
}