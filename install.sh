#!/bin/bash

# 1. Comprobar permisos de superusuario
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./install.sh)"
  exit 1
fi

echo "▶ 1. Instalando dependencias (Apache, PHP, Wget, Unzip)..."
apt update
apt install -y apache2 php libapache2-mod-php wget unzip curl

echo "▶ 2. Comprobando e inicializando LXD..."
# Si no está el comando lxc, lo instalamos
if ! command -v lxc &> /dev/null; then
    echo "LXD no está instalado. Instalando vía snap..."
    snap install lxd
fi

# Inicializamos LXD si no tiene configuración
if [ ! -d "/var/snap/lxd/common/lxd/database" ] && [ ! -d "/var/lib/lxd/database" ]; then
    lxd init --auto
fi

echo "▶ 3. Copiando archivos web a /var/www/html/..."
mkdir -p /var/www/html
mkdir -p /var/www/scripts
cp -r web/* /var/www/html/
cp -r scripts/* /var/www/scripts/

echo "▶ 4. Dando permisos a los scripts..."
chmod +x /var/www/scripts/*.sh
chmod +x /var/www/html/PORTserver/*.sh 2>/dev/null
chown -R www-data:www-data /var/www/html

echo "▶ 5. Configurando sudoers (para que PHP pueda ejecutar LXD)..."
# Permisos exactos y restringidos para que la web pueda hacer su trabajo
cat > /etc/sudoers.d/terraria-lxc <<SUDO
www-data ALL=(ALL) NOPASSWD: /usr/bin/lxc, /snap/bin/lxc, /bin/bash /var/www/scripts/crear_contenedor.sh, /bin/bash /var/www/html/PORTserver/encender.sh, /bin/bash /var/www/html/PORTserver/apagar.sh, /bin/bash /var/www/html/PORTserver/borrar.sh
SUDO
chmod 440 /etc/sudoers.d/terraria-lxc

echo "▶ 6. Añadiendo www-data al grupo LXD..."
usermod -aG lxd www-data

echo "▶ 7. Reiniciando Apache..."
systemctl restart apache2
systemctl enable apache2

echo ""
echo "✅ ¡Instalación completada!"
echo "🌐 Abre tu navegador y ve a: http://$(hostname -I | awk '{print $1}')/"
