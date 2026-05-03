import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Ingresa usuario y contraseña")));
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

        // 🔐 AQUÍ luego guardarás el token (paso siguiente)
        // data["token"]

        Navigator.pushReplacementNamed(context, route, arguments: data);
        print('DEBUG Login: Navegación completada');
      } else {
        print(
          'DEBUG Login: Credenciales inválidas - Status: ${response.statusCode}',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Credenciales inválidas")));
      }
    } catch (e, stackTrace) {
      print('DEBUG Login: ERROR CAPTURADO: $e');
      print('DEBUG Login: Stack trace: $stackTrace');
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            // Main content centered
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ICONO
                  Container(
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock, color: Colors.white, size: 45),
                  ),

                  SizedBox(height: 20),

                  Text(
                    "Bienvenido",
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                  Text(
                    "Inicia sesión para continuar",
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),

                  SizedBox(height: 30),

                  // TARJETA LOGIN
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
                          controller: userCtrl,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.alternate_email),
                            hintText: "Ingresa tu correo",
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        SizedBox(height: 20),
                        Text("Contraseña", style: TextStyle(fontSize: 15)),
                        SizedBox(height: 5),

                        TextField(
                          controller: passCtrl,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => obscure = !obscure);
                              },
                            ),
                            hintText: "Ingresa tu contraseña",
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        SizedBox(height: 10),
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/forgot-password',
                            ),
                            child: Text(
                              "¿Olvidaste tu contraseña?",
                              style: TextStyle(
                                color: Color(0xFF9D26F2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 20),

                        // BOTÓN LOGIN
                        GestureDetector(
                          onTap: loading ? null : login,
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
                                      "Iniciar sesión",
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
                          child: Column(
                            children: [
                              Text(
                                "¿Aún no tienes cuenta?",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, "/register");
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Color(0xFF9D26F2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Regístrate",
                                      style: TextStyle(
                                        color: Color(0xFF9D26F2),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
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
          ],
        ),
      ),
    );
  }
}
