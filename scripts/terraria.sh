#!/bin/bash
# terraria.sh - crea un contenedor LXC con servidor de Terraria
# Uso: terraria.sh --contenedor=X --semilla=Y --mundo=Z --dificultad=D --jugadores=N --contraseña=P

# --- parseo de argumentos ---
CONTAINER=""; SEED=""; WORLD=""; DIFFICULTY=1; PLAYERS=8; PASSWORD=""
for arg in "$@"; do
  case "$arg" in
    --contenedor=*) CONTAINER="${arg#*=}" ;;
    --semilla=*)    SEED="${arg#*=}" ;;
    --mundo=*)      WORLD="${arg#*=}" ;;
    --dificultad=*) DIFFICULTY="${arg#*=}" ;;
    --jugadores=*)  PLAYERS="${arg#*=}" ;;
    --contraseña=*) PASSWORD="${arg#*=}" ;;
  esac
done

if [ -z "$CONTAINER" ] || [ -z "$WORLD" ]; then
  echo "Error: faltan --contenedor o --mundo"
  exit 1
fi

# --- comprobar si ya existe ---
if lxc info "$CONTAINER" >/dev/null 2>&1; then
  echo "El contenedor $CONTAINER ya existe."
  exit 0
fi

echo "Creando el contenedor $CONTAINER..."
lxc launch ubuntu:22.04 "$CONTAINER"

# --- descargar y configurar dentro del contenedor ---
lxc exec "$CONTAINER" -- bash -c "
  apt update && apt install -y wget unzip
  cd /root
  wget -O terraria.zip https://terraria.org/api/download/pc-dedicated-server/terraria-server-1449.zip
  unzip -o terraria.zip
  mkdir -p /root/1449/Linux/Worlds
  cat > /root/1449/Linux/config.txt <<CONF
world=/root/1449/Linux/Worlds/${WORLD}.wld
autocreate=1
seed=${SEED}
worldname=${WORLD}
difficulty=${DIFFICULTY}
maxplayers=${PLAYERS}
port=7777
password=${PASSWORD}
banlist=banlist.txt
secure=1
CONF
  chmod +x /root/1449/Linux/TerrariaServer.bin.x86_64
  cd /root/1449/Linux
  nohup ./TerrariaServer.bin.x86_64 -config config.txt > /root/terraria.log 2>&1 &
"

echo "Servidor creado: $CONTAINER"
lxc list "$CONTAINER"
