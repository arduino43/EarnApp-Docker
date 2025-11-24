#!/bin/sh
set -euo pipefail

# Simple bare-metal installer for EarnApp
# Works on Debian-like hosts and BusyBox environments without Docker.

STATE_DIR=${STATE_DIR:-/etc/earnapp}
BIN_DIR=${BIN_DIR:-/usr/local/bin}
DOWNLOAD_DIR=${DOWNLOAD_DIR:-/tmp/earnapp-download}

# Detect architecture
case "$(uname -m)" in
    x86_64|amd64)
        file=bin_64
        ;;
    armv7l|armv6l)
        file=armv7
        ;;
    aarch64|arm64)
        file=aarch64
        ;;
    *)
        file=armv7
        ;;
esac

mkdir -p "$DOWNLOAD_DIR" "$STATE_DIR" "$BIN_DIR"

printf 'Downloading EarnApp binary for %s...\n' "$file"
wget -cq --no-check-certificate "https://brightdata.com/static/earnapp/$file" -O "$DOWNLOAD_DIR/earnapp"
chmod +x "$DOWNLOAD_DIR/earnapp"

install -m 0755 "$DOWNLOAD_DIR/earnapp" "$BIN_DIR/earnapp"

if [ "${EARNAPP_UUID:-}" != "" ]; then
    printf '%s' "$EARNAPP_UUID" > "$STATE_DIR/uuid"
fi

touch "$STATE_DIR/status"
chmod a+rw "$STATE_DIR/status" "$STATE_DIR" 2>/dev/null || true

cat > "$BIN_DIR/earnapp-daemon" <<'LAUNCHER'
#!/bin/sh
STATE_DIR=${STATE_DIR:-/etc/earnapp}
EARNAPP_BIN=${EARNAPP_BIN:-/usr/local/bin/earnapp}
LOG_FILE=${LOG_FILE:-/var/log/earnapp.log}

mkdir -p "$(dirname "$LOG_FILE")"

while true; do
    "$EARNAPP_BIN" start >>"$LOG_FILE" 2>&1 || true
    "$EARNAPP_BIN" run >>"$LOG_FILE" 2>&1
    sleep 5
done
LAUNCHER
chmod +x "$BIN_DIR/earnapp-daemon"

echo "EarnApp installed to $BIN_DIR/earnapp"

if command -v systemctl >/dev/null 2>&1; then
    SERVICE_FILE=/etc/systemd/system/earnapp.service
    cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=EarnApp headless client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN_DIR/earnapp-daemon
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    systemctl enable earnapp.service
    systemctl start earnapp.service
    echo "Systemd service installed and started (earnapp.service)."
else
    echo "Systemd not found; start manually with:"
    echo "  nohup $BIN_DIR/earnapp-daemon >/var/log/earnapp.log 2>&1 &"
fi

echo "If no UUID was provided, run 'earnapp showid' to register this node."
