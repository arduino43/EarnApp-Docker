#!/bin/sh
# Lightweight helper to run EarnApp without Docker/systemd.
set -eu

DATA_DIR="${EARNAPP_DATA:-/etc/earnapp}"
BIN_PATH="${EARNAPP_BIN:-/usr/local/bin/earnapp}"
DOWNLOAD_DIR="${EARNAPP_DOWNLOAD:-/tmp}"
LOG_FILE="${EARNAPP_LOG:-$DATA_DIR/earnapp.log}"
RESTART_DELAY="${EARNAPP_RESTART_DELAY:-30}"

mkdir -p "$DATA_DIR" "$DOWNLOAD_DIR" "$(dirname "$BIN_PATH")"

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "bin_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        armv7l|armv6l) echo "armv7" ;;
        *) echo "armv7" ;;
    esac
}

install_binary() {
    if [ -x "$BIN_PATH" ]; then
        return
    fi

    archive_name=$(detect_arch)
    tmp_path="$DOWNLOAD_DIR/earnapp"
    if ! wget -cq --no-check-certificate "https://brightdata.com/static/earnapp/$archive_name" -O "$tmp_path"; then
        echo "Failed to download earnapp binary for $(uname -m)" >&2
        exit 1
    fi
    chmod +x "$tmp_path"
    mv "$tmp_path" "$BIN_PATH"
}

initialize_data_dir() {
    touch "$DATA_DIR/status"
    chmod a+wr "$DATA_DIR" "$DATA_DIR/status" 2>/dev/null || true

    if [ -n "${EARNAPP_UUID:-}" ]; then
        printf '%s' "$EARNAPP_UUID" > "$DATA_DIR/uuid"
    fi
}

run_loop() {
    while true; do
        "$BIN_PATH" start >/dev/null 2>&1 || true
        "$BIN_PATH" run >>"$LOG_FILE" 2>&1 &
        pid=$!
        wait $pid
        status=$?
        echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') earnapp exited with status $status, restarting in ${RESTART_DELAY}s" >>"$LOG_FILE"
        sleep "$RESTART_DELAY"
    done
}

install_binary
initialize_data_dir
run_loop
