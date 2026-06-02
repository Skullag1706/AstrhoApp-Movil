import 'package:flutter/material.dart';

class AppColors {
  // Colores principales - Esquema Web AstrhoApp
  static const Color primaryPurple = Color(0xFF9B7BFF);
  static const Color primaryPink = Color(0xFFF472D0);
  static const Color darkPurple = Color(0xFF8B6BE8);
  static const Color lightPink = Color(0xFFFFD6F4);
  
  // Gradiente Principal
  static const Color gradientStart = Color(0xFFF472D0);
  static const Color gradientEnd = Color(0xFF9B7BFF);
  
  // Colores de estado - Esquema consistente
  static const Color statusPending = Color(0xFFF472D0);      // Rosa - Pendiente
  static const Color statusConfirmed = Color(0xFF9B7BFF);    // Púrpura - Confirmado
  static const Color statusCompleted = Color(0xFF10B981);    // Verde - Completado
  static const Color statusCancelled = Color(0xFFEF4444);    // Rojo - Cancelado
  
  // Colores de fondo y secundarios
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF5F5F7);
  static const Color lightPurpleBackground = Color(0xFFF1ECFF);
  static const Color borderLight = Color(0xFFE7E7EF);
  
  // Gradientes
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );
  
  // Colores de texto
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGray = Color(0xFF64748B);
  static const Color textWhite = Color(0xFFFFFFFF);
}

