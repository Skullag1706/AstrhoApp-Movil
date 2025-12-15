import 'package:flutter/material.dart';

class AppColors {
  // Colores principales del gradiente morado/rosado
  static const Color primaryPurple = Color(0xFF6B46C1);
  static const Color primaryPink = Color(0xFFEC4899);
  static const Color darkPurple = Color(0xFF4C1D95);
  static const Color lightPurple = Color(0xFF8B5CF6);
  
  // Colores de estado
  static const Color confirmedBlue = Color(0xFF3B82F6);
  static const Color pendingOrange = Color(0xFFF97316);
  
  // Colores de fondo
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // Gradiente principal
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, primaryPink],
  );
  
  // Colores de texto
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGray = Color(0xFF6B7280);
  static const Color textWhite = Color(0xFFFFFFFF);
}

