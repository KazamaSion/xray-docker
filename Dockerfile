ARG ARCH=
FROM ${ARCH}golang:1.17.1-alpine as xray-builder
ARG XRAY_VERSION=1.4.5

RUN set -x \
    && tempDir="$(mktemp -d)" \
    && chown nobody:nobody ${tempDir} \
    && apk add --no-cache --virtual .fetch-deps \
    wget \
    tar \
    unzip \
    && su nobody -s /bin/sh -c " \
        export HOME=${tempDir} \
        && cd ${tempDir} \
        && mkdir src/ \
        && wget --output-document=xray_src.zip https://github.com/XTLS/Xray-core/archive/refs/tags/v${XRAY_VERSION}.zip \
        && unzip -qq xray_src.zip \
        && rm xray_src.zip \
        && mv Xray*/ src/xray/ \
        && cd src/xray/ \
        && mkdir /tmp/bin/\
        # Build
        && go mod download \
        && CGO_ENABLED=0 go build -o /tmp/bin/xray -trimpath -ldflags '-s -w -buildid=' ./main \
        "

FROM ${ARCH}alpine:latest

LABEL maintainer="Sion Kazama <13185633+KazamaSion@users.noreply.github.com>"
ENV XRAY_LOCATION_ASSET=/usr/share/xray/ XRAY_LOCATION_CONFIG=/etc/xray/

RUN --mount=type=bind,from=xray-builder,source=/tmp/bin,target=/usr/src/xray,readonly \
    set -x \
    && tempDir="$(mktemp -d)" \
    && chown nobody:nobody ${tempDir} \
    # Deploy(Part 1)
    && mkdir -p /var/log/xray /etc/xray /usr/share/xray \
    && cp /usr/src/xray/xray /usr/bin/ \
    && chmod +x /usr/bin/xray \
    && chown nobody:nobody /usr/bin/xray /var/log/xray /etc/xray /usr/share/xray \
    && su nobody -s /bin/sh -c " \
        export HOME=${tempDir} \
        && cd ${tempDir} \
        # Deploy(Part 2)
        && echo '{}' > /etc/xray/config.json \
        && touch /var/log/xray/access.log \
        && touch /var/log/xray/error.log \
        && wget --output-document=/usr/share/xray/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat \
        && wget --output-document=/usr/share/xray/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat \
        " \
    && rm -rf ${tempDir} \
    # Forward access and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/xray/access.log \
    && ln -sf /dev/stderr /var/log/xray/error.log

RUN rm -rf /usr/src

ENTRYPOINT ["/usr/bin/xray"]

STOPSIGNAL SIGQUIT

CMD ["run"]
