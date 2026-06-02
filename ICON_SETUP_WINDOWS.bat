@echo off
REM Script para configurar los iconos en Windows

echo ========================================
echo Configurador de Iconos - AstrhoApp
echo ========================================
echo.

REM Verificar si Python está instalado
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Python no está instalado o no está en el PATH
    echo Descárgalo desde: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo Instalando dependencias de Python...
pip install cairosvg pillow

if %errorlevel% neq 0 (
    echo Error al instalar dependencias
    pause
    exit /b 1
)

echo.
echo Generando iconos...
python generate_icons.py

if %errorlevel% neq 0 (
    echo Error al generar iconos
    pause
    exit /b 1
)

echo.
echo Limpiando Flutter...
flutter clean

echo.
echo Obteniendo dependencias...
flutter pub get

echo.
echo ========================================
echo Iconos configurados exitosamente
echo ========================================
echo.
echo Próximos pasos:
echo 1. Ejecuta: flutter run
echo 2. El nuevo icono debería aparecer en el launcher
echo.
pause
