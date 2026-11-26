#!/usr/bin/env bash
# Se ejecuta DENTRO del contenedor, una sola vez, al crearlo.
# Deja Terraria funcionando como servicio de systemd:
#   - arranca solo al encender el contenedor
#   - guarda el mundo al apagar (envía "exit" a la consola)
#   - la consola vive en tmux para poder leerla y mandarle comandos
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if ! command -v tmux >/dev/null; then
    # Esperar a que el contenedor tenga red antes de usar apt
    for _ in $(seq 30); do getent hosts archive.ubuntu.com >/dev/null && break; sleep 2; done
    apt-get update -q
    apt-get install -y -q tmux
fi

id terraria >/dev/null 2>&1 || useradd --system --home-dir /opt/terraria --shell /usr/sbin/nologin terraria

touch /opt/terraria/banlist.txt
chmod +x /opt/terraria/server/TerrariaServer*
chown -R terraria:terraria /opt/terraria
chmod 600 /opt/terraria/serverconfig.txt

cat > /etc/systemd/system/terraria.service <<'UNIT'
[Unit]
Description=Servidor dedicado de Terraria
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=terraria
WorkingDirectory=/opt/terraria/server
Environment=TERM=xterm
ExecStart=/usr/bin/tmux -L terraria new-session -d -s terraria -x 160 -y 50 \
    /opt/terraria/server/TerrariaServer.bin.x86_64 -config /opt/terraria/serverconfig.txt
# Apagado limpio: "exit" guarda el mundo antes de cerrar.
ExecStop=/bin/sh -c '/usr/bin/tmux -L terraria send-keys -t terraria exit Enter; \
    for i in $(seq 40); do /usr/bin/tmux -L terraria has-session -t terraria 2>/dev/null || exit 0; sleep 1; done'
TimeoutStopSec=50
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now terraria.service
rm -f /root/setup.sh
echo "Servicio terraria activo."
