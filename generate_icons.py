#!/usr/bin/env python3
"""
Script para generar iconos de la APK desde el SVG del logo
Requiere: pip install cairosvg pillow
"""

import os
import sys
from pathlib import Path

try:
    import cairosvg
    from PIL import Image
except ImportError:
    print("Error: Se requieren las librerías 'cairosvg' y 'pillow'")
    print("Instálalas con: pip install cairosvg pillow")
    sys.exit(1)

# Configuración
SVG_PATH = "assets/logo/astrho_logo.svg"
ANDROID_SIZES = {
    "mdpi": 96,
    "hdpi": 144,
    "xhdpi": 192,
    "xxhdpi": 288,
    "xxxhdpi": 432,
}

def generate_android_icons():
    """Genera los iconos para Android en todos los tamaños"""
    
    if not os.path.exists(SVG_PATH):
        print(f"Error: No se encontró {SVG_PATH}")
        return False
    
    print("Generando iconos de Android...")
    
    for density, size in ANDROID_SIZES.items():
        output_dir = f"android/app/src/main/res/mipmap-{density}"
        output_path = os.path.join(output_dir, "ic_launcher.png")
        
        # Crear directorio si no existe
        os.makedirs(output_dir, exist_ok=True)
        
        try:
            # Convertir SVG a PNG
            cairosvg.svg2png(
                url=SVG_PATH,
                write_to=output_path,
                output_width=size,
                output_height=size
            )
            print(f"✓ {density} ({size}x{size}): {output_path}")
        except Exception as e:
            print(f"✗ Error generando {density}: {e}")
            return False
    
    return True

def generate_ios_icons():
    """Genera los iconos para iOS"""
    
    print("\nGenerando iconos de iOS...")
    print("Nota: Los iconos de iOS deben configurarse manualmente en Xcode")
    print("Abre ios/Runner.xcworkspace y ve a Assets.xcassets > AppIcon")
    
    # Generar algunos tamaños comunes para iOS
    ios_sizes = {
        "20": 20,
        "29": 29,
        "40": 40,
        "60": 60,
        "76": 76,
        "83.5": 83,
        "1024": 1024,
    }
    
    ios_dir = "assets/logo/ios"
    os.makedirs(ios_dir, exist_ok=True)
    
    for name, size in ios_sizes.items():
        output_path = os.path.join(ios_dir, f"icon_{name}x{name}.png")
        
        try:
            cairosvg.svg2png(
                url=SVG_PATH,
                write_to=output_path,
                output_width=size,
                output_height=size
            )
            print(f"✓ iOS {name}x{name}: {output_path}")
        except Exception as e:
            print(f"✗ Error generando iOS {name}x{name}: {e}")
    
    return True

def main():
    print("=" * 60)
    print("Generador de Iconos - AstrhoApp")
    print("=" * 60)
    
    success = True
    
    # Generar iconos de Android
    if not generate_android_icons():
        success = False
    
    # Generar iconos de iOS
    if not generate_ios_icons():
        success = False
    
    print("\n" + "=" * 60)
    if success:
        print("✓ Iconos generados exitosamente")
        print("\nPróximos pasos:")
        print("1. Para Android: Los iconos ya están en su lugar")
        print("2. Para iOS: Abre ios/Runner.xcworkspace en Xcode")
        print("3. Ejecuta: flutter clean && flutter pub get && flutter run")
    else:
        print("✗ Hubo errores al generar los iconos")
        sys.exit(1)
    print("=" * 60)

if __name__ == "__main__":
    main()
