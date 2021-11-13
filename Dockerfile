FROM ubuntu:20.10

ADD "https://github.com/nobl9/sloctl/releases/download/0.0.55/sloctl-linux-0.0.55.zip" /
RUN apt-get update
RUN apt-get -y install unzip ca-certificates
RUN unzip /sloctl-linux-0.0.55.zip

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
