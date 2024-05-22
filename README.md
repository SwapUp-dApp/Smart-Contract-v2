## Reference for the contracts

### swap contracts

#### BASE sepolia testnet

https://sepolia.basescan.org/address/0xA0D8918D03766f539dF2de9Be3dA62Cae5B421a4#code

#### Sepolia ETH testnet

https://sepolia.etherscan.io/address/0x24D2d14fFA5f4024c91Be56d5c68321c80959C7d#code

#### Polygon Amoy testnet

https://amoy.polygonscan.com/address/0x06C2F7A6792c31C3B551582D20FD525ac38adC15#code

## SCRIPTS

### migrate script:

npm run migrate:base-sepolia

the script above will recompile/rebuild the contracts in order to get the relevant build files, after that it should start the blockchain (currently testnet) deployment
if the deployment didn't start you should check the console to identify the error message

### generate swap up contract output

npm run generate-swapup-output

generate SwapUp contract for verifying it on testnet
