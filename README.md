# (GitHub) tool downloader

## What is this

This is a Docker image / bash script to download tools (mostly written in Go) into your image.

## Why

Because I got tired of writting the same script over and over again. Most newer tools do not have an installer anymore but just point you to download the binary from their GitHub page.

## How to use

Usually, you'll want do this as a step of your Docker build, e.g.:

```Dockerfile
# ≡≡≡≡≡≡≡≡≡≡≡≡ Download executable ≡≡≡≡≡≡≡≡≡≡≡≡
FROM boky/tool-downloader AS hetzner-kube

RUN  \
    env \
      PROJECT='xetys/hetzner-kube' \
      DOWNLOAD_TEMPLATE='https://github.com/${PROJECT}/releases/download/${VERSION}/${NAME}-${VERSION}-${GOOS}-${GOARCH}${GOEXT}' \
    tool-downloader

# ≡≡≡≡≡≡≡≡≡≡≡≡ Create your image for install-less usage on your computer ≡≡≡≡≡≡≡≡≡≡≡≡
FROM scratch
COPY --from=hetzner-kube /usr/local/bin/hetzner-kube /usr/local/bin

# ≡≡≡≡≡≡≡≡≡≡≡≡ Embed into your image ≡≡≡≡≡≡≡≡≡≡≡≡
FROM python:latest
...
COPY --from=hetzner-kube /usr/bin/hetzner-kube /usr/bin
```

See more usage examples in the `tools` folder.

## Configuration options

Most of the time, you will need to provide the `$PROJECT` (GitHub project name) and `$DOWNLOAD_TEMPLATE` and the tool will download the latest version.

To fix the specific version, set the `$VERSION` field.
