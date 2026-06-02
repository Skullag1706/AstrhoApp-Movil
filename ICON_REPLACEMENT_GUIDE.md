# Guía: Reemplazar el Icono de la APK de AstrhoApp

## Resumen Rápido

El logo de AstrhoApp (estrella púrpura de 4 puntas) está listo para ser convertido a icono de la APK. Sigue uno de estos métodos:

---

## Método 1: Usar Flutter Launcher Icons (RECOMENDADO)

Este es el método más fácil y automático.

### Paso 1: Instalar la herramienta
```bash
flutter pub add --dev flutter_launcher_icons
```

### Paso 2: Convertir SVG a PNG
Primero necesitas convertir el SVG a PNG. Usa una de estas opciones:

**Opción A: Con ImageMagick (si lo tienes instalado)**
```bash
convert -background none -size 192x192 assets/logo/astrho_logo.svg assets/logo/astrho_logo.png
```

**Opción B: Con Inkscape (si lo tienes instalado)**
```bash
inkscape -w 192 -h 192 assets/logo/astrho_logo.svg -o assets/logo/astrho_logo.png
```

**Opción C: Herramienta online (sin instalar nada)**
1. Ve a https://cloudconvert.com/svg-to-png
2. Sube `assets/logo/astrho_logo.svg`
3. Descarga como PNG (192x192)
4. Guarda en `assets/logo/astrho_logo.png`

### Paso 3: Generar los iconos
```bash
flutter pub run flutter_launcher_icons
```

### Paso 4: Limpiar y ejecutar
```bash
flutter clean
flutter pub get
flutter run
```

---

## Método 2: Script Python Automático

Si tienes Python instalado, puedes usar el script automático.

### Paso 1: Instalar dependencias
```bash
pip install cairosvg pillow
```

### Paso 2: Ejecutar el script
```bash
python3 generate_icons.py
```

Este script:
- Convierte el SVG a PNG automáticamente
- Genera todos los tamaños necesarios para Android
- Genera tamaños comunes para iOS

### Paso 3: Limpiar y ejecutar
```bash
flutter clean
flutter pub get
flutter run
```

---

## Método 3: Reemplazo Manual

Si prefieres hacerlo manualmente:

### Paso 1: Obtener el PNG
Convierte `assets/logo/astrho_logo.svg` a PNG (192x192) usando cualquier herramienta online o de escritorio.

### Paso 2: Reemplazar archivos de Android

Copia el PNG a estos directorios (redimensionando según sea necesario):

```
android/app/src/main/res/mipmap-mdpi/ic_launcher.png (96x96)
android/app/src/main/res/mipmap-hdpi/ic_launcher.png (144x144)
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png (192x192)
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png (288x288)
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png (432x432)
```

### Paso 3: Reemplazar archivos de iOS

1. Abre `ios/Runner.xcworkspace` en Xcode
2. Ve a **Runner > Assets.xcassets > AppIcon**
3. Reemplaza todas las imágenes con el logo en los tamaños requeridos

### Paso 4: Limpiar y ejecutar
```bash
flutter clean
flutter pub get
flutter run
```

---

## Verificar que funcionó

Después de cualquier método:

1. Ejecuta la app: `flutter run`
2. Cierra la app completamente
3. Busca el icono de AstrhoApp en el launcher de Android
4. Debería mostrar la estrella púrpura en lugar del icono de Flutter

---

## Archivos Incluidos

- `assets/logo/astrho_logo.svg` - Logo en formato vectorial
- `flutter_launcher_icons.yaml` - Configuración para flutter_launcher_icons
- `generate_icons.py` - Script Python para generar iconos automáticamente
- `LOGO_SETUP.md` - Documentación técnica detallada

---

## Solución de Problemas

### El icono no cambia después de ejecutar
```bash
flutter clean
flutter pub get
flutter run
```

### En Android, el icono sigue siendo el de Flutter
- Desinstala la app completamente
- Ejecuta `flutter clean`
- Vuelve a instalar con `flutter run`

### En iOS, el icono no cambia
- Abre `ios/Runner.xcworkspace` en Xcode
- Limpia el build: **Product > Clean Build Folder**
- Reconstruye: **Product > Build**

---

## Contacto

Si tienes problemas, verifica que:
1. El archivo SVG existe en `assets/logo/astrho_logo.svg`
2. Tienes Flutter instalado correctamente
3. Ejecutaste `flutter pub get` después de instalar dependencias
