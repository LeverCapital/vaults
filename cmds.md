
## Forge commands

```shell
forge script ./src/test/GMX.t.sol --tc GMXTest --sig "testLongOpenPosition()" \
             -vvv --fork-url $ARB_MAIN

forge script scripts/GMX.s.sol:marketBuyOrder --rpc-url $ARB_MAIN \              
 --private-key $PRIVATE_KEY -vvvvv 

 ```


## Cast commands

```shell
export $(xargs < .env)
cast call $GMX_VAULT_MAIN "poolAmounts(address)(uint256)" 0xff970a61a04b1ca14834a43f5de4533ebddb5cc8 --rpc-url $ARB_MAIN 54022172170516
```

