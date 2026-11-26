#!/usr/bin/env bash
# Instalador de Terraria LXC Manager para Ubuntu 22.04 / 24.04.
#
#   sudo ./install.sh
#
# Se puede volver a ejecutar sin problema: sirve también para actualizar.
# Variables opcionales:
#   ADMIN_USER=admin ADMIN_PASS=secreto   credenciales del panel (solo la 1.ª vez)
#   SKIP_DOWNLOAD=1                       no descargar el servidor de Terraria ahora
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SHARE_DIR=/opt/terraria-lxc
CONF_DIR=/etc/terraria-lxc
DATA_DIR=/var/lib/terraria-lxc
CLI=/usr/local/sbin/terraria-lxc

paso()  { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
aviso() { printf '\033[1;31m[!] %s\033[0m\n' "$*"; }
fallo() { aviso "$*"; exit 1; }

[[ $EUID -eq 0 ]] || fallo "Ejecuta el instalador como root: sudo ./install.sh"

# shellcheck source=/dev/null
. /etc/os-release
if [[ ${ID:-} != ubuntu ]]; then
    aviso "Este instalador está probado en Ubuntu 22.04 y 24.04. Detectado: ${PRETTY_NAME:-desconocido}."
fi
[[ $(uname -m) == x86_64 ]] || fallo "El servidor de Terraria para Linux solo existe para x86_64."

# --- 1. Paquetes ----------------------------------------------------------
paso "1/7 Instalando Apache, PHP y herramientas"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
# "php" instala la versión que trae cada Ubuntu (8.1 en 22.04, 8.3 en 24.04),
# así no se depende de un php8.x concreto que puede no existir.
apt-get install -y -q apache2 apache2-utils php libapache2-mod-php \
    jq curl unzip snapd iproute2 sudo

PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
a2dismod -q mpm_event >/dev/null 2>&1 || true
a2enmod -q mpm_prefork "php$PHP_VER" headers >/dev/null
echo "PHP $PHP_VER activado en Apache."

# --- 2. LXD ---------------------------------------------------------------
paso "2/7 Comprobando LXD"
if ! command -v lxc >/dev/null && [[ ! -x /snap/bin/lxc ]]; then
    snap wait system seed.loaded
    snap install lxd
fi
export PATH=/snap/bin:$PATH
lxd waitready --timeout=120
if [[ -z $(lxc storage list --format csv 2>/dev/null) ]]; then
    echo "LXD sin configurar: inicializando con valores por defecto..."
    lxd init --auto
fi
lxc network show lxdbr0 >/dev/null 2>&1 || aviso "No existe la red lxdbr0; los contenedores podrían no tener internet."
if command -v docker >/dev/null; then
    aviso "Docker está instalado. Su firewall puede dejar a los contenedores LXD sin internet."
    aviso "Si la creación falla en el paso 4, mira la sección 'Problemas comunes' del README."
fi

# --- 3. Archivos ----------------------------------------------------------
paso "3/7 Copiando archivos"
install -d -m 755 "$SHARE_DIR" "$CONF_DIR"
rm -rf "$SHARE_DIR/web" "$SHARE_DIR/container"
cp -r "$REPO_DIR/web" "$REPO_DIR/container" "$SHARE_DIR/"
install -m 755 "$REPO_DIR/bin/terraria-lxc" "$CLI"
if [[ ! -f $CONF_DIR/terraria-lxc.conf ]]; then
    install -m 644 "$REPO_DIR/etc/terraria-lxc.conf" "$CONF_DIR/terraria-lxc.conf"
else
    echo "Se conserva tu configuración en $CONF_DIR/terraria-lxc.conf"
fi
install -d -m 700 "$DATA_DIR" "$DATA_DIR/servers" "$DATA_DIR/cache" "$DATA_DIR/logs"
chown -R root:root "$SHARE_DIR"
find "$SHARE_DIR/web" -type d -exec chmod 755 {} +
find "$SHARE_DIR/web" -type f -exec chmod 644 {} +

# --- 4. Permisos ----------------------------------------------------------
paso "4/7 Configurando permisos"
# www-data solo puede ejecutar el gestor, que valida todo lo que recibe.
# Nunca lxc directamente: eso equivaldría a darle root a la web.
sudoers=$(mktemp)
echo "www-data ALL=(root) NOPASSWD: $CLI" > "$sudoers"
visudo -cqf "$sudoers" || fallo "La regla de sudoers no es válida."
install -m 440 "$sudoers" /etc/sudoers.d/terraria-lxc
rm -f "$sudoers"
# Versiones anteriores metían a www-data en el grupo lxd (acceso total a LXD).
if id -nG www-data | grep -qw lxd; then
    gpasswd -d www-data lxd >/dev/null
    echo "Quitado www-data del grupo lxd (ya no hace falta)."
fi

# --- 5. Usuario del panel -------------------------------------------------
paso "5/7 Protegiendo el panel con contraseña"
HTPASSWD=$CONF_DIR/htpasswd
CRED_FILE=/root/terraria-lxc-credenciales.txt
NEW_PASS=""
if [[ ! -s $HTPASSWD ]]; then
    ADMIN_USER=${ADMIN_USER:-admin}
    if [[ -n ${ADMIN_PASS:-} ]]; then
        NEW_PASS=$ADMIN_PASS
    else
        NEW_PASS=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')
        NEW_PASS=${NEW_PASS:0:14}
    fi
    htpasswd -cbB "$HTPASSWD" "$ADMIN_USER" "$NEW_PASS" >/dev/null
    printf 'Panel Terraria LXC\nUsuario: %s\nContraseña: %s\n' "$ADMIN_USER" "$NEW_PASS" > "$CRED_FILE"
    chmod 600 "$CRED_FILE"
else
    echo "Se conservan los usuarios existentes ($HTPASSWD)."
    echo "Para cambiar la contraseña: sudo htpasswd -B $HTPASSWD admin"
fi
chown root:www-data "$HTPASSWD"
chmod 640 "$HTPASSWD"

# --- 6. Apache ------------------------------------------------------------
paso "6/7 Configurando Apache"
cat > /etc/apache2/sites-available/terraria-lxc.conf <<APACHE
<VirtualHost *:80>
    DocumentRoot $SHARE_DIR/web
    DirectoryIndex index.html

    <Directory $SHARE_DIR/web>
        Options -Indexes
        AllowOverride None
        AuthType Basic
        AuthName "Terraria LXC"
        AuthUserFile $HTPASSWD
        Require valid-user
    </Directory>

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set Referrer-Policy "same-origin"

    ErrorLog \${APACHE_LOG_DIR}/terraria-lxc-error.log
    CustomLog \${APACHE_LOG_DIR}/terraria-lxc-access.log combined
</VirtualHost>
APACHE
a2dissite -q 000-default >/dev/null 2>&1 || true
a2ensite -q terraria-lxc >/dev/null
apache2ctl configtest
systemctl enable -q apache2
systemctl restart apache2

if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
    # shellcheck source=/dev/null
    . "$CONF_DIR/terraria-lxc.conf"
    ufw allow 80/tcp >/dev/null
    ufw allow "${PORT_MIN:-7777}:${PORT_MAX:-7876}/tcp" >/dev/null
    echo "Abiertos en UFW: 80/tcp y ${PORT_MIN:-7777}-${PORT_MAX:-7876}/tcp."
fi

# --- 7. Servidor de Terraria ---------------------------------------------
paso "7/7 Descargando el servidor de Terraria"
if [[ ${SKIP_DOWNLOAD:-0} == 1 ]]; then
    echo "Omitido (SKIP_DOWNLOAD=1). Se descargará al crear el primer servidor."
else
    "$CLI" prepare || aviso "No se pudo descargar ahora. Se reintentará al crear el primer servidor."
fi

IP=$(hostname -I | awk '{print $1}')
printf '\n\033[1;32mInstalación completada.\033[0m\n'
echo "Panel: http://$IP/"
if [[ -n $NEW_PASS ]]; then
    echo "Usuario: ${ADMIN_USER}"
    echo "Contraseña: $NEW_PASS"
    echo "(Guardada también en $CRED_FILE)"
fi
