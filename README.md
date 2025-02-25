# sing-box-manager

> [!NOTE]
> For personal use!

## Configuration

```sh
SING_BOX_VERSION=1.10.7

CONFIG_GIT_REPO=./config
CONFIG_GIT_HASH=054d37e3

TROJAN_CLIENT_CONFIG=./config/client/trojan-client.json
HYSTERIA2_CLIENT_CONFIG=./config/client/hysteria2-client.json
TROJAN_TUN_CLIENT_CONFIG=./config/client/trojan-tun-client.json

TROJAN_SERVER_CONFIG=./config/server/trojan-server.json
HYSTERIA2_SERVER_CONFIG=./config/server/hysteria2-server.json

WEB_PORT=7070
```

## Package everything

```sh
uv run ./release.py
```

## Web service

```sh
sudo cp ./scripts/sing-box-release.service /etc/systemd/system/
sudo systemctl enable --now sing-box-release.service
```

## Deploy sing-box on server

```sh
./scripts/deploy_to_server.bash <SSH-SHORTCUT>
```
