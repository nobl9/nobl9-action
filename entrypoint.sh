#!/bin/bash

operation="${INPUT_OPERATION:-apply}"
case "$operation" in
apply | delete) ;;
*)
  printf 'Invalid operation: %s. Expected apply or delete.\n' "$operation" >&2
  exit 1
  ;;
esac

mkdir -p ~/.config/nobl9

cat <<EOF >~/.config/nobl9/config.toml
defaultContext = "default"

[Contexts]
  [Contexts.default]
    clientId = "${INPUT_CLIENT_ID}"
    clientSecret = "${INPUT_CLIENT_SECRET}"
EOF

if [[ -n ${INPUT_OKTAORGURL:-} ]]; then
  printf '    oktaOrgURL = "%s"\n' "$INPUT_OKTAORGURL" >>~/.config/nobl9/config.toml
fi
if [[ -n ${INPUT_OKTAAUTHSERVER:-} ]]; then
  printf '    oktaAuthServer = "%s"\n' "$INPUT_OKTAAUTHSERVER" >>~/.config/nobl9/config.toml
fi

# Required to auto confirm, for more details refer to:
# https://docs.nobl9.com/sloctl-user-guide?_highlight=prompt&_highlight=threshold#apply
flags=(-y)

# Split paths on commas and leave glob expansion to sloctl.
IFS="," read -r -a filepaths <<<"$INPUT_SLOCTL_YML"
for filepath in "${filepaths[@]}"; do
  flags+=(-f "$filepath")
done

if [[ $INPUT_DRY_RUN == "true" ]]; then
  flags+=(--dry-run)
fi

sloctl "$operation" "${flags[@]}"
