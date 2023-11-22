# sing-box in docker

A dockerized [sing-box](https://github.com/SagerNet/sing-box) (by [nekohasekai](https://github.com/nekohasekai)) for personal use. 

## Quick start (for linux clients)

### 0. Requirements

[Docker Engine](https://docs.docker.com/engine/) and [Docker Compose](https://docs.docker.com/compose/)

### 1. Configure

There are two configuration files.

#### `*.json` for sing-box

Make sure that you receive a correct configuration file from your service provider.

For details, check out the ([offical reference](https://sing-box.sagernet.org/configuration/)).

#### `.env` for Docker

Modify the value of `CLIENT_CONFIG` to the path of your `*.json`.

### 2. Run

```bash
docker compose up -d client
```

Executing it once is sufficient. No need to worry about rebooting.
