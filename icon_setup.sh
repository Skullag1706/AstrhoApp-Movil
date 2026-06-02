#!/bin/bash

# Script para configurar los iconos en Linux/Mac

echo "========================================"
echo "Configurador de Iconos - AstrhoApp"
echo "========================================"
echo ""

# Verificar si Python está instalado
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 no está instalado"
    echo "Instálalo con:"
    echo "  macOS: brew install python3"
    echo "  Linux: sudo apt-get install python3"
    exit 1
fi

echo "Instalando dependencias de Python..."
pip3 install cairosvg pillow

if [ $? -ne 0 ]; then
    echo "Error al instalar dependencias"
    exit 1
fi

echo ""
echo "Generando iconos..."
python3 generate_icons.py

if [ $? -ne 0 ]; then
    echo "Error al generar iconos"
    exit 1
fi

echo ""
echo "Limpiando Flutter..."
flutter clean

echo ""
echo "Obteniendo dependencias..."
flutter pub get

echo ""
echo "========================================"
echo "Iconos configurados exitosamente"
echo "========================================"
echo ""
echo "Próximos pasos:"
echo "1. Ejecuta: flutter run"
echo "2. El nuevo icono debería aparecer en el launcher"
echo ""
