FROM alpine:3.17.2

# Add the dependencies
RUN apk add bash wget unzip libc6-compat libstdc++ libssl3 libcrypto3

# Get the latest release of sloctl
RUN wget -O sloctl -q https://github.com/nobl9/sloctl/releases/download/v0.0.96/sloctl-linux-0.0.96

# place the binary in the PATH
RUN chmod +x sloctl
RUN mv sloctl /usr/local/bin

# Copy over our entrypoint file
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
