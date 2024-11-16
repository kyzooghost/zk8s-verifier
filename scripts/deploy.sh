#!/bin/bash

# Get current environment variables defined in .env
source .env
echo "Running deploy script"
forge script forge-script/DeploySystem.s.sol:DeploySystem --ffi --rpc-url $RPC_URL --slow --broadcast --verify -vvvv --via-ir