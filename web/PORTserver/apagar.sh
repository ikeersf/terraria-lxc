#!/bin/bash
# Uso: apagar.sh <nombre_contenedor>
CONTAINER="$1"
if [ -z "$CONTAINER" ]; then echo "Error: Falta el nombre del contenedor"; exit 1; fi

lxc stop "$CONTAINER"
echo "Contenedor $CONTAINER apagado."
