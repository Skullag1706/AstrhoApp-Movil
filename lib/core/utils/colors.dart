import 'package:flutter/material.dart';

class AppColors {
  // Colores principales del diseño de agendamiento
  static const Color primaryPurple = Color(0xFF7926F7);
  static const Color primaryPink = Color(0xFFE54BCF);
  static const Color gradientStart = Color(0xFF9D26F2);
  static const Color gradientEnd = Color(0xFFE9418C);
  static const Color darkPurple = Color(0xFF4C1D95);
  static const Color lightPurpleBackground = Color(0xFFEAD8FF);
  
  // Colores de estado
  static const Color confirmedBlue = Color(0xFF3B82F6);
  static const Color pendingOrange = Color(0xFFF97316);
  
  // Colores de fondo
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF8F9FA);
  
  // Gradientes
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );
  
  // Colores de texto
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGray = Color(0xFF6B7280);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // Colores de bordes
  static const Color borderLight = Color(0xFFE5E7EB);
}

