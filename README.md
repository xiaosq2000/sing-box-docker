# sing-box setup

A lot thanks to [sing-box](https://github.com/SagerNet/sing-box) (by [nekohasekai](https://github.com/nekohasekai)).

## Usage

1. A dockerized environment for personal use. 
2. A quick release for my friends.

## Quick start (for linux clients)

### 0. Requirements

[Docker Engine](https://docs.docker.com/engine/) and [Docker Compose](https://docs.docker.com/compose/)

### 1. Configure

#### `*.json` for sing-box

For details, check out the ([offical reference](https://sing-box.sagernet.org/configuration/)).

### 2. Run

```bash
docker compose up -d ${PROTOCOL}-client
```

Executing it once is sufficient. No need to worry about rebooting.

## TODO

1. Instead of a private repo containing my secrets, divide them into open-source template files and secrets files, and use scripts to integrate them.
2. Docker serects.
