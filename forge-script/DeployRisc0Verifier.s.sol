// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RiscZeroGroth16Verifier} from "risc0/groth16/RiscZeroGroth16Verifier.sol";

contract DeployRisc0VerifierScript is Script {
    /// ref: https://github.com/risc0/risc0-ethereum/blob/main/contracts/script/DeployVerifier.s.sol

    bytes32 public constant CONTROL_ROOT = hex"a516a057c9fbf5629106300934d48e0e775d4230e41e503347cad96fcbde7e2e";
    // NOTE: This has opposite byte order to the value in the risc0 repository.
    bytes32 public constant BN254_CONTROL_ID = hex"0eb6febcf06c5df079111be116f79bd8c7e85dc9448776ef9a59aaf2624ab551";

    RiscZeroGroth16Verifier riscZeroVerifier;

    function run() external {
        uint256 deployerKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.broadcast(deployerKey);
        riscZeroVerifier = new RiscZeroGroth16Verifier(CONTROL_ROOT, BN254_CONTROL_ID);
        console2.log("Deployed RiscZeroGroth16Verifier to", address(riscZeroVerifier));
    }
}
