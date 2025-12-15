import 'package:flutter/material.dart';
import 'package:astrhoapp/core/services/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController newPassCtrl = TextEditingController();
  final TextEditingController confirmPassCtrl = TextEditingController();

  bool loading = false;
  bool obscureNew = true;
  bool obscureConfirm = true;

  String? codeError;
  String? newPassError;
  String? confirmPassError;

  String? validateNewPass(String? value) {
    if (value == null || value.isEmpty) {
      return "Obligatorio";
    }
    if (value.length < 6) {
      return "Mín 6 caracteres";
    }
    return null;
  }

  String? validateConfirmPass(String? value) {
    if (value == null || value.isEmpty) {
      return "Obligatorio";
    }
    if (value != newPassCtrl.text) {
      return "No coinciden";
    }
    return null;
  }

  Future<void> resetPassword() async {
    setState(() {
      newPassError = validateNewPass(newPassCtrl.text);
      confirmPassError = validateConfirmPass(confirmPassCtrl.text);
    });

    if (newPassError != null || confirmPassError != null) {
      return;
    }

    setState(() => loading = true);

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final resetToken = args?['resetToken'] as String?;
    
    if (resetToken == null) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Token no encontrado"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Reset the password
      final success = await AuthService.resetPassword(
        resetToken,
        newPassCtrl.text.trim(),
        confirmPassCtrl.text.trim(),
      );

      setState(() => loading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Contraseña cambiada exitosamente"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al cambiar contraseña"),
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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String? ?? '';

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
              child: SingleChildScrollView(
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
                      "Restablecer contraseña",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Ingresa nueva contraseña",
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Correo: $email",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
                          Text(
                            "Nueva contraseña",
                            style: TextStyle(fontSize: 15),
                          ),
                          SizedBox(height: 5),
                          TextField(
                            controller: newPassCtrl,
                            obscureText: obscureNew,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureNew
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() => obscureNew = !obscureNew);
                                },
                              ),
                              hintText: "Ingresa nueva contraseña",
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              errorText: newPassError,
                            ),
                            onChanged: (value) => setState(
                              () => newPassError = validateNewPass(value),
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            "Confirmar contraseña",
                            style: TextStyle(fontSize: 15),
                          ),
                          SizedBox(height: 5),
                          TextField(
                            controller: confirmPassCtrl,
                            obscureText: obscureConfirm,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(
                                    () => obscureConfirm = !obscureConfirm,
                                  );
                                },
                              ),
                              hintText: "Confirma nueva contraseña",
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              errorText: confirmPassError,
                            ),
                            onChanged: (value) => setState(
                              () =>
                                  confirmPassError = validateConfirmPass(value),
                            ),
                          ),
                          SizedBox(height: 20),
                          GestureDetector(
                            onTap: loading ? null : resetPassword,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF9D26F2),
                                    Color(0xFFE9418C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Center(
                                child: loading
                                    ? CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        "Cambiar contraseña",
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
                                "Volver",
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
