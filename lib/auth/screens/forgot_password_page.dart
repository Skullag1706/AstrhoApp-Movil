import 'package:flutter/material.dart';
import 'package:astrhoapp/core/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailCtrl = TextEditingController();
  bool loading = false;
  String? emailError;

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Obligatorio";
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return "Correo inválido";
    }
    return null;
  }

  Future<void> requestRecovery() async {
    setState(() {
      emailError = validateEmail(emailCtrl.text);
    });

    if (emailError != null) {
      return;
    }

    setState(() => loading = true);

    try {
      final token = await AuthService.recuperarPassword(emailCtrl.text.trim());

      setState(() => loading = false);

      if (token != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Código enviado a tu correo"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamed(
          context,
          '/confirm-code',
          arguments: {"token": token, "email": emailCtrl.text.trim()},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al recuperar contraseña"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0XFF9D26F2), Color(0XFFE9418C)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset,
                      color: Colors.white,
                      size: 45,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Recuperar contraseña",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Ingresa tu correo para recibir el código",
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  SizedBox(height: 30),
                  Container(
                    width: 340,
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Correo", style: TextStyle(fontSize: 15)),
                        SizedBox(height: 5),
                        TextField(
                          controller: emailCtrl,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.alternate_email),
                            hintText: "Ingresa tu correo",
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            errorText: emailError,
                          ),
                          onChanged: (value) =>
                              setState(() => emailError = validateEmail(value)),
                        ),
                        SizedBox(height: 20),
                        GestureDetector(
                          onTap: loading ? null : requestRecovery,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF9D26F2), Color(0xFFE9418C)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: loading
                                  ? CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      "Enviar código",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              "Volver al inicio de sesión",
                              style: TextStyle(
                                color: Color(0xFF9D26F2),
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
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "© 2025 Todos los derechos reservados",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
