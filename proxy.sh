#!/usr/bin/env bash
# shellcheck shell=bash

# ============================================================
# Proxy switch helper
# Usage:
#   source /path/to/proxy.sh
#   sp      # enable proxy and test connectivity
#   sp -q   # enable proxy only, skip connectivity test
#   usp     # disable proxy
#   spp     # enable proxy only, skip connectivity test
# ============================================================

# ---------- Config ----------
PROXY_HTTP="${PROXY_HTTP:-http://your.proxy.server:7890}"
PROXY_SOCKS5="${PROXY_SOCKS5:-socks5://your.proxy.server:7891}"
PROXY_TEST_URL="${PROXY_TEST_URL:-https://www.google.com}"
PROXY_IP_API="${PROXY_IP_API:-https://ipinfo.io}"
PROXY_TIMEOUT="${PROXY_TIMEOUT:-5}"

# ---------- TUI helpers ----------
_proxy_is_tty() { [[ -t 1 ]]; }

if _proxy_is_tty && command -v tput >/dev/null 2>&1; then
    _BOLD="$(tput bold 2>/dev/null || true)"
    _DIM="$(tput dim 2>/dev/null || true)"
    _RESET="$(tput sgr0 2>/dev/null || true)"
    _RED="$(tput setaf 1 2>/dev/null || true)"
    _GREEN="$(tput setaf 2 2>/dev/null || true)"
    _YELLOW="$(tput setaf 3 2>/dev/null || true)"
    _BLUE="$(tput setaf 4 2>/dev/null || true)"
    _MAGENTA="$(tput setaf 5 2>/dev/null || true)"
    _CYAN="$(tput setaf 6 2>/dev/null || true)"
else
    _BOLD=""; _DIM=""; _RESET=""
    _RED=""; _GREEN=""; _YELLOW=""; _BLUE=""; _MAGENTA=""; _CYAN=""
fi

_proxy_line() {
    printf '%b\n' "${_DIM}────────────────────────────────────────────────────────${_RESET}"
}

_proxy_title() {
    local title="$1"
    _proxy_line
    printf '%b\n' "${_BOLD}${_CYAN}  $title${_RESET}"
    _proxy_line
}

_proxy_kv() {
    local key="$1"
    local value="$2"
    printf '  %b%-12s%b %s\n' "${_DIM}" "$key" "${_RESET}" "$value"
}

_proxy_ok() {
    printf '  %b%-24s%b %b%s%b\n' "${_DIM}" "$1" "${_RESET}" "${_GREEN}" "OK" "${_RESET}"
}

_proxy_fail() {
    printf '  %b%-24s%b %b%s%b\n' "${_DIM}" "$1" "${_RESET}" "${_RED}" "FAILED" "${_RESET}"
}

_proxy_warn() {
    printf '  %b%s%b\n' "${_YELLOW}" "$1" "${_RESET}"
}

_proxy_cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

_proxy_curl_head() {
    local proxy_arg="$1"
    curl -fsSI $proxy_arg --connect-timeout "$PROXY_TIMEOUT" --max-time "$PROXY_TIMEOUT" "$PROXY_TEST_URL" >/dev/null 2>&1
}

_proxy_print_ip() {
    local info ip city region country loc org

    info=$(curl -fsS --connect-timeout "$PROXY_TIMEOUT" --max-time "$PROXY_TIMEOUT" "$PROXY_IP_API" 2>/dev/null)
    if [[ -z "$info" ]]; then
        _proxy_fail "Proxy IP"
        return 1
    fi

    # Prefer jq when available; fall back to awk for minimal systems.
    if _proxy_cmd_exists jq; then
        ip=$(printf '%s' "$info" | jq -r '.ip // empty')
        city=$(printf '%s' "$info" | jq -r '.city // empty')
        region=$(printf '%s' "$info" | jq -r '.region // empty')
        country=$(printf '%s' "$info" | jq -r '.country // empty')
    else
        ip=$(printf '%s' "$info" | awk -F'"' '/"ip"/ {print $4; exit}')
        city=$(printf '%s' "$info" | awk -F'"' '/"city"/ {print $4; exit}')
        region=$(printf '%s' "$info" | awk -F'"' '/"region"/ {print $4; exit}')
        country=$(printf '%s' "$info" | awk -F'"' '/"country"/ {print $4; exit}')
    fi

    if [[ -n "$ip" ]]; then
        printf '  %b%-12s%b %b%s%b\n' "${_DIM}" "IP" "${_RESET}" "${_MAGENTA}" "$ip" "${_RESET}"
        [[ -n "$city$region$country" ]] && _proxy_kv "Location" "${city:-Unknown}, ${region:-Unknown}, ${country:-Unknown}"
    else
        _proxy_fail "Proxy IP"
        return 1
    fi
}

