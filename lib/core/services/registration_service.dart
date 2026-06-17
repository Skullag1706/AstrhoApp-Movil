import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class RegistrationService {
  static const String baseUrl = 'http://www.astrhoapp.somee.com/api';
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Headers para registro (SIN token de autenticación)
  static const Map<String, String> _publicHeaders = {
    'Content-Type': 'application/json',
  };

  /// Verificar si un email ya existe
  static Future<bool> checkEmailExists(String email) async {
    developer.log('🔍 Verificando si email existe: $email');
    try {
      final url = Uri.parse('$baseUrl/Usuarios');
      developer.log('📡 GET: $url');

      final response = await http
          .get(url, headers: _publicHeaders)
          .timeout(timeoutDuration);

      developer.log('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> users = jsonDecode(response.body);
        developer.log('👥 Total usuarios: ${users.length}');

        bool exists = users.any(
          (u) =>
              u["email"].toString().toLowerCase() ==
              email.trim().toLowerCase(),
        );

        developer.log('📌 Email existe: $exists');
        return exists;
      } else if (response.statusCode == 401) {
        // Si el GET requiere autenticación, intentar solo POST
        developer.log('⚠️ GET Usuarios requiere autenticación. Continuando con POST...');
        return false;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      developer.log('🔴 Error al verificar email: $e');
      rethrow;
    }
  }

  /// Registrar un nuevo usuario
  static Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String password,
    required String confirmPassword,
    String? documento,
    String? tipoDocumento,
  }) async {
    developer.log('👤 Registrando usuario: $email');

    try {
      final url = Uri.parse('$baseUrl/Usuarios');
      developer.log('📡 POST: $url');

      final body = {
        "rolId": 2, // Cliente
        "nombreUsuario": email.split('@')[0],
        "email": email.trim(),
        "contrasena": password.trim(),
        "confirmarContrasena": confirmPassword.trim(),
      };

      // Agregar documento y tipoDocumento si se proporcionan
      if (documento != null && documento.isNotEmpty) {
        body["documento"] = documento;
        developer.log('📝 Documento agregado: $documento');
      }
      if (tipoDocumento != null && tipoDocumento.isNotEmpty) {
        body["tipoDocumento"] = tipoDocumento;
        developer.log('📝 Tipo de documento agregado: $tipoDocumento');
      }

      developer.log('📦 Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            url,
            headers: _publicHeaders,
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      developer.log('📊 Status: ${response.statusCode}');
      developer.log('📋 Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Intentar parsear la respuesta como JSON
        try {
          final responseData = jsonDecode(response.body);
          developer.log('✅ Usuario creado: $responseData');
          return responseData;
        } catch (e) {
          developer.log('⚠️ No se pudo parsear respuesta, pero status es 200/201');
          // Retornar los datos del usuario que enviamos
          return {"email": email, "rolId": 2, "documento": documento};
        }
      } else {
        throw Exception(
            'Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      developer.log('🔴 Error al registrar usuario: $e');
      rethrow;
    }
  }

  /// Hacer login después del registro para obtener el ID del usuario
  static Future<Map<String, dynamic>?> loginAfterRegistration(
    String email,
    String password,
  ) async {
    developer.log('🔐 Haciendo login para obtener ID del usuario...');
    developer.log('📧 Email: $email');

    try {
      final url = Uri.parse('$baseUrl/auth/login');
      developer.log('📡 POST: $url');

      final body = {
        "email": email.trim().toLowerCase(),
        "password": password.trim(),
      };

      developer.log('📦 Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            url,
            headers: _publicHeaders,
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      developer.log('📊 Status: ${response.statusCode}');
      developer.log('📋 Response: ${response.body}');

      if (response.statusCode == 200) {
        final loginData = jsonDecode(response.body);
        developer.log('✅ Login exitoso: $loginData');

        // Extraer el ID del usuario
        int? userId;
        
        // Intentar obtener de múltiples campos posibles
        if (loginData['idUsuario'] != null) {
          userId = loginData['idUsuario'] is int 
              ? loginData['idUsuario']
              : int.tryParse(loginData['idUsuario'].toString());
        } else if (loginData['usuarioId'] != null) {
          userId = loginData['usuarioId'] is int 
              ? loginData['usuarioId']
              : int.tryParse(loginData['usuarioId'].toString());
        } else if (loginData['id'] != null) {
          userId = loginData['id'] is int 
              ? loginData['id']
              : int.tryParse(loginData['id'].toString());
        }

        developer.log('🆔 Usuario ID obtenido del login: $userId');
        
        if (userId != null) {
          loginData['idUsuario'] = userId;
        }
        
        return loginData;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      developer.log('🔴 Error al hacer login: $e');
      rethrow;
    }
  }

  /// Registrar datos del cliente CON autenticación
  static Future<bool> registerClientWithAuth({
    required int userId,
    required String documento,
    required String tipoDocumento,
    required String nombre,
    required String telefono,
    required String direccion,
    required String token,
  }) async {
    developer.log('👤 Registrando cliente para usuario: $userId');
    developer.log('🔐 Token recibido: ${token.substring(0, 20)}...');

    try {
      final url = Uri.parse('$baseUrl/Clientes');
      developer.log('📡 POST: $url');

      // Headers CON autenticación
      final authHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      developer.log('📝 Headers completos: $authHeaders');
      developer.log('🔐 Authorization header: Bearer ${token.substring(0, 20)}...');

      final body = {
        "documentoCliente": documento,
        "usuarioId": userId,
        "tipoDocumento": tipoDocumento,
        "nombre": nombre,
        "telefono": telefono,
        "dirección": direccion,
        "estado": true,
      };

      developer.log('📦 Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            url,
            headers: authHeaders,
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      developer.log('📊 Status: ${response.statusCode}');
      developer.log('📋 Response Body: ${response.body}');
      developer.log('📋 Response Headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        developer.log('✅ Cliente registrado exitosamente');
        try {
          final responseData = jsonDecode(response.body);
          developer.log('✅ Respuesta parseada: $responseData');
        } catch (e) {
          developer.log('⚠️ No se pudo parsear respuesta pero status es 200/201');
        }
        return true;
      } else if (response.statusCode == 400) {
        developer.log('❌ Error 400 (Bad Request): ${response.body}');
        throw Exception('Datos inválidos: ${response.body}');
      } else if (response.statusCode == 401) {
        developer.log('❌ Error 401 (Unauthorized)');
        developer.log('⚠️ El token puede estar expirado o inválido');
        throw Exception('No autorizado para registrar cliente');
      } else if (response.statusCode == 500) {
        developer.log('❌ Error 500 (Server Error): ${response.body}');
        throw Exception('Error del servidor: ${response.body}');
      } else {
        developer.log('❌ Error desconocido: ${response.statusCode}');
        throw Exception(
            'Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      developer.log('🔴 Error al registrar cliente: $e');
      rethrow;
    }
  }
}
