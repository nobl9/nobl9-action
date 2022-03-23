#!/bin/sh

CLIENT_ID=$1
CLIENT_SECRET=$2
ACCESS_TOKEN=$3
PROJECT=$4
SLOCTL_YML=$5

mkdir -p ~/.config/nobl9

cat << EOF > ~/.config/nobl9/config.toml
defaultContext = "default"

[Contexts]
  [Contexts.default]
    clientId = ${CLIENT_ID}
    clientSecret = ${CLIENT_SECRET}
    accessToken = ${ACCESS_TOKEN}
    project = ${PROJECT}
EOF

sloctl apply -f "$SLOCTL_YML"
