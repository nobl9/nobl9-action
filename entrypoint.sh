#!/bin/sh

CLIENT_ID=$1
CLIENT_SECRET=$2
ACCESS_TOKEN=$3
PROJECT=$4
SLOCTL_YML=$5

mkdir -p ~/.config/nobl9
touch ~/.config/nobl9/config.toml

echo 'defaultContext = "default"' >> ~/.config/nobl9/config.toml
echo '[Contexts]' >> ~/.config/nobl9/config.toml
echo '  [Contexts.default]' >> ~/.config/nobl9/config.toml
echo "    clientId = \"${CLIENT_ID}\"" >> ~/.config/nobl9/config.toml
echo "    clientSecret = \"${CLIENT_SECRET}\"" >> ~/.config/nobl9/config.toml
echo "    accessToken = \"${ACCESS_TOKEN}\"" >> ~/.config/nobl9/config.toml
echo "    project = \"${PROJECT}\"" >> ~/.config/nobl9/config.toml

cat $SLOCTL_YML

/sloctl apply -f "$SLOCTL_YML"
