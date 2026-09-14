FROM docker.io/nobl9/sloctl:0.26.0 AS sloctl

FROM docker.io/library/alpine:3.24.1

RUN apk add --no-cache bash ca-certificates

COPY --from=sloctl /usr/bin/sloctl /usr/local/bin/sloctl
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
