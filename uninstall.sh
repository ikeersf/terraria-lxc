#!/usr/bin/env bash
# Desinstala Terraria LXC Manager.
#
#   sudo ./uninstall.sh          Quita el panel pero conserva servidores y mundos
#   sudo ./uninstall.sh --purge  Borra también todos los contenedores tlxc-* y sus datos
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecuta: sudo ./uninstall.sh"; exit 1; }
export PATH=/snap/bin:$PATH

a2dissite -q terraria-lxc >/dev/null 2>&1 || true
a2ensite -q 000-default >/dev/null 2>&1 || true
rm -f /etc/apache2/sites-available/terraria-lxc.conf /etc/sudoers.d/terraria-lxc
systemctl reload apache2 2>/dev/null || true

if [[ ${1:-} == --purge ]]; then
    lxc list '^tlxc-' --format csv -c n 2>/dev/null | while read -r ct; do
        echo "Borrando $ct..."
        lxc delete --force "$ct"
    done
    rm -rf /var/lib/terraria-lxc /etc/terraria-lxc /root/terraria-lxc-credenciales.txt
fi

rm -rf /opt/terraria-lxc /usr/local/sbin/terraria-lxc
echo "Terraria LXC Manager desinstalado."
[[ ${1:-} == --purge ]] || echo "Los contenedores tlxc-* y /var/lib/terraria-lxc se han conservado."
