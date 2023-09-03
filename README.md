# sing-box in docker

A dockerized [sing-box](https://github.com/SagerNet/sing-box) (by [nekohasekai](https://github.com/nekohasekai)) for personal use. 

```bash
# working tree
.
├── config
│   └── *.json
├── docker-compose.yml
├── Dockerfile
├── .dockerignore
├── .env
├── .gitignore
├── LICENSE
└── README.md

1 directory, 8 files

```

## Quick Start

### 0. Requirements

[Docker Engine](https://docs.docker.com/engine/) and [Docker Compose](https://docs.docker.com/compose/)

### 1. Get `.env` and `*.json` files ready

`.env` is loaded by `docker-compose.yml` for both building images and running containers.

Here is an example.

```bash
OS=linux
ARCH=amd64
SING_BOX_VERSION=1.4.0
http_proxy=http://127.0.0.1:1080 # optional, only for building
https_proxy=https://127.0.0.1:1080 # optional, only for building
CONFIG_FILE=./config/vmess-client.json
```

`*.json` is the configuration file for sing-box ([offical reference](https://sing-box.sagernet.org/configuration/)). 

### 2. Start

```bash
docker compose up -d
```
