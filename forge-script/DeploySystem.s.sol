// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/verifiers/V4QuoteVerifier.sol";
import "../contracts/PCCSRouter.sol";
import {RiscZeroGroth16Verifier} from "risc0/groth16/RiscZeroGroth16Verifier.sol";
import "../contracts/ZK8sVerifier.sol";

contract DeploySystem is Script {
    uint256 deployerKey = uint256(vm.envBytes32("PRIVATE_KEY"));
    address enclaveIdDaoAddr = vm.envAddress("ENCLAVE_ID_DAO");
    address enclaveIdHelperAddr = vm.envAddress("ENCLAVE_IDENTITY_HELPER");
    address pckHelperAddr = vm.envAddress("X509_HELPER");
    address tcbDaoAddr = vm.envAddress("FMSPC_TCB_DAO");
    address tcbHelperAddr = vm.envAddress("FMSPC_TCB_HELPER");
    address crlHelperAddr = vm.envAddress("X509_CRL_HELPER");
    address pcsDaoAddr = vm.envAddress("PCS_DAO");
    address pckDaoAddr = vm.envAddress("PCK_DAO");
    bytes32 riscZeroImageId = vm.envBytes32("DCAP_IMAGE_ID");

    bytes32 public constant CONTROL_ROOT = hex"a516a057c9fbf5629106300934d48e0e775d4230e41e503347cad96fcbde7e2e";
    // NOTE: This has opposite byte order to the value in the risc0 repository.
    bytes32 public constant BN254_CONTROL_ID = hex"0eb6febcf06c5df079111be116f79bd8c7e85dc9448776ef9a59aaf2624ab551";

    RiscZeroGroth16Verifier riscZeroVerifier;

    function run() public {
        vm.broadcast(deployerKey);

        PCCSRouter router =
            new PCCSRouter(enclaveIdDaoAddr, tcbDaoAddr, pcsDaoAddr, pckDaoAddr, pckHelperAddr, crlHelperAddr);
        console2.log("Deployed PCCSRouter to", address(router));

        V4QuoteVerifier verifier = new V4QuoteVerifier(address(router));
        console.log("V4QuoteVerifier deployed at ", address(verifier));

        riscZeroVerifier = new RiscZeroGroth16Verifier(CONTROL_ROOT, BN254_CONTROL_ID);
        console2.log("Deployed RiscZeroGroth16Verifier to", address(riscZeroVerifier));

        ZK8SVerifier zk8sVerifier = new ZK8SVerifier(address(riscZeroVerifier), riscZeroImageId);
        console.log("ZK8sVerifier deployed at: ", address(zk8sVerifier));

        vm.stopBroadcast();
    }
}
