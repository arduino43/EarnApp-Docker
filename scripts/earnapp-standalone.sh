#!/bin/sh
# Lightweight helper to run EarnApp without Docker/systemd.
set -eu

DATA_DIR="${EARNAPP_DATA:-/etc/earnapp}"
BIN_PATH="${EARNAPP_BIN:-/usr/local/bin/earnapp}"
DOWNLOAD_DIR="${EARNAPP_DOWNLOAD:-/tmp}"
LOG_FILE="${EARNAPP_LOG:-$DATA_DIR/earnapp.log}"
RESTART_DELAY="${EARNAPP_RESTART_DELAY:-30}"
VERSION="${EARNAPP_VERSION:-1.585.464}"
BASE_URL="${EARNAPP_BASE_URL:-https://cdn-earnapp.b-cdn.net/static}"
PRODUCT="${EARNAPP_PRODUCT:-}" # earns "piggybox" when detected, otherwise "earnapp"
LCONF="${EARNAPP_VER_CONF:-/etc/earnapp/ver_conf.json}"

mkdir -p "$DATA_DIR" "$DOWNLOAD_DIR" "$(dirname "$BIN_PATH")"

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x64" ;;
        aarch64|arm64) echo "aarch64" ;;
        armv7l|armv6l) echo "arm7l" ;;
        *) echo "arm7l" ;;
    esac
}

detect_product() {
    if [ -n "$PRODUCT" ]; then
        echo "$PRODUCT"
        return
    fi

    if [ -f "$LCONF" ] && grep -q "appid" "$LCONF" 2>/dev/null && grep -q "piggy" "$LCONF" 2>/dev/null; then
        echo "piggybox"
    else
        echo "earnapp"
    fi
}

detect_ssl_suffix() {
    if command -v openssl >/dev/null 2>&1; then
        case "$(openssl version 2>/dev/null || echo '')" in
            OpenSSL\ 3*)
                echo "-ssl3"
                return
                ;;
        esac
    fi

    echo ""
}

install_binary() {
    if [ -x "$BIN_PATH" ]; then
        return
    fi

    arch_suffix=$(detect_arch)
    product=$(detect_product)
    ssl_suffix=$(detect_ssl_suffix)
    file_name="${product}${ssl_suffix}-${arch_suffix}-${VERSION}"
    download_dest="$DOWNLOAD_DIR/${product}_${VERSION}"

    echo "Downloading ${file_name} from ${BASE_URL}/${file_name}" >&2

    if command -v wget >/dev/null 2>&1; then
        wget -O "$download_dest" "${BASE_URL}/${file_name}" || {
            echo "Download failed (wget)." >&2
            exit 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -fSL -o "$download_dest" "${BASE_URL}/${file_name}" || {
            echo "Download failed (curl)." >&2
            exit 1
        }
    else
        echo "Neither wget nor curl found. Please install one of them." >&2
        exit 1
    fi

    chmod +x "$download_dest" || {
        echo "Could not mark ${download_dest} as executable." >&2
        exit 1
    }

    mv "$download_dest" "$BIN_PATH"
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
