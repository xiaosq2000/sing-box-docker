# TODO: build from source
ARG OS
ARG ARCH
FROM --platform=${OS}/${ARCH} ubuntu:22.04 AS base
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /sing-box
ARG OS
ARG ARCH
ARG SING_BOX_VERSION
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \
    https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    tar -zxf sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    rm sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz 
WORKDIR /sing-box/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}
RUN wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \
    https://github.com/SagerNet/sing-geoip/releases/download/20230812/geoip.db && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \
    https://github.com/SagerNet/sing-geoip/releases/download/20230812/geoip-cn.db && \
    wget -e http_proxy=${http_proxy} -e https_proxy=${https_proxy} \
    https://github.com/SagerNet/sing-geosite/releases/download/20230807051510/geosite.db

ARG OS
ARG ARCH
FROM --platform=${OS}/${ARCH} alpine:3.18.3
ARG OS
ARG ARCH
ARG SING_BOX_VERSION
COPY --from=base /sing-box/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH} /sing-box/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}
WORKDIR /sing-box/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}
