FROM alpine:latest

# Add the dependencies
RUN apk add bash curl wget unzip libc6-compat libstdc++

# Get the latest release of sloctl
RUN curl -s https://api.github.com/repos/nobl9/sloctl/releases/latest | \
  grep "browser_download_url.*linux*" | \
  cut -d : -f 2,3 | \
  tr -d \" | \
  wget -O sloctl.zip -qi -

# unzip and place the binary in the PATH
RUN unzip sloctl.zip && mv sloctl /usr/local/bin

# Copy over our entrypoint file
COPY entrypoint.sh /entrypoint.sh

# Copy over the config
COPY config.toml /config.toml

ENTRYPOINT ["/entrypoint.sh"]
