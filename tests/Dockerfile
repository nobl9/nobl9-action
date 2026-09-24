ARG ACTION_IMAGE=nobl9-action:local
FROM ${ACTION_IMAGE} AS action

FROM docker.io/bats/bats:1.14.0

RUN apk add --no-cache ca-certificates coreutils git jq

COPY --from=action /usr/local/bin/sloctl /usr/local/bin/sloctl
COPY --from=action /entrypoint.sh /entrypoint.sh

ENV BATS_LIB_PATH=/usr/lib/bats
WORKDIR /tests
COPY e2e.bats .
COPY fixtures ./fixtures

CMD ["e2e.bats"]
