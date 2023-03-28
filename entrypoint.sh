#!/bin/bash

mkdir -p ~/.config/nobl9

cat << EOF > ~/.config/nobl9/config.toml
defaultContext = "default"

[Contexts]
  [Contexts.default]
    clientId = "${INPUT_CLIENT_ID}"
    clientSecret = "${INPUT_CLIENT_SECRET}"
EOF

flags=(
  -y # Required to auto confirm, for more details refer to: https://docs.nobl9.com/sloctl-user-guide?_highlight=prompt&_highlight=threshold#apply
  -f "${INPUT_SLOCTL_YML}"
)

if [[ $INPUT_DRY_RUN == "true" ]]; then
  flags+=(--dry-run)
fi

sloctl apply "${flags[@]}"
