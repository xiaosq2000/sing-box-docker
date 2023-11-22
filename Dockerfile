FROM alpine:3.18.3
ARG OS
ARG ARCH
ARG SING_BOX_VERSION
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    wget https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    tar -zxf sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    rm sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    cd sing-box-${SING_BOX_VERSION}-${OS}-${ARCH} && \
    wget https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db && \
    wget https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db
WORKDIR /sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}
