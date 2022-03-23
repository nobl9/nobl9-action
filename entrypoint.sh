#!/bin/sh

mkdir -p ~/.config/nobl9

cat << EOF > ~/.config/nobl9/config.toml
defaultContext = "default"

[Contexts]
  [Contexts.default]
    clientId = "${INPUT_CLIENT_ID}"
    clientSecret = "${INPUT_CLIENT_SECRET}"
    accessToken = "${INPUT_ACCESS_TOKEN}"
    project = "${INPUT_PROJECT}"
EOF

sloctl apply -f "${INPUT_SLOCTL_YML}"
