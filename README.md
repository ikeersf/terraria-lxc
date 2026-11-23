# Terraria LXC Manager

**Gestor web para desplegar y administrar servidores de Terraria en contenedores LXC.**

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-7c3aed?style=for-the-badge&logo=gnu)](LICENSE)
[![LXD](https://img.shields.io/badge/LXD-5.x-0ea5e9?style=for-the-badge&logo=linuxcontainers&logoColor=white)](https://linuxcontainers.org/lxd/)
[![PHP](https://img.shields.io/badge/PHP-8.1+-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://php.net)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)

---

## Descripción del Proyecto

Terraria LXC Manager es una plataforma self-hosted diseñada para automatizar la creación y gestión de servidores de Terraria. Utiliza la tecnología de contenedores LXC para garantizar el aislamiento total de cada mundo, permitiendo ejecutar múltiples servidores simultáneamente sin conflictos de dependencias ni saturación del sistema anfitrión.

La aplicación cuenta con una interfaz web desarrollada en PHP y HTML/CSS, inspirada en la estética pixel-art del videojuego original, que permite configurar todos los parámetros del servidor de forma visual.

## Arquitectura del Sistema

El flujo de ejecución está dividido en las siguientes capas:

1. **Frontend (web/index.html)**: Formulario de configuración con validación en el lado del cliente.
2. **Backend (web/execute.php)**: Recibe los parámetros del formulario, aplica medidas de seguridad (escapeshellarg) y ejecuta el script maestro.
3. **Orquestador (scripts/crear_contenedor.sh)**: Se encarga de lanzar el contenedor LXC, inyectar los archivos de configuración y ejecutar el proceso de instalación interno.
4. **Instalador Interno (scripts/SecondPart.sh)**: Descarga los binarios oficiales de Terraria, genera el archivo config.txt y arranca el servicio.

Además, incluye un panel de control (web/PORTserver/) para monitorizar el estado de los contenedores, con opciones para encenderlos, apagarlos o eliminarlos.

## Instalación Rápida

Para desplegar el proyecto en un servidor **Ubuntu 20.04 / 22.04** (físico o virtual), ejecuta los siguientes comandos:

```bash
git clone https://github.com/ikeersf/terraria-lxc.git
cd terraria-lxc
sudo ./install.sh
