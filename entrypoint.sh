#!/bin/sh

mkdir -p ~/.config/nobl9

cat << EOF > ~/.config/nobl9/config.toml
defaultContext = "default"

[Contexts]
  [Contexts.default]
    clientId = "${INPUT_CLIENT_ID}"
    clientSecret = "${INPUT_CLIENT_SECRET}"
EOF

flags=(
  -f "${INPUT_SLOCTL_YML}"
)
if [[ $INPUT_AUTO_CONFIRM == "true" ]]; then
  flags+=(-y)
fi

if [[ $INPUT_DRY_RUN == "true" ]]; then
  flags+=(--dry-run)
fi

sloctl apply "${flags[@]}"
