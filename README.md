# proxy_tui_switch
A lightweight Bash proxy switcher with a clean TUI, concurrent connectivity checks, and proxy identity display.

一个轻量级 Bash 代理开关脚本，支持美观的 TUI 输出、并发连通性检测和代理出口信息展示。


## Features

- Enable or disable proxy environment variables with simple commands
- Clean and readable terminal UI output
- Concurrent HTTP and SOCKS5 connectivity checks
- Proxy identity display, including IP address, location
- Designed for system-wide loading through `/etc/profile.d`
- Works even when `jq` is not installed
- Configurable proxy address, test URL, IP API, and timeout

## Preview

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/d0de9d57-1c9c-4be0-bdfc-d4dd9ade6f55" />

## Commands

| Command | Description |
|---|---|
| `sp` | Enable proxy and run connectivity checks |
| `usp` | Disable proxy by unsetting proxy environment variables |
| `spp` | Enable proxy without connectivity check |

## Installation

Clone the repository:

```bash
git clone https://github.com/Little-King2022/proxy_tui_switch.git
cd proxy_tui_switch
```

Copy the script to `/etc/profile.d`:

```bash
sudo cp proxy.sh /etc/profile.d/proxy.sh
sudo chmod 644 /etc/profile.d/proxy.sh
```

Log out and log back in, or open a new login shell:

```bash
bash -l
```

Then run:

```bash
sp
```

## Configuration

The script can be configured through environment variables.

| Variable | Default | Description |
|---|---|---|
| `PROXY_HTTP` | `http://your.proxy.server:7890` | HTTP and HTTPS proxy address |
| `PROXY_SOCKS5` | `socks5://your.proxy.server:7891` | SOCKS5 proxy address |
| `PROXY_TEST_URL` | `https://www.google.com` | URL used for connectivity checks |
| `PROXY_IP_API` | `https://ipinfo.io` | API used to query proxy identity |
| `PROXY_TIMEOUT` | `5` | Timeout in seconds for network checks |

You can edit these values directly in `proxy.sh`, or define them before the script is loaded by your shell environment.

## Usage

Enable proxy:

```bash
sp
```

Disable proxy:

```bash
usp
```

Enable proxy without connectivity check:

```bash
spp
```

## Requirements

Required:

```bash
bash
curl
```

Optional:

```bash
jq
```

If `jq` is unavailable, the script falls back to basic `awk` parsing for IP information.

## License

MIT License