# ---------- Public commands ----------
sp() {
    local quick_mode=0
    if [[ "${1:-}" == "-q" ]]; then
        quick_mode=1
        shift
    fi

    export http_proxy="$PROXY_HTTP"
    export HTTP_PROXY="$PROXY_HTTP"
    export https_proxy="$PROXY_HTTP"
    export HTTPS_PROXY="$PROXY_HTTP"
    export all_proxy="$PROXY_SOCKS5"
    export ALL_PROXY="$PROXY_SOCKS5"

    _proxy_title "Proxy Enabled"
    _proxy_kv "HTTP"  "$PROXY_HTTP"
    _proxy_kv "HTTPS" "$PROXY_HTTP"
    _proxy_kv "SOCKS5" "$PROXY_SOCKS5"

    if [[ $quick_mode -eq 1 ]]; then
        _proxy_line
        return 0
    fi

    if ! _proxy_cmd_exists curl; then
        _proxy_warn "curl not found, connectivity test skipped."
        return 0
    fi

    printf '\n%b\n' "${_BOLD}  Connectivity${_RESET}"

    # Run concurrent checks inside a non-interactive bash process.
    # This avoids interactive job-control messages such as "[1] 12345".
    local check_result
    check_result="$(
        PROXY_HTTP="$PROXY_HTTP" \
        PROXY_SOCKS5="$PROXY_SOCKS5" \
        PROXY_TEST_URL="$PROXY_TEST_URL" \
        PROXY_TIMEOUT="$PROXY_TIMEOUT" \
        bash -c '
            http_rc=1
            socks_rc=1

            curl -fsSI -x "$PROXY_HTTP" \
                --connect-timeout "$PROXY_TIMEOUT" \
                --max-time "$PROXY_TIMEOUT" \
                "$PROXY_TEST_URL" >/dev/null 2>&1 &
            http_pid=$!

            curl -fsSI --socks5-hostname "${PROXY_SOCKS5#socks5://}" \
                --connect-timeout "$PROXY_TIMEOUT" \
                --max-time "$PROXY_TIMEOUT" \
                "$PROXY_TEST_URL" >/dev/null 2>&1 &
            socks_pid=$!

            wait "$http_pid"; http_rc=$?
            wait "$socks_pid"; socks_rc=$?

            printf "%s %s\n" "$http_rc" "$socks_rc"
        '
    )"

    local http_rc=1
    local socks_rc=1
    read -r http_rc socks_rc <<< "$check_result"

    if [[ $http_rc -eq 0 ]]; then
        _proxy_ok "HTTP to Google"
    else
        _proxy_fail "HTTP to Google"
    fi

    if [[ $socks_rc -eq 0 ]]; then
        _proxy_ok "SOCKS5 to Google"
    else
        _proxy_fail "SOCKS5 to Google"
    fi

    printf '\n%b\n' "${_BOLD}  Proxy Identity${_RESET}"
    _proxy_print_ip

    printf '\n%b\n' "${_BOLD}  Use \"spp\" to skip connectivity check${_RESET}"
    _proxy_line
}

usp() {
    unset http_proxy HTTP_PROXY
    unset https_proxy HTTPS_PROXY
    unset all_proxy ALL_PROXY

    _proxy_title "Proxy Disabled"
}

alias spp="sp -q"
