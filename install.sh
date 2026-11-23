#!/bin/bash
# Instalador automático de Terraria LXC
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./install.sh)"
  exit 1
fi

echo "▶ 1. Instalando dependencias (Apache, PHP, LXD, unzip)..."
apt update && apt install -y apache2 php libapache2-mod-php lxd wget unzip

echo "▶ 2. Inicializando LXD (si no está configurado)..."
lxd init --auto 2>/dev/null || true

echo "▶ 3. Copiando archivos web a /var/www/html/..."
mkdir -p /var/www/html/PORTserver /var/www/scripts
cp -r web/* /var/www/html/
cp -r scripts/* /var/www/scripts/

echo "▶ 4. Dando permisos a los scripts..."
chmod +x /var/www/scripts/*.sh
chmod +x /var/www/html/PORTserver/*.sh
chown -R www-data:www-data /var/www/html

echo "▶ 5. Configurando sudoers (para que PHP pueda ejecutar LXD)..."
# Damos permisos a www-data para ejecutar lxc y nuestros scripts sin contraseña
cat > /etc/sudoers.d/terraria-lxc <<SUDO
www-data ALL=(ALL) NOPASSWD: /usr/bin/lxc, /bin/bash /var/www/scripts/crear_contenedor.sh, /bin/bash /var/www/html/PORTserver/encender.sh, /bin/bash /var/www/html/PORTserver/apagar.sh, /bin/bash /var/www/html/PORTserver/borrar.sh
SUDO
chmod 440 /etc/sudoers.d/terraria-lxc

echo "▶ 6. Añadiendo www-data al grupo LXD..."
usermod -aG lxd www-data

echo "▶ 7. Reiniciando Apache..."
systemctl restart apache2

echo ""
echo "✅ ¡Instalación completada!"
echo "🌐 Abre tu navegador y ve a: http://$(hostname -I | awk '{print $1}')/"
echo "⚠️  Nota: Si estás en VirtualBox con NAT, recuerda configurar el Redireccionamiento de Puertos (Port Forwarding) para poder acceder."
