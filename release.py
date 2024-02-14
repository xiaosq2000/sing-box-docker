#!/usr/bin/env python3
import os
import sys
import json
import dotenv
import wget
import shutil
import subprocess

root_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(root_dir)
env_file = os.path.join(root_dir, '.env')

if os.path.exists(env_file):
    env = dotenv.dotenv_values(env_file)
else:
    print("`.env' does not exist", file=sys.stderr)
    sys.exit(1)

sing_box_version = str(env.get('SING_BOX_VERSION'))
config_git_repo = str(env.get('CONFIG_GIT_REPO'))
config_git_hash = str(env.get('CONFIG_GIT_HASH'))
if os.path.exists(config_git_repo):
    os.chdir(config_git_repo)
    subprocess.run(['git', 'reset', '--hard'])
    subprocess.run(['git', 'checkout', config_git_hash])
    os.chdir(root_dir)

server_config_path = os.path.abspath(str(env.get('TROJAN_SERVER_CONFIG')))
client_config_path = os.path.abspath(str(env.get('TROJAN_CLIENT_CONFIG')))
client_tun_config_path = os.path.abspath(
    str(env.get('TROJAN_TUN_CLIENT_CONFIG')))

release_dir = os.path.join(
    root_dir, 'releases', 'sing-box-v' + sing_box_version + '-' + config_git_hash)
os.makedirs(release_dir, exist_ok=True)

official_releases = [{'platform': 'linux-amd64', 'url': 'https://github.com/SagerNet/sing-box/releases/download/v' + sing_box_version + '/sing-box-' + sing_box_version + '-linux-amd64.tar.gz', 'path': ''},
                     {'platform': 'windows-amd64', 'url': 'https://github.com/SagerNet/sing-box/releases/download/v' + sing_box_version + '/sing-box-' + sing_box_version + '-windows-amd64.zip', 'path': ''}, {
    'platform': 'android-arm64', 'url': 'https://github.com/SagerNet/sing-box/releases/download/v' + sing_box_version + '/SFA-' + sing_box_version + '-universal.apk', 'path': ''}
]

print('Download prebuilt binaries from SagerNet/sing-box on Github.')
for official_release in official_releases:
    official_release['path'] = os.path.join(
        release_dir, os.path.basename(official_release['url']))
    print(official_release['platform'], ': ', sep='')
    if not os.path.exists(official_release['path']):
        wget.download(official_release['url'], out=official_release['path'])
        print()
    else:
        print('\talready exists.')

print('Parse users information from the server configuration.')
users = {}
with open(server_config_path, 'r') as server_config_file:
    users = json.loads(server_config_file.read())["inbounds"][0]["users"]

print('There are', len(users), 'users in total.')

print('Prepare execuables among platforms for each user.')
for i, user in enumerate(users):
    print('\tUser', i+1, end=', ')
    user_dir = os.path.join(release_dir, os.path.basename(
        release_dir) + '-' + str(user['name']))
    os.makedirs(user_dir, exist_ok=True)
    for official_release in official_releases:
        dir = os.path.join(user_dir, official_release['platform'])
        os.makedirs(dir, exist_ok=True)
        if official_release['platform'] == 'linux-amd64':
            subprocess.run(['tar', 'xf', official_release['path'],
                           '-C', dir, '--strip-components=1'])
        elif official_release['platform'] == 'windows-amd64':
            subprocess.run(['unzip', '-qoj', '-d', dir,
                           official_release['path']])
        elif official_release['platform'] == 'android-arm64':
            shutil.copy(official_release['path'], dir)
        else:
            sys.exit(1)
    print('Done.')

print('Prepare configuration files for each user.')
for official_release in official_releases:
    if official_release['platform'] == 'linux-amd64':
        print('\t', official_release['platform'])
        with open(file=client_config_path, mode='r') as client_config_file:
            client_config = json.loads(
                client_config_file.read())
            for i, user in enumerate(users):
                print('\t\tUser', i+1, end=', ')
                client_config["inbounds"][0]["set_system_proxy"] = True
                client_config["outbounds"][0]["password"] = user['password']
                user_dir = os.path.join(release_dir, os.path.basename(
                    release_dir) + '-' + str(user['name']))
                user_client_config_path = os.path.join(user_dir, official_release['platform'], os.path.basename(client_config_path))
                with open(file=user_client_config_path, mode='w') as user_client_config_file:
                    json.dump(client_config,
                              user_client_config_file, indent=4)
                print('Done.')
    elif official_release['platform'] == 'windows-amd64':
        print('\t', official_release['platform'])
        with open(file=client_config_path, mode='r') as client_config_file:
            client_config = json.loads(
                client_config_file.read())
            for i, user in enumerate(users):
                print('\t\tUser', i+1, end=', ')
                client_config["inbounds"][0]["set_system_proxy"] = True
                client_config["outbounds"][0]["password"] = user['password']
                user_dir = os.path.join(release_dir, os.path.basename(
                    release_dir) + '-' + str(user['name']))
                user_client_config_path = os.path.join(user_dir, official_release['platform'], os.path.basename(client_config_path))
                with open(file=user_client_config_path, mode='w') as user_client_config_file:
                    json.dump(client_config,
                              user_client_config_file, indent=4)
                print('Done.')
    elif official_release['platform'] == 'android-arm64':
        print('\t', official_release['platform'])
        with open(file=client_tun_config_path, mode='r') as client_config_file:
            client_config = json.loads(
                client_config_file.read())
            for i, user in enumerate(users):
                print('\t\tUser', i+1, end=', ')
                client_config["outbounds"][0]["password"] = user['password']
                user_dir = os.path.join(release_dir, os.path.basename(
                    release_dir) + '-' + str(user['name']))
                user_client_config_path = os.path.join(user_dir, official_release['platform'], os.path.basename(client_tun_config_path))
                with open(file=user_client_config_path, mode='w') as user_client_config_file:
                    json.dump(client_config,
                              user_client_config_file, indent=4)
                print('Done.')
    else:
        sys.exit(1)

print('Compress by gzip.')
for i, user in enumerate(users):
    print('\tUser', i+1, end=', ')
    user_dir = os.path.join(release_dir, os.path.basename(
        release_dir) + '-' + str(user['name']))
    os.chdir(os.path.dirname(user_dir))
    subprocess.run((['tar', '-czf', os.path.basename(user_dir
                                                     ) + '.tar.gz', os.path.basename(user_dir)]))
    print('Done.')

print('Done.')
subprocess.run(['tree', release_dir])
