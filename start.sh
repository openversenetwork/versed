HOMEDIR="$HOME/.versed"
# to trace evm
#TRACE="--trace"
TRACE=""
LOGLEVEL="info"
# Start the node (remove the --pruning=nothing flag if historical queries are not needed)
versed start --metrics "$TRACE" --log_level $LOGLEVEL --minimum-gas-prices=7aenergy --json-rpc.address 0.0.0.0:8545 --json-rpc.api eth,txpool,personal,net,debug,web3 --api.enable --rpc.laddr=tcp://0.0.0.0:26657 --api.enabled-unsafe-cors --home "$HOMEDIR"
