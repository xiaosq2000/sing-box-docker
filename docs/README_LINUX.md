# README

## Installation

> [!TIP]
> It's a dangerous world. You are recommended to check the script before executation.
>
> If you believe in me, `./install.sh` will
> 1. Install a systemd service. (why `sudo` is required)
> 2. Add some handy shell functions by appending a line to your `~/.bashrc` or `~/.zshrc`. 

If you are using `bash`, execute

```sh
sudo ./install.sh --bash
```

If you are using `zsh`, execute

```sh
sudo ./install.sh --zsh
```

## Usage

Open a new shell or source your shell's rc-file.

- To enable proxy:
    ```sh
    set_proxy
    ```
- To disable proxy:
    ```sh
    unset_proxy
    ````
- To check public ip
    ```sh
    check_public_ip
    ```
- To check proxy status
    ```sh
    check_proxy_status
    ```
