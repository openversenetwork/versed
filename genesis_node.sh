#!/bin/bash

KEYS[0]="Founders"
KEYS[1]="Technology"
KEYS[2]="Foundation"
KEYS[3]="Community"

CHAINID="openverse_23617-1"
MONIKER="Genesis_Node"
# Remember to change to other types of keyring like 'file' in-case exposing to outside world,
# otherwise your balance will be wiped quickly
# The keyring test does not require private key to steal tokens from you
KEYRING="os"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"
# Set dedicated home directory for the versed instance
HOMEDIR="$HOME/.versed"
# to trace evm
#TRACE="--trace"
TRACE=""

# Path variables
CONFIG=$HOMEDIR/config/config.toml
APP_TOML=$HOMEDIR/config/app.toml
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
	echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
	exit 1
}

# used to exit on first error (any non-zero exit code)
set -e

# Reinstall daemon
make install

# User prompt if an existing local node configuration is found.
if [ -d "$HOMEDIR" ]; then
	printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$HOMEDIR"
	echo "Overwrite the existing configuration and start a new local node? [y/n]"
	read -r overwrite
else
	overwrite="Y"
fi


# Setup local node if overwrite is set to Yes, otherwise skip setup
if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
	# Remove the previous folder
	rm -rf "$HOMEDIR"

	# Set client config
	versed config keyring-backend $KEYRING --home "$HOMEDIR"
	versed config chain-id $CHAINID --home "$HOMEDIR"

	# If keys exist they should be deleted
	for KEY in "${KEYS[@]}"; do
		versed keys add "$KEY" --keyring-backend $KEYRING --algo $KEYALGO --home "$HOMEDIR"
	done

	# Set moniker and chain-id for Evmos (Moniker can be anything, chain-id must be an integer)
	versed init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"

	# Change parameter token denominations to aevmos
	jq '.app_state["staking"]["params"]["bond_denom"]="aenergy"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["crisis"]["constant_fee"]["denom"]="aenergy"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="aenergy"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["evm"]["params"]["evm_denom"]="aenergy"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["inflation"]["params"]["mint_denom"]="aenergy"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Set gas limit in genesis
	jq '.consensus_params["block"]["max_gas"]="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

  # enable prometheus metrics
  if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' 's/prometheus = false/prometheus = true/' "$CONFIG"
      sed -i '' 's/prometheus-retention-time = 0/prometheus-retention-time  = 1000000000000/g' "$APP_TOML"
      sed -i '' 's/enabled = false/enabled = true/g' "$APP_TOML"
  else
      sed -i 's/prometheus = false/prometheus = true/' "$CONFIG"
      sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
      sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
  fi
	
	# Change proposal periods to pass within a reasonable time for local testing
	sed -i.bak 's/"max_deposit_period": "172800s"/"max_deposit_period": "30s"/g' "$HOMEDIR"/config/genesis.json
	sed -i.bak 's/"voting_period": "172800s"/"voting_period": "30s"/g' "$HOMEDIR"/config/genesis.json

	# set custom pruning settings
	sed -i.bak 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
	sed -i.bak 's/pruning-keep-recent = "0"/pruning-keep-recent = "2"/g' "$APP_TOML"
	sed -i.bak 's/pruning-interval = "0"/pruning-interval = "10"/g' "$APP_TOML"

	# Allocate genesis accounts (cosmos formatted addresses)
#	for KEY in "${KEYS[@]}"; do
#		versed add-genesis-account "$KEY" 100000000000000000000000000aenergy --keyring-backend $KEYRING --home "$HOMEDIR"
#	done

  versed add-genesis-account Founders 10000000000energy,20000000bitgold,1USD,1EUR,1GBP,1JPY,1RUB --keyring-backend $KEYRING --home "$HOMEDIR"
  versed add-genesis-account Technology 10000000000energy --keyring-backend $KEYRING --home "$HOMEDIR"
  versed add-genesis-account Foundation 18200000000energy --keyring-backend $KEYRING --home "$HOMEDIR"
  versed add-genesis-account Community 61800000000energy --keyring-backend $KEYRING --home "$HOMEDIR"

	# Sign genesis transaction
	versed gentx "${KEYS[0]}" 100000000energy --keyring-backend $KEYRING --chain-id $CHAINID --home "$HOMEDIR"
	## In case you want to create multiple validators at genesis
	## 1. Back to `versed keys add` step, init more keys
	## 2. Back to `versed add-genesis-account` step, add balance for those
	## 3. Clone this ~/.versed home directory into some others, let's say `~/.clonedEvmosd`
	## 4. Run `gentx` in each of those folders
	## 5. Copy the `gentx-*` folders under `~/.clonedEvmosd/config/gentx/` folders into the original `~/.versed/config/gentx`

	# Collect genesis tx
	versed collect-gentxs --home "$HOMEDIR"

	# Run this to ensure everything worked and that the genesis file is setup correctly
	versed validate-genesis --home "$HOMEDIR"

fi
