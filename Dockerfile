FROM alpine

RUN apk add --no-cache jq unzip curl
COPY files/tool-downloader.sh /usr/local/bin/tool-downloader
RUN chmod +x /usr/local/bin/tool-downloader
