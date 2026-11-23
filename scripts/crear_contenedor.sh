#!/bin/bash
# Recibe --contenedor, --semilla, --mundo, --dificultad, --jugadores, --contraseña
CONTAINER=""
SEED=""
WORLD=""
DIFFICULTY=""
PLAYERS=""
PASSWORD=""

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

# 1. Comprobar si existe
if lxc info "$CONTAINER" >/dev/null 2>&1; then
  echo "El contenedor $CONTAINER ya existe."
  exit 0
fi

echo "Creando el contenedor $CONTAINER..."
lxc launch ubuntu:22.04 "$CONTAINER"

# 2. Preparar el config.txt para el contenedor
# Esto es lo que le faltaba a tu terraria.sh, crear las variables TEST_*
cat <<EOF > /tmp/config_contenedor.txt
TEST_WORLD="$WORLD"
TEST_SEED="$SEED"
TEST_DIFFICULTY="$DIFFICULTY"
TEST_PLAYERS="$PLAYERS"
TEST_PORT=7777
TEST_PASSWORD="$PASSWORD"
