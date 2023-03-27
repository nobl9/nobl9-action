FROM alpine:latest

# Add the dependencies
RUN apk add bash wget unzip libc6-compat libstdc++ libssl3=3.0.8-r1 libcrypto3=3.0.8-r1

# Get the latest release of sloctl
RUN wget -qO- https://api.github.com/repos/nobl9/sloctl/releases/latest | \
  grep "browser_download_url.*linux*" | \
  cut -d : -f 2,3 | \
  tr -d \" | \
  wget -O sloctl -qi -

# place the binary in the PATH
RUN chmod +x sloctl
RUN mv sloctl /usr/local/bin

# Copy over our entrypoint file
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
