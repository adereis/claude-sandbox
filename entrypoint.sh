#!/bin/bash
# Claude Sandbox entrypoint — starts network filtering proxy, then execs user command.
#
# Behavior depends on environment:
#   CLAUDE_SANDBOX_UNRESTRICTED_NETWORK=1  → skip filtering entirely
#   CLAUDE_SANDBOX_EXTERNAL_PROXY set      → use host's proxy, skip tinyproxy
#   Otherwise                              → start tinyproxy with domain whitelist

set -e

PROXY_PORT=8888
PROXY_CONF="/etc/tinyproxy/tinyproxy.conf"
WHITELIST_DIR="/etc/tinyproxy"

# Default command if none provided
if [ $# -eq 0 ]; then
    set -- /bin/bash
fi

# --- Unrestricted mode: skip everything ---
if [ "${CLAUDE_SANDBOX_UNRESTRICTED_NETWORK:-0}" = "1" ]; then
    exec "$@"
fi

# --- External proxy: use host's proxy instead of tinyproxy ---
if [ -n "${CLAUDE_SANDBOX_EXTERNAL_PROXY:-}" ]; then
    echo "[sandbox] Using external proxy: $CLAUDE_SANDBOX_EXTERNAL_PROXY"
    export HTTPS_PROXY="$CLAUDE_SANDBOX_EXTERNAL_PROXY"
    export HTTP_PROXY="$CLAUDE_SANDBOX_EXTERNAL_PROXY"
    export https_proxy="$CLAUDE_SANDBOX_EXTERNAL_PROXY"
    export http_proxy="$CLAUDE_SANDBOX_EXTERNAL_PROXY"
    exec "$@"
fi

# --- Build merged whitelist ---
MERGED_WHITELIST="$HOME/tmp/network-whitelist-merged.conf"
mkdir -p "$HOME/tmp"
cp "$WHITELIST_DIR/network-whitelist.conf" "$MERGED_WHITELIST"

# Auto-append GCP domains for Vertex AI users
if [ "${CLAUDE_CODE_USE_VERTEX:-0}" = "1" ] || [ -d "$HOME/.config/gcloud" ]; then
    if [ -f "$WHITELIST_DIR/network-whitelist-gcp.conf" ]; then
        cat "$WHITELIST_DIR/network-whitelist-gcp.conf" >> "$MERGED_WHITELIST"
    fi
fi

# Auto-append AWS domains for Bedrock users
if [ "${CLAUDE_CODE_USE_BEDROCK:-0}" = "1" ] || [ -n "${AWS_REGION:-}" ]; then
    if [ -f "$WHITELIST_DIR/network-whitelist-aws.conf" ]; then
        cat "$WHITELIST_DIR/network-whitelist-aws.conf" >> "$MERGED_WHITELIST"
    fi
fi

# Append --allow-domain entries passed via env var
if [ -n "${CLAUDE_SANDBOX_EXTRA_DOMAINS:-}" ]; then
    IFS=',' read -ra DOMAINS <<< "$CLAUDE_SANDBOX_EXTRA_DOMAINS"
    for domain in "${DOMAINS[@]}"; do
        # Escape dots and wrap in anchored pattern
        escaped=$(echo "$domain" | sed 's/\./\\./g')
        echo "(^|\\.)${escaped}$" >> "$MERGED_WHITELIST"
    done
fi

# Append user-provided custom whitelist (mounted at runtime via --whitelist)
if [ -f "$HOME/.claude-sandbox-whitelist.conf" ]; then
    cat "$HOME/.claude-sandbox-whitelist.conf" >> "$MERGED_WHITELIST"
fi

# --- Start tinyproxy ---
RUNTIME_CONF="$HOME/tmp/tinyproxy-runtime.conf"
sed "s|^Filter .*|Filter \"$MERGED_WHITELIST\"|" "$PROXY_CONF" > "$RUNTIME_CONF"

# Remove User/Group directives — run as current user (mapped via --userns=keep-id)
sed -i '/^User /d; /^Group /d' "$RUNTIME_CONF"

tinyproxy -d -c "$RUNTIME_CONF" &
TINYPROXY_PID=$!

# Give tinyproxy a moment to bind
sleep 0.3

# Verify it started
if ! kill -0 "$TINYPROXY_PID" 2>/dev/null; then
    echo "[sandbox] WARNING: tinyproxy failed to start, running without network filtering." >&2
    exec "$@"
fi

# Clean up tinyproxy on exit
trap 'kill "$TINYPROXY_PID" 2>/dev/null || true' EXIT

# --- Configure proxy for all tools ---
export HTTP_PROXY="http://127.0.0.1:${PROXY_PORT}"
export HTTPS_PROXY="http://127.0.0.1:${PROXY_PORT}"
export http_proxy="http://127.0.0.1:${PROXY_PORT}"
export https_proxy="http://127.0.0.1:${PROXY_PORT}"
export NO_PROXY="localhost,127.0.0.1"
export no_proxy="localhost,127.0.0.1"

# npm sometimes ignores env vars — set explicitly
npm config set proxy "http://127.0.0.1:${PROXY_PORT}" 2>/dev/null || true
npm config set https-proxy "http://127.0.0.1:${PROXY_PORT}" 2>/dev/null || true

# git proxy
git config --global http.proxy "http://127.0.0.1:${PROXY_PORT}" 2>/dev/null || true

echo "[sandbox] Network filtering active (proxy on 127.0.0.1:${PROXY_PORT})"

exec "$@"
