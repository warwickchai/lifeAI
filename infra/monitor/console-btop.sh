#!/usr/bin/env bash
# Show btop full-time on a spare text console (default tty3), visible while the
# desktop is locked. At the box: Ctrl+Alt+F3 to view, Ctrl+Alt+F2 back to the desktop.
#
# btop runs as a dedicated no-login user that owns no other processes, so someone
# at the keyboard can look but cannot kill your processes or get a shell.
# Run on the box:  sudo ./infra/monitor/console-btop.sh   (safe to re-run)
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }

TTY=${TTY:-tty3}
USR=btopview
HOME_DIR=/var/lib/$USR

command -v btop >/dev/null || { apt-get update && apt-get install -y btop; }

if ! id "$USR" >/dev/null 2>&1; then
  useradd --system --home-dir "$HOME_DIR" --create-home --shell /usr/sbin/nologin "$USR"
fi
# GPU stats (NVML) need access to /dev/nvidia*; harmless before the driver exists.
usermod -aG video "$USR"

# Text console: 16 colours, no braille glyphs -> force btop's tty mode.
install -d -o "$USR" -g "$USR" "$HOME_DIR/.config/btop"
cat > "$HOME_DIR/.config/btop/btop.conf" <<'CONF'
force_tty = True
update_ms = 2000
proc_sorting = "cpu lazy"
shown_boxes = "cpu mem net proc gpu0"
CONF
chown "$USR:$USR" "$HOME_DIR/.config/btop/btop.conf"

# Free the console from the login prompt.
systemctl disable --now "getty@$TTY.service" 2>/dev/null || true
systemctl mask "getty@$TTY.service"

cat > /etc/systemd/system/btop-console.service <<UNIT
[Unit]
Description=btop system monitor on $TTY
After=systemd-user-sessions.service
Conflicts=getty@$TTY.service

[Service]
User=$USR
Environment=TERM=linux HOME=$HOME_DIR
# '+' = run as root: hand the console to $USR and stop it blanking.
ExecStartPre=+/bin/chown $USR /dev/$TTY
ExecStartPre=+/bin/sh -c 'setterm --blank 0 --powerdown 0 >/dev/$TTY </dev/$TTY'
ExecStart=/usr/bin/btop
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/$TTY
TTYReset=yes
TTYVHangup=yes
Restart=always
RestartSec=2
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$HOME_DIR

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable btop-console.service
systemctl restart btop-console.service
sleep 2
systemctl --no-pager --lines=5 status btop-console.service
echo
echo "Done. At the box press Ctrl+Alt+F${TTY#tty} for btop, Ctrl+Alt+F2 for the desktop."
