ARG OS
ARG ARCH
FROM --platform=${OS}/${ARCH} alpine:3.18.3
ARG OS
ARG ARCH
ARG SING_BOX_VERSION
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    apk upgrade --update-cache --available && \
    apk --no-cache add \
    curl openssl && \
    wget -O -  https://get.acme.sh | sh && \
    wget https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    tar -zxf sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    rm sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    cd sing-box-${SING_BOX_VERSION}-${OS}-${ARCH} && \
    wget https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db && \
    wget https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db
WORKDIR /sing-box/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}
