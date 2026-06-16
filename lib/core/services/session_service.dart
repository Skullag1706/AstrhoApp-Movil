import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar sesiones de usuario con expiración persistente
class SessionService {
  static final SessionService _instance = SessionService._internal();
  
  factory SessionService() {
    return _instance;
  }
  
  SessionService._internal();

  /// Duración de la sesión (1 hora)
  static const Duration SESSION_DURATION = Duration(hours: 1);
  
  /// Keys de preferencias
  static const String _SESSION_EXPIRY_KEY = 'session_expiry_time';
  static const String _IS_SESSION_ACTIVE_KEY = 'is_session_active';
  static const String _USER_DATA_KEY = 'user_data_json';
  
  /// Timer para controlar la expiración
  Timer? _sessionTimer;
  
  /// Callback cuando la sesión expira
  VoidCallback? _onSessionExpired;

  /// Iniciar sesión y guardar en persistencia
  Future<void> startSession(VoidCallback? onExpired, {Map<dynamic, dynamic>? userData}) async {
    print('========================================');
    print('🔐 INICIANDO SESIÓN');
    print('========================================');
    print('⏰ Duración: ${SESSION_DURATION.inMinutes} minutos');
    
    _onSessionExpired = onExpired;
    
    // Calcular tiempo de expiración
    final expiryTime = DateTime.now().add(SESSION_DURATION);
    
    // Guardar en preferencias
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_SESSION_EXPIRY_KEY, expiryTime.millisecondsSinceEpoch);
      await prefs.setBool(_IS_SESSION_ACTIVE_KEY, true);
      
      // Guardar datos del usuario si existen
      if (userData != null) {
        final userDataJson = jsonEncode(userData);
        await prefs.setString(_USER_DATA_KEY, userDataJson);
        print('💾 Datos de usuario guardados');
      }
      
      print('💾 Sesión guardada en persistencia');
      print('✅ Sesión iniciada a las: ${DateTime.now()}');
      print('⏰ Expirará a las: $expiryTime');
    } catch (e) {
      print('❌ Error guardando sesión: $e');
    }
    
    // Cancelar timer anterior si existe
    _sessionTimer?.cancel();
    
    // Crear nuevo timer
    _sessionTimer = Timer(SESSION_DURATION, _handleSessionExpired);
    
    print('========================================');
  }

  /// Renovar sesión y guardar en persistencia
  Future<void> renewSession() async {
    print('🔄 RENOVANDO SESIÓN');
    print('⏰ Hora actual: ${DateTime.now()}');
    
    // Calcular nuevo tiempo de expiración
    final expiryTime = DateTime.now().add(SESSION_DURATION);
    
    // Guardar en preferencias
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_SESSION_EXPIRY_KEY, expiryTime.millisecondsSinceEpoch);
      print('💾 Sesión renovada en persistencia');
    } catch (e) {
      print('❌ Error renovando sesión: $e');
    }
    
    // Cancelar timer anterior
    _sessionTimer?.cancel();
    
    // Crear nuevo timer
    _sessionTimer = Timer(SESSION_DURATION, _handleSessionExpired);
    
    print('✅ Sesión renovada');
    print('⏰ Nueva expiración: $expiryTime');
  }

  /// Maneja la expiración de sesión
  void _handleSessionExpired() {
    print('========================================');
    print('❌ SESIÓN EXPIRADA');
    print('========================================');
    print('⏰ Expiración: ${DateTime.now()}');
    
    _onSessionExpired?.call();
  }

  /// Cerrar sesión y limpiar persistencia
  Future<void> closeSession() async {
    print('========================================');
    print('🚪 CERRANDO SESIÓN');
    print('========================================');
    
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _onSessionExpired = null;
    
    // Limpiar preferencias
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_SESSION_EXPIRY_KEY);
      await prefs.remove(_USER_DATA_KEY);
      await prefs.setBool(_IS_SESSION_ACTIVE_KEY, false);
      print('💾 Sesión limpiada de persistencia');
    } catch (e) {
      print('❌ Error limpiando sesión: $e');
    }
    
    print('✅ Sesión cerrada');
    print('========================================');
  }

  /// Obtener datos del usuario guardados
  Future<Map<dynamic, dynamic>?> getSavedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString(_USER_DATA_KEY);
      
      if (userDataJson == null) return null;
      
      final userData = jsonDecode(userDataJson) as Map<dynamic, dynamic>;
      print('✅ Datos de usuario recuperados');
      return userData;
    } catch (e) {
      print('❌ Error recuperando datos de usuario: $e');
      return null;
    }
  }

  /// Obtener tiempo restante de sesión desde persistencia
  Future<Duration?> getTimeRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTimeMs = prefs.getInt(_SESSION_EXPIRY_KEY);
      
      if (expiryTimeMs == null) return null;
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryTimeMs);
      final timeRemaining = expiryTime.difference(DateTime.now());
      
      return timeRemaining.isNegative ? Duration.zero : timeRemaining;
    } catch (e) {
      print('❌ Error obteniendo tiempo restante: $e');
      return null;
    }
  }

  /// Verificar si la sesión está activa desde persistencia
  Future<bool> isSessionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTimeMs = prefs.getInt(_SESSION_EXPIRY_KEY);
      
      if (expiryTimeMs == null) return false;
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryTimeMs);
      final isActive = DateTime.now().isBefore(expiryTime);
      
      print('🔍 Verificando sesión: activa=$isActive, expira=$expiryTime');
      return isActive;
    } catch (e) {
      print('❌ Error verificando sesión: $e');
      return false;
    }
  }

  /// Restaurar sesión desde persistencia (llamar en app startup)
  Future<Map<dynamic, dynamic>?> restoreSession(VoidCallback? onExpired) async {
    print('========================================');
    print('♻️ RESTAURANDO SESIÓN DESDE PERSISTENCIA');
    print('========================================');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTimeMs = prefs.getInt(_SESSION_EXPIRY_KEY);
      final isActive = prefs.getBool(_IS_SESSION_ACTIVE_KEY) ?? false;
      
      if (expiryTimeMs == null || !isActive) {
        print('❌ No hay sesión guardada o está inactiva');
        return null;
      }
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryTimeMs);
      final now = DateTime.now();
      
      if (now.isAfter(expiryTime)) {
        print('❌ Sesión expirada: $expiryTime < $now');
        await closeSession();
        onExpired?.call();
        return null;
      }
      
      // Obtener datos del usuario
      final userData = await getSavedUserData();
      
      // Sesión aún válida
      _onSessionExpired = onExpired;
      final timeRemaining = expiryTime.difference(now);
      
      print('✅ Sesión restaurada');
      print('⏰ Tiempo restante: ${timeRemaining.inMinutes} minutos');
      print('⏰ Expirará a las: $expiryTime');
      if (userData != null) {
        print('👤 Usuario: ${userData['nombre']}');
      }
      
      // Cancelar timer anterior si existe
      _sessionTimer?.cancel();
      
      // Crear nuevo timer con tiempo restante
      _sessionTimer = Timer(timeRemaining, _handleSessionExpired);
      
      print('========================================');
      return userData;
      
    } catch (e) {
      print('❌ Error restaurando sesión: $e');
    }
    
    print('========================================');
    return null;
  }
}
