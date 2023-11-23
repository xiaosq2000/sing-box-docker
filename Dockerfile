FROM alpine:3.18.3
ARG OS
ARG ARCH
ARG SING_BOX_VERSION
RUN http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    wget https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    tar -zxf sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz && \
    rm sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}.tar.gz
WORKDIR /sing-box-${SING_BOX_VERSION}-${OS}-${ARCH}
