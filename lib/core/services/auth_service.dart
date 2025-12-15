import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static Future<String?> recuperarPassword(String email) async {
    final response = await http.post(
      Uri.parse("http://astrhoapp.somee.com/api/Usuarios/recuperar-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["token"];
    }
    return null;
  }

  static Future<Map<String, dynamic>?> validarCodigoRecuperacion(String token, String codigo) async {
    final response = await http.post(
      Uri.parse("http://astrhoapp.somee.com/api/Usuarios/validar-codigo-recuperacion"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token, "codigo": codigo}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    }
    return null;
  }

  static Future<bool> resetPassword(String resetToken, String nuevaContrasena, String confirmarContrasena) async {
    final response = await http.post(
      Uri.parse("http://astrhoapp.somee.com/api/Usuarios/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"resetToken": resetToken, "nuevaContrasena": nuevaContrasena, "confirmarContrasena": confirmarContrasena}),
    );

    return response.statusCode == 200;
  }

  static Future<bool> hasClientData(int userId) async {
    final response = await http.get(
      Uri.parse("http://astrhoapp.somee.com/api/Clientes"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.any((client) => client['usuarioId'] == userId);
    }
    return false;
  }
}
