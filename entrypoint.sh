#!/bin/sh

CLIENT_ID=$1
CLIENT_SECRET=$2
ACCESS_TOKEN=$3
PROJECT=$4
SLOCTL_YML=$5

sed -i "s/{{CLIENT_ID}}/${CLIENT_ID}/g" ~/.config/nobl9/config.toml
sed -i "s/{{CLIENT_SECRET}}/${CLIENT_SECRET}/g" ~/.config/nobl9/config.toml
sed -i "s/{{ACCESS_TOKEN}}/${ACCESS_TOKEN}/g" ~/.config/nobl9/config.toml
sed -i "s/{{PROJECT}}/${PROJECT}/g" ~/.config/nobl9/config.toml

sloctl apply -f "$SLOCTL_YML"
