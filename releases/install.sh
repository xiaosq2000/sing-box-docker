#!/usr/bin/env bash
# Be safe.
set -euo pipefail
# The parent folder of this script.
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $script_dir

if [ -f "/etc/systemd/system/sing-box.service" ]; then
    sudo systemctl stop sing-box.service
    sudo systemctl disable sing-box.service
    sudo cp sing-box.service /etc/systemd/system/sing-box.service
else
    sudo cp sing-box.service /etc/systemd/system/sing-box.service
fi

sudo mkdir -p /usr/local/bin/ /usr/local/etc/

sudo cp sing-box /usr/local/bin/sing-box

sudo mkdir -p /usr/local/etc/sing-box
sudo cp trojan-client.json /usr/local/etc/sing-box/config.json

sudo mkdir -p /var/lib/sing-box/

sudo systemctl enable --now sing-box.service
