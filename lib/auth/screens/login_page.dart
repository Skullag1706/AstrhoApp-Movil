import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';
import 'package:astrhoapp/core/services/session_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  bool loading = false;
  bool obscure = true;

  Future<void> login() async {
    if (userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      CustomAlert.showError(context, "Ingresa usuario y contraseña");
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("http://www.astrhoapp.somee.com/api/auth/login");

    try {
      print('DEBUG Login: Iniciando petición a $url');
      print('DEBUG Login: Email: ${userCtrl.text.trim().toLowerCase()}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userCtrl.text.trim().toLowerCase(),
          'password': passCtrl.text,
        }),
      );

      print('DEBUG Login: Status code: ${response.statusCode}');
      print('DEBUG Login: Response body: ${response.body}');

      setState(() => loading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('DEBUG Login: Data decoded: $data');

        final rol = data["rol"].toString().toLowerCase();
        print('DEBUG Login: Rol: $rol');

        // Verificar si el usuario está activo/desactivado
        final estado = data["estado"]?.toString().toLowerCase() ?? '';
        final activo = data["activo"] as bool?;
        final desactivado = data["desactivado"] as bool?;
        
        print('DEBUG Login: Estado: $estado, Activo: $activo, Desactivado: $desactivado');
        
        // Validar si el usuario está desactivado
        if (desactivado == true || estado.contains('inactiv') || estado.contains('desactiv') || activo == false) {
          print('DEBUG Login: Usuario desactivado');
          if (mounted) {
            CustomAlert.showError(context, "Este Usuario se encuentra desactivado");
          }
          return;
        }

        // RUTA POR DEFECTO
        String route = "/home";

        if (rol == "administrador" || 
            rol == "super admin" || 
            rol == "superadmin" || 
            rol == "super administrador") {
          route = "/admin";
        } else if (rol == "asistente") {
          route = "/assistant";
        } else if (rol == "cliente") {
          // Siempre ir a home, el modal se maneja ahí
        }

        print('DEBUG Login: Navegando a ruta: $route');

        if (mounted) {
          // Iniciar sesión con callback de expiración (await para asegurar que se guarde)
          await SessionService().startSession(
            () {
              _showSessionExpiredDialog();
            },
            userData: data,
          );
          
          if (mounted) {
            Navigator.pushReplacementNamed(context, route, arguments: data);
          }
        }
        print('DEBUG Login: Navegación completada');
      } else if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
        print('========================================');
        print('🔍 ERROR DE AUTENTICACIÓN');
        print('========================================');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        print('========================================');
        
        // Convertir la respuesta completa a minúsculas para búsqueda
        final fullResponseLower = response.body.toLowerCase();
        
        // Palabras clave para identificar usuario desactivado
        final isDesactivado = fullResponseLower.contains('desactivado') ||
                              fullResponseLower.contains('desactiv') ||
                              fullResponseLower.contains('inactivo') ||
                              fullResponseLower.contains('inactiv') ||
                              fullResponseLower.contains('disabled') ||
                              fullResponseLower.contains('estado') ||
                              fullResponseLower.contains('state') ||
                              fullResponseLower.contains('no se encuentra activo');
        
        print('¿Está desactivado? $isDesactivado');
        print('========================================');
        
        if (isDesactivado) {
          print('✅ Mostrando mensaje de usuario desactivado');
          if (mounted) {
            CustomAlert.showError(context, "Este Usuario se encuentra desactivado");
          }
        } else {
          print('❌ Mostrando mensaje de credenciales incorrectas');
          if (mounted) {
            CustomAlert.showError(context, "Correo o Contraseña incorrectas");
          }
        }
      } else if (response.statusCode == 500) {
        print('DEBUG Login: Error 500 - Servicio no disponible');
        if (mounted) {
          CustomAlert.showError(context, "Este servicio no se encuentra disponible actualmente");
        }
      } else {
        print('DEBUG Login: Error ${response.statusCode}');
        if (mounted) {
          // Intentar extraer mensaje sin mostrar código de error
          try {
            final errorData = jsonDecode(response.body);
            final message = errorData['message']?.toString() ?? 'Ocurrió un error';
            CustomAlert.showError(context, message);
          } catch (_) {
            CustomAlert.showError(context, "Ocurrió un error al iniciar sesión");
          }
        }
      }
    } catch (e, stackTrace) {
      print('DEBUG Login: ERROR CAPTURADO: $e');
      print('DEBUG Login: Stack trace: $stackTrace');
      setState(() => loading = false);
      if (mounted) {
        CustomAlert.showError(context, "Error de conexión: $e");
      }
    }
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lightPurpleBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "AstrhoApp",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo/Icon
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: AppColors.lightPurpleBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: AppColors.primaryPurple,
                            size: 45,
                          ),
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          "Bienvenido",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Inicia sesión para continuar",
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Form
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Correo",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.scaffoldBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: TextField(
                                  controller: userCtrl,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.alternate_email, color: AppColors.textGray),
                                    hintText: "Ingresa tu correo",
                                    hintStyle: TextStyle(color: AppColors.textGray),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                              const Text(
                                "Contraseña",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.scaffoldBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: TextField(
                                  controller: passCtrl,
                                  obscureText: obscure,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textGray),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppColors.textGray,
                                      ),
                                      onPressed: () {
                                        setState(() => obscure = !obscure);
                                      },
                                    ),
                                    hintText: "Ingresa tu contraseña",
                                    hintStyle: const TextStyle(color: AppColors.textGray),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/forgot-password',
                                  ),
                                  child: const Text(
                                    "¿Olvidaste tu contraseña?",
                                    style: TextStyle(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Botón login
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryPurple,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: loading ? null : login,
                                  child: loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: AppColors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          "Iniciar sesión",
                                          style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      "¿Aún no tienes cuenta?",
                                      style: TextStyle(
                                        color: AppColors.textGray,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppColors.primaryPurple, width: 2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pushNamed(context, "/register");
                                        },
                                        child: const Text(
                                          "Regístrate",
                                          style: TextStyle(
                                            color: AppColors.primaryPurple,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Botón de ayuda
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _launchWhatsApp(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "¿Necesitas ayuda? Contáctenos",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUrl = Uri.parse("https://wa.me/573125536381");
    try {
      // Intentar con canLaunchUrl primero
      try {
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        print("canLaunchUrl no disponible: $e");
      }

      // Si canLaunchUrl falla, intentar directamente con launchUrl
      try {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        print("launchUrl falló: $e");
      }

      // Si ambos fallan, mostrar error
      if (mounted) {
        CustomAlert.showError(context, "No se puede abrir WhatsApp. Por favor, visita: https://wa.me/573125536381");
      }
    } catch (e) {
      print("Error general al abrir WhatsApp: $e");
      if (mounted) {
        CustomAlert.showError(context, "Error al abrir WhatsApp");
      }
    }
  }

  /// Mostrar diálogo de sesión expirada
  void _showSessionExpiredDialog() {
    print('========================================');
    print('⚠️ MOSTRANDO DIÁLOGO DE SESIÓN EXPIRADA');
    print('========================================');
    
    // Cerrar la sesión
    SessionService().closeSession();
    
    // Mostrar diálogo solo si estamos en la app
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono de advertencia
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.access_time,
                      size: 70,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Título
                  const Text(
                    "Sesión Expirada",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Mensaje
                  Text(
                    "Tu sesión ha caducado. Por seguridad, debes iniciar sesión nuevamente.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Botón Entendido
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Cerrar diálogo
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'Entendido',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}
