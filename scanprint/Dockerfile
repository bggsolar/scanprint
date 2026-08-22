FROM ghcr.io/home-assistant/base:latest

ARG BUILD_VERSION
ARG BUILD_ARCH

ENV APP_VERSION="${BUILD_VERSION}"

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="app" \
    io.hass.arch="${BUILD_ARCH}"

RUN apk add --no-cache \
    cups-client \
    inotify-tools \
    mosquitto-clients \
    jq \
    netcat-openbsd

COPY run.sh /

RUN chmod a+x /run.sh

CMD ["/run.sh"]
