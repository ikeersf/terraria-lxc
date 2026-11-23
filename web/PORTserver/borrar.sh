#!/bin/bash
# Uso: borrar.sh <nombre_contenedor>
CONTAINER="$1"
if [ -z "$CONTAINER" ]; then echo "Error: Falta el nombre del contenedor"; exit 1; fi

lxc stop "$CONTAINER" --force 2>/dev/null
lxc delete "$CONTAINER"
echo "Contenedor $CONTAINER borrado."
