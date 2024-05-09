## Reference for the contracts

### test NFT 721 contract:

https://sepolia.basescan.org/address/0xcbc46Dcf35A063ea7a8d1F082dD86705450bA32C#writeContract

### test ERC20 token contract:

https://sepolia.basescan.org/address/0xeD8a62Ab2305a83622d5a773C1357D92216634bB#writeContract

### test NFT 1155 contract:

https://sepolia.basescan.org/address/0x0d078ba75f28134a04dbd82ce39198fe80d62dad#writeContract

### swap contract:

https://sepolia.basescan.org/address/0xFBF75380e511835e40C448A753E775cA8740A7f4#writeContract

## SCRIPTS

### migrate script:

npm run migrate:base-sepolia

the script above will recompile/rebuild the contracts in order to get the relevant build files, after that it should start the blockchain (currently testnet) deployment
if the deployment didn't start you should check the console to identify the error message
