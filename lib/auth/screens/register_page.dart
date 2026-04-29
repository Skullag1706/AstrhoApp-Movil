import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final confirmEmailController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  final documentoCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  String? tipoDocumento;
  final List<String> tipoDocumentoOptions = ['CC', 'CE', 'TI', 'TE'];

  bool showPass = false;
  bool showConfirmPass = false;
  bool isLoading = false;

  String? nameError;
  String? emailError;
  String? confirmEmailError;
  String? passError;
  String? confirmPassError;
  String? usernameExistsError;
  String? emailExistsError;

  String? documentoError;
  String? nombreClienteError;
  String? telefonoError;
  String? tipoDocumentoError;

  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return "Obligatorio";
    }
    if (value.length < 3) {
      return "Mín 3 caracteres";
    }
    return null;
  }

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

  String? validateConfirmEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Obligatorio";
    }
    if (value != emailController.text) {
      return "No coinciden";
    }
    return null;
  }

  String? validatePass(String? value) {
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
    if (value != passController.text) {
      return "No coinciden";
    }
    return null;
  }

  String? validateDocumento(String? value) {
    if (value == null || value.isEmpty) return "Obligatorio";
    return null;
  }

  String? validateNombreCliente(String? value) {
    if (value == null || value.isEmpty) return "Obligatorio";
    return null;
  }

  String? validateTelefono(String? value) {
    if (value == null || value.isEmpty) return "Obligatorio";
    return null;
  }

  Future<void> checkUsernameExists(String value) async {
    if (value.isEmpty) {
      setState(() => usernameExistsError = null);
      return;
    }
    final checkUrl = Uri.parse("http://astrhoapp.somee.com/api/Usuarios");
    try {
      final checkResponse = await http.get(checkUrl);
      if (checkResponse.statusCode == 200) {
        List<dynamic> users = jsonDecode(checkResponse.body);
        bool userExists = users.any(
          (u) =>
              u["nombreUsuario"].toString().toLowerCase() ==
              value.trim().toLowerCase(),
        );
        setState(
          () => usernameExistsError = userExists ? "Usuario ya existe" : null,
        );
      } else {
        setState(() => usernameExistsError = null);
      }
    } catch (e) {
      setState(() => usernameExistsError = null);
    }
  }

  Future<void> checkEmailExists(String value) async {
    if (value.isEmpty) {
      setState(() => emailExistsError = null);
      return;
    }
    final checkUrl = Uri.parse("http://astrhoapp.somee.com/api/Usuarios");
    try {
      final checkResponse = await http.get(checkUrl);
      if (checkResponse.statusCode == 200) {
        List<dynamic> users = jsonDecode(checkResponse.body);
        bool emailExists = users.any(
          (u) =>
              u["email"].toString().toLowerCase() == value.trim().toLowerCase(),
        );
        setState(
          () => emailExistsError = emailExists ? "Correo ya registrado" : null,
        );
      } else {
        setState(() => emailExistsError = null);
      }
    } catch (e) {
      setState(() => emailExistsError = null);
    }
  }

  Future<void> registerUser() async {
    // Validate all fields
    setState(() {
      nameError = validateName(nameController.text);
      emailError = validateEmail(emailController.text);
      confirmEmailError = validateConfirmEmail(confirmEmailController.text);
      passError = validatePass(passController.text);
      confirmPassError = validateConfirmPass(confirmPassController.text);
      documentoError = validateDocumento(documentoCtrl.text);
      nombreClienteError = validateNombreCliente(nombreCtrl.text);
      telefonoError = validateTelefono(telefonoCtrl.text);
      tipoDocumentoError = tipoDocumento == null ? "Obligatorio" : null;
    });

    if (nameError != null ||
        emailError != null ||
        confirmEmailError != null ||
        passError != null ||
        confirmPassError != null ||
        documentoError != null ||
        nombreClienteError != null ||
        telefonoError != null ||
        tipoDocumentoError != null) {
      showError("Corrige los errores antes de continuar");
      return;
    }

    setState(() => isLoading = true);

    // Check if user or email already exists
    final checkUrl = Uri.parse("http://astrhoapp.somee.com/api/Usuarios");
    try {
      final checkResponse = await http.get(checkUrl);
      if (checkResponse.statusCode == 200) {
        List<dynamic> users = jsonDecode(checkResponse.body);
        bool userExists = users.any(
          (u) =>
              u["nombreUsuario"].toString().toLowerCase() ==
              nameController.text.trim().toLowerCase(),
        );
        bool emailExists = users.any(
          (u) =>
              u["email"].toString().toLowerCase() ==
              emailController.text.trim().toLowerCase(),
        );

        if (userExists) {
          showError("El nombre de usuario ya está en uso");
          return;
        }
        if (emailExists) {
          showError("El correo ya está registrado");
          return;
        }
      } else {
        showError("Error al verificar datos existentes");
        return;
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError("Error de conexión: $e");
      return;
    }

    final url = Uri.parse("http://astrhoapp.somee.com/api/Usuarios");

    final body = {
      "rolId": 2, // 2 = Cliente
      "nombreUsuario": nameController.text.trim(),
      "email": emailController.text.trim(),
      "contrasena": passController.text.trim(),
      "confirmarContrasena": confirmPassController.text.trim(),
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        int? newUserId;
        try {
          final getRes = await http.get(Uri.parse("http://astrhoapp.somee.com/api/Usuarios"));
          if (getRes.statusCode == 200) {
            List<dynamic> users = jsonDecode(getRes.body);
            var createdUser = users.firstWhere(
              (u) => u["email"].toString().toLowerCase() == emailController.text.trim().toLowerCase(),
              orElse: () => null,
            );
            if (createdUser != null) {
              newUserId = createdUser["idUsuario"] ?? createdUser["usuarioId"];
            }
          }
        } catch (e) {
          print("Error obtaining new user ID: $e");
        }

        if (newUserId != null) {
          final clientData = {
            "documentoCliente": documentoCtrl.text,
            "usuarioId": newUserId,
            "tipoDocumento": tipoDocumento,
            "nombre": nombreCtrl.text,
            "telefono": telefonoCtrl.text,
            "estado": true,
          };
          
          final clientRes = await http.post(
            Uri.parse("http://astrhoapp.somee.com/api/Clientes"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(clientData),
          );

          setState(() => isLoading = false);

          if (clientRes.statusCode == 200 || clientRes.statusCode == 201) {
            showSuccess("Usuario creado exitosamente");
            if (mounted) Navigator.pop(context); // Go back to login
          } else {
            showError("Usuario creado, pero hubo un error al guardar datos de cliente");
          }
        } else {
          setState(() => isLoading = false);
          showError("Usuario creado, pero no se pudo obtener su ID");
        }
      } else {
        setState(() => isLoading = false);
        showError("Error: ${response.body}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError("Error de conexión: $e");
    }
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
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
            colors: [Color(0xFFB530F4), Color(0xFFFD3C8D)],
          ),
        ),
        child: Stack(
          children: [
            // Main content centered
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              "Volver",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      // ICONO EMAIL
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mail,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        "Crear cuenta",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // CARD BLANCO
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text("Nombre de usuario"),
                                if (nameError != null ||
                                    usernameExistsError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    nameError ?? usernameExistsError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: nameController,
                              icon: Icons.person,
                              hint: "Ingrese tu nombre de usuario",
                              onChanged: (value) {
                                setState(() => nameError = validateName(value));
                                checkUsernameExists(value);
                              },
                              isError:
                                  nameError != null ||
                                  usernameExistsError != null,
                              isValid:
                                  nameError == null &&
                                  usernameExistsError == null &&
                                  nameController.text.isNotEmpty,
                            ),

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text("Correo"),
                                if (emailError != null ||
                                    emailExistsError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    emailError ?? emailExistsError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: emailController,
                              icon: Icons.mail,
                              hint: "Ingresa tu correo",
                              onChanged: (value) {
                                setState(
                                  () => emailError = validateEmail(value),
                                );
                                checkEmailExists(value);
                              },
                              isError:
                                  emailError != null ||
                                  emailExistsError != null,
                              isValid:
                                  emailError == null &&
                                  emailExistsError == null &&
                                  emailController.text.isNotEmpty,
                            ),

                            const SizedBox(height: 12),
                            const Text("Confirmar correo"),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: confirmEmailController,
                              icon: Icons.mail,
                              hint: "Confirma tu correo",
                              onChanged: (value) => setState(
                                () => confirmEmailError = validateConfirmEmail(
                                  value,
                                ),
                              ),
                              isError: confirmEmailError != null,
                              isValid:
                                  confirmEmailError == null &&
                                  confirmEmailController.text.isNotEmpty,
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text("Contraseña"),
                                if (passError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    passError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: passController,
                              icon: Icons.lock,
                              hint: "Ingresa tu contraseña",
                              isPassword: true,
                              showPassword: showPass,
                              onToggle: () =>
                                  setState(() => showPass = !showPass),
                              onChanged: (value) => setState(
                                () => passError = validatePass(value),
                              ),
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text("Confirmar contraseña"),
                                if (confirmPassError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    confirmPassError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: confirmPassController,
                              icon: Icons.lock,
                              hint: "Confirma tu contraseña",
                              isPassword: true,
                              showPassword: showConfirmPass,
                              onToggle: () => setState(
                                () => showConfirmPass = !showConfirmPass,
                              ),
                              onChanged: (value) => setState(
                                () => confirmPassError = validateConfirmPass(
                                  value,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            const Divider(color: Colors.grey),
                            const SizedBox(height: 10),
                            const Text(
                              "Datos Personales",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7926F7),
                              ),
                            ),
                            const SizedBox(height: 15),

                            Row(
                              children: [
                                const Text("Tipo de Documento"),
                                if (tipoDocumentoError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    tipoDocumentoError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: tipoDocumentoError != null ? Colors.red : Colors.grey.shade300,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 10),
                                  const Icon(Icons.assignment_ind, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: tipoDocumento,
                                      hint: const Text("Selecciona tipo"),
                                      items: tipoDocumentoOptions.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        setState(() {
                                          tipoDocumento = newValue;
                                          tipoDocumentoError = null;
                                        });
                                      },
                                      decoration: const InputDecoration(border: InputBorder.none),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text("Documento Cliente"),
                                if (documentoError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    documentoError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: documentoCtrl,
                              icon: Icons.credit_card,
                              hint: "Ingresa tu documento",
                              onChanged: (value) => setState(() => documentoError = validateDocumento(value)),
                              isError: documentoError != null,
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text("Nombre"),
                                if (nombreClienteError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    nombreClienteError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: nombreCtrl,
                              icon: Icons.person_outline,
                              hint: "Ingresa tu nombre completo",
                              onChanged: (value) => setState(() => nombreClienteError = validateNombreCliente(value)),
                              isError: nombreClienteError != null,
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text("Teléfono"),
                                if (telefonoError != null) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    telefonoError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            inputBox(
                              controller: telefonoCtrl,
                              icon: Icons.phone,
                              hint: "Ingresa tu teléfono",
                              onChanged: (value) => setState(() => telefonoError = validateTelefono(value)),
                              isError: telefonoError != null,
                            ),

                            const SizedBox(height: 25),

                            GestureDetector(
                              onTap: isLoading ? null : registerUser,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7926F7),
                                      Color(0xFFF63D77),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          "Registrarse",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget inputBox({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    bool isError = false,
    bool isValid = false,
  }) {
    Color borderColor = Colors.grey.shade300;
    if (isError) {
      borderColor = Colors.red;
    } else if (isValid) {
      borderColor = Colors.green;
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: isPassword ? !showPassword : false,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
              validator: validator,
              onChanged: onChanged,
            ),
          ),
          if (isPassword)
            IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}
