FROM alpine:latest

# Add the dependencies
RUN apk add bash curl wget unzip libc6-compat libstdc++

# Get the latest release of sloctl
RUN curl -s https://api.github.com/repos/nobl9/sloctl/releases/latest | \
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
