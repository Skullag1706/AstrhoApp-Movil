# Configuración del Logo de AstrhoApp

## Pasos para reemplazar el icono de la APK

### Opción 1: Usar Flutter Launcher Icons (Recomendado)

1. **Instala la herramienta:**
```bash
flutter pub add --dev flutter_launcher_icons
```

2. **Crea el archivo `flutter_launcher_icons.yaml` en la raíz del proyecto:**
```yaml
flutter_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/logo/astrho_logo.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/logo/astrho_logo_foreground.png"
  min_sdk_android: 21
```

3. **Genera los iconos:**
```bash
flutter pub run flutter_launcher_icons
```

### Opción 2: Convertir SVG a PNG manualmente

Si necesitas convertir el SVG a PNG, puedes usar:

**Con ImageMagick:**
```bash
convert -background none -size 192x192 assets/logo/astrho_logo.svg assets/logo/astrho_logo.png
```

**Con Inkscape:**
```bash
inkscape -w 192 -h 192 assets/logo/astrho_logo.svg -o assets/logo/astrho_logo.png
```

**Con herramientas online:**
- Visita https://cloudconvert.com/svg-to-png
- Sube `assets/logo/astrho_logo.svg`
- Descarga como PNG en 192x192

### Opción 3: Reemplazar manualmente los archivos

Una vez tengas el PNG en 192x192, cópialo a:

**Android:**
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (96x96)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (144x144)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (192x192)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (288x288)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (432x432)

**iOS:**
- Abre `ios/Runner.xcworkspace` en Xcode
- Ve a **Runner > Assets.xcassets > AppIcon**
- Reemplaza todas las imágenes con el logo en los tamaños requeridos

## Tamaños requeridos

| Densidad | Tamaño |
|----------|--------|
| mdpi | 96x96 |
| hdpi | 144x144 |
| xhdpi | 192x192 |
| xxhdpi | 288x288 |
| xxxhdpi | 432x432 |

## Verificar cambios

Después de hacer los cambios:

```bash
flutter clean
flutter pub get
flutter run
```

El nuevo icono debería aparecer en el launcher de Android.
