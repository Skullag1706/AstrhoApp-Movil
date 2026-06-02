# Inicio Rápido: Reemplazar Icono de la APK

## 🚀 Opción Más Rápida (Recomendada)

### En Windows:
```bash
ICON_SETUP_WINDOWS.bat
```

### En Linux/Mac:
```bash
chmod +x icon_setup.sh
./icon_setup.sh
```

---

## 📋 Opción Manual (Sin Scripts)

### Paso 1: Instalar herramienta
```bash
flutter pub add --dev flutter_launcher_icons
```

### Paso 2: Convertir SVG a PNG
Usa una herramienta online:
1. Ve a https://cloudconvert.com/svg-to-png
2. Sube: `assets/logo/astrho_logo.svg`
3. Descarga como PNG (192x192)
4. Guarda en: `assets/logo/astrho_logo.png`

### Paso 3: Generar iconos
```bash
flutter pub run flutter_launcher_icons
```

### Paso 4: Ejecutar
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📁 Archivos Disponibles

| Archivo | Descripción |
|---------|-------------|
| `assets/logo/astrho_logo.svg` | Logo en formato vectorial |
| `flutter_launcher_icons.yaml` | Configuración automática |
| `generate_icons.py` | Script Python para generar iconos |
| `ICON_SETUP_WINDOWS.bat` | Script automático para Windows |
| `icon_setup.sh` | Script automático para Linux/Mac |
| `ICON_REPLACEMENT_GUIDE.md` | Guía completa y detallada |

---

## ✅ Verificar que funcionó

1. Ejecuta: `flutter run`
2. Cierra la app completamente
3. Busca el icono en el launcher
4. Debería mostrar la estrella púrpura

---

## ❓ Problemas?

Si el icono no cambia:
```bash
flutter clean
flutter pub get
flutter run
```

Desinstala la app completamente y vuelve a instalar.

---

## 📞 Más Información

Lee `ICON_REPLACEMENT_GUIDE.md` para instrucciones detalladas y solución de problemas.
