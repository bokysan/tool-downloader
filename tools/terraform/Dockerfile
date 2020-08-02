# ≡≡≡≡≡≡≡≡≡≡≡≡ Download executable ≡≡≡≡≡≡≡≡≡≡≡≡
FROM boky/tool-downloader AS build
ARG PROJECT
ARG DOWNLOAD_TEMPLATE
ARG VERIFY_COMMAND
ARG VERSION
ARG NAME
ARG PRE_INSTALL
ARG POST_INSTALL
RUN tool-downloader

# ≡≡≡≡≡≡≡≡≡≡≡≡ Create the image ≡≡≡≡≡≡≡≡≡≡≡≡
FROM alpine
COPY --from=build /usr/local/bin/terraform /terraform
WORKDIR /work
ENTRYPOINT [ "/terraform" ]
