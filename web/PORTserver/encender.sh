#!/bin/bash
# Uso: encender.sh <nombre_contenedor>
CONTAINER="$1"
if [ -z "$CONTAINER" ]; then echo "Error: Falta el nombre del contenedor"; exit 1; fi

lxc start "$CONTAINER"
echo "Contenedor $CONTAINER encendido."
