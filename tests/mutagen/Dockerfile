# ≡≡≡≡≡≡≡≡≡≡≡≡ Download executable ≡≡≡≡≡≡≡≡≡≡≡≡
FROM --platform=$BUILDPLATFORM boky/tool-downloader AS build
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG PROJECT
ARG DOWNLOAD_TEMPLATE
ARG VERIFY_COMMAND
ARG VERSION
ARG NAME
ARG PRE_INSTALL
ARG POST_INSTALL
RUN tool-downloader

# ≡≡≡≡≡≡≡≡≡≡≡≡ Create the image ≡≡≡≡≡≡≡≡≡≡≡≡
FROM --platform=$TARGETPLATFORM scratch
ARG TARGETPLATFORM
COPY --from=build /usr/local/bin/mutagen /mutagen
WORKDIR /work
ENTRYPOINT [ "/mutagen" ]
