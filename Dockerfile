FROM alpine:latest

# Add the dependencies
RUN apk add bash wget unzip libc6-compat libstdc++ libssl3=3.0.8-r1 libcrypto3=3.0.8-r1

# Get the latest release of sloctl
RUN wget -O sloctl -q https://github.com/nobl9/sloctl/releases/download/v0.0.86/sloctl-linux-0.0.86

# place the binary in the PATH
RUN chmod +x sloctl
RUN mv sloctl /usr/local/bin

# Copy over our entrypoint file
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
