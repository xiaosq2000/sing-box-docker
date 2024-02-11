#!/usr/bin/env python3
import os
import json
import dotenv
import wget
from datetime import date
import shutil
import subprocess

root_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(root_dir)

env_file = os.path.join(root_dir, '.env')
env = dotenv.dotenv_values(env_file)

release_name = 'sing-box-v' + str(env.get('SING_BOX_VERSION'))
timestamp = date.today().strftime("%Y%m%d")
release_name = release_name + '-' + timestamp
release_dir = os.path.join(root_dir, 'releases', release_name)

os.makedirs(release_dir, exist_ok=True)

prebuilt_binary_urls = [
    'https://github.com/SagerNet/sing-box/releases/download/v' + str(
        env.get('SING_BOX_VERSION')) + '/sing-box-' + str(
        env.get('SING_BOX_VERSION')) + '-linux-amd64.tar.gz', 'https://github.com/SagerNet/sing-box/releases/download/v' + str(
            env.get('SING_BOX_VERSION')) + '/sing-box-' + str(
                env.get('SING_BOX_VERSION')) + '-windows-amd64.zip',
    'https://github.com/SagerNet/sing-box/releases/download/v' +
    str(env.get('SING_BOX_VERSION')) + '/SFA-' +
    str(env.get('SING_BOX_VERSION')) + '-universal.apk'
]
prebuilt_binary_file_paths = []
for url in prebuilt_binary_urls:
    prebuilt_binary_file_path = os.path.join(
        release_dir, os.path.basename(url))
    prebuilt_binary_file_paths.append(prebuilt_binary_file_path)
    if os.path.exists(prebuilt_binary_file_path) == False:
        wget.download(url, out=prebuilt_binary_file_path)

server_config_path = os.path.abspath(str(env.get('TROJAN_SERVER_CONFIG')))
client_config_path = os.path.abspath(str(env.get('TROJAN_CLIENT_CONFIG')))
client_tun_config_path = os.path.abspath(
    str(env.get('TROJAN_TUN_CLIENT_CONFIG')))

usernames = []
passwords = []
user_release_dirs = []
linux_amd64_dirs = []
windows_amd64_dirs = []
android_arm64_dirs = []
with open(server_config_path, 'r') as server_config_file:
    users = json.loads(server_config_file.read())["inbounds"][0]["users"]
    for user in users:
        usernames.append(user["name"])
        passwords.append(user["password"])

        user_release_dir = os.path.join(
            release_dir, release_name + '-' + str(user["name"]))
        user_release_dirs.append(user_release_dir)

        linux_amd64_dirs.append(os.path.join(user_release_dir, 'linux-amd64'))
        windows_amd64_dirs.append(
            os.path.join(
                user_release_dir,
                'windows-amd64'))
        android_arm64_dirs.append(
            os.path.join(
                user_release_dir,
               'android-arm64'))

user_num = len(usernames)

for i in range(0, user_num):
    os.makedirs(linux_amd64_dirs[i], exist_ok=True)
    subprocess.run(['tar', '-xf', prebuilt_binary_file_paths[0], '-C',
                   linux_amd64_dirs[i], '--strip-components=1'])

    os.makedirs(windows_amd64_dirs[i], exist_ok=True)
    subprocess.run(['unzip', '-qoj', '-d', windows_amd64_dirs[i], prebuilt_binary_file_paths[1]])

    os.makedirs(android_arm64_dirs[i], exist_ok=True)
    shutil.copy(prebuilt_binary_file_paths[2], android_arm64_dirs[i])

linux_amd64_config_paths = []
windows_amd64_config_paths = []
android_arm64_config_paths = []
for i in range(0, user_num):
    linux_amd64_config_paths.append(
        os.path.join(
            linux_amd64_dirs[i],
            os.path.basename(client_config_path)))
    windows_amd64_config_paths.append(
        os.path.join(
            windows_amd64_dirs[i],
            os.path.basename(client_config_path)))
    android_arm64_config_paths.append(
        os.path.join(
            android_arm64_dirs[i],
            os.path.basename(client_tun_config_path)))

with open(file=client_config_path, mode='r') as client_config_file:
    client_config = json.loads(client_config_file.read())
    for i in range(0, user_num):
        client_config["outbounds"][0]["password"] = passwords[i]
        client_config["inbounds"][0]["set_system_proxy"] = True
        with open(file=linux_amd64_config_paths[i], mode='w') as linux_amd64_config_file:
            json.dump(client_config, linux_amd64_config_file, indent=4)
        with open(file=windows_amd64_config_paths[i], mode='w') as windows_amd64_config_file:
            json.dump(client_config, windows_amd64_config_file, indent=4)

with open(file=client_tun_config_path, mode='r') as client_tun_config_file:
    client_tun_config = json.loads(client_tun_config_file.read())
    for i in range(0, user_num):
        client_tun_config["outbounds"][0]["password"] = passwords[i]
        with open(file=android_arm64_config_paths[i], mode='w') as android_arm64_config_file:
            json.dump(client_tun_config, android_arm64_config_file, indent=4)

for i in range(0, user_num):
    os.chdir(os.path.dirname(user_release_dirs[i]))
    subprocess.run((['tar', '-czf', os.path.basename(user_release_dirs[i]) + '.tar.gz', os.path.basename(user_release_dirs[i])]))
