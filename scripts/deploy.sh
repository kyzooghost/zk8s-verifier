#!/bin/bash

# Get current environment variables defined in .env
source .env
echo "Running deploy script"
forge script forge-script/DeploySystem.s.sol:DeploySystem --ffi --rpc-url $RPC_URL --slow --broadcast -vvvv --via-ir
# forge script forge-script/DeploySystem.s.sol:DeploySystem --ffi --rpc-url $RPC_URL --slow --broadcast -vvvv --via-ir --etherscan-api-key 45165302A9B1ECF06BE78218277648FCAD --verify --verifier-url https://explorer.zircuit.com/api/contractVerifyHardhat

forge verify-contract --verifier-url https://explorer.testnet.zircuit.com/api/contractVerifyHardhat 0x7a4137fC69d2460B52c0eb85BC1B9B6aE5e781f6 contracts/ZK8SVerifier.sol:ZK8SVerifier --root . --etherscan-api-key E2AE77D62FE5DD63AD0CF03CFC97A177BE