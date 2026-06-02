import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final confirmEmailController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  final documentoCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  String? tipoDocumento;
  final List<String> tipoDocumentoOptions = ['CC', 'CE', 'TI', 'TE'];

  bool showPass = false;
  bool showConfirmPass = false;
  bool isLoading = false;

  String? emailError;
  String? confirmEmailError;
  String? passError;
  String? confirmPassError;
  String? emailExistsError;

  String? documentoError;
  String? nombreClienteError;
  String? telefonoError;
  String? tipoDocumentoError;
  String? direccionError;

  String? validateDireccion(String? value) {
    if (value == null || value.isEmpty) {
      return "Obligatorio";
    }
    if (value.length < 5) {
      return "Mín 5 caracteres";
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

  Future<void> checkEmailExists(String value) async {
    if (value.isEmpty) {
      setState(() => emailExistsError = null);
      return;
    }
    final checkUrl = Uri.parse("http://www.astrhoapp.somee.com/api/Usuarios");
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
    setState(() {
      emailError = validateEmail(emailController.text);
      confirmEmailError = validateConfirmEmail(confirmEmailController.text);
      passError = validatePass(passController.text);
      confirmPassError = validateConfirmPass(confirmPassController.text);
      documentoError = validateDocumento(documentoCtrl.text);
      nombreClienteError = validateNombreCliente(nombreCtrl.text);
      telefonoError = validateTelefono(telefonoCtrl.text);
      tipoDocumentoError = tipoDocumento == null ? "Obligatorio" : null;
      direccionError = validateDireccion(direccionCtrl.text);
    });

    if (emailError != null ||
        confirmEmailError != null ||
        passError != null ||
        confirmPassError != null ||
        documentoError != null ||
        nombreClienteError != null ||
        telefonoError != null ||
        tipoDocumentoError != null ||
        direccionError != null) {
      showError("Corrige los errores antes de continuar");
      return;
    }

    setState(() => isLoading = true);

    final checkUrl = Uri.parse("http://www.astrhoapp.somee.com/api/Usuarios");
    try {
      final checkResponse = await http.get(checkUrl);
      if (checkResponse.statusCode == 200) {
        List<dynamic> users = jsonDecode(checkResponse.body);
        bool emailExists = users.any(
          (u) =>
              u["email"].toString().toLowerCase() ==
              emailController.text.trim().toLowerCase(),
        );

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

    final url = Uri.parse("http://www.astrhoapp.somee.com/api/Usuarios");

    final body = {
      "rolId": 2,
      "nombreUsuario": emailController.text.split('@')[0],
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
          final getRes = await http.get(Uri.parse("http://www.astrhoapp.somee.com/api/Usuarios"));
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
            "direccion": direccionCtrl.text,
            "estado": true,
          };
          
          final clientRes = await http.post(
            Uri.parse("http://www.astrhoapp.somee.com/api/Clientes"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(clientData),
          );

          setState(() => isLoading = false);

          if (clientRes.statusCode == 200 || clientRes.statusCode == 201) {
            showSuccess("Usuario creado exitosamente");
            if (mounted) Navigator.pop(context);
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
    CustomAlert.showError(context, msg);
  }

  void showSuccess(String msg) {
    CustomAlert.showSuccess(context, msg);
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, color: AppColors.primaryPurple),
                const SizedBox(width: 6),
                const Text(
                  "Volver",
                  style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
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

  Widget inputBox({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onToggle,
    Function(String)? onChanged,
    bool isError = false,
  }) {
    Color borderColor = AppColors.borderLight;
    if (isError) {
      borderColor = Colors.red;
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, color: AppColors.textGray),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: isPassword ? !showPassword : false,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textGray),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: onChanged,
            ),
          ),
          if (isPassword)
            IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textGray,
              ),
              onPressed: onToggle,
            ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurpleBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1,
                        color: AppColors.primaryPurple,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Crear cuenta",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Completa tus datos para registrarte",
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                          _buildLabel("Correo", emailError ?? emailExistsError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: emailController,
                            icon: Icons.alternate_email,
                            hint: "Ingresa tu correo",
                            onChanged: (value) {
                              setState(() => emailError = validateEmail(value));
                              checkEmailExists(value);
                            },
                            isError: emailError != null || emailExistsError != null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Confirmar correo", confirmEmailError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: confirmEmailController,
                            icon: Icons.alternate_email,
                            hint: "Confirma tu correo",
                            onChanged: (value) => setState(() => confirmEmailError = validateConfirmEmail(value)),
                            isError: confirmEmailError != null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Contraseña", passError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: passController,
                            icon: Icons.lock_outline,
                            hint: "Ingresa tu contraseña",
                            isPassword: true,
                            showPassword: showPass,
                            onToggle: () => setState(() => showPass = !showPass),
                            onChanged: (value) => setState(() => passError = validatePass(value)),
                            isError: passError != null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Confirmar contraseña", confirmPassError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: confirmPassController,
                            icon: Icons.lock_outline,
                            hint: "Confirma tu contraseña",
                            isPassword: true,
                            showPassword: showConfirmPass,
                            onToggle: () => setState(() => showConfirmPass = !showConfirmPass),
                            onChanged: (value) => setState(() => confirmPassError = validateConfirmPass(value)),
                            isError: confirmPassError != null,
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: AppColors.borderLight),
                          const SizedBox(height: 20),
                          const Text(
                            "Datos Personales",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildLabel("Tipo de Documento", tipoDocumentoError),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBackground,
                              border: Border.all(
                                color: tipoDocumentoError != null ? Colors.red : AppColors.borderLight,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                const Icon(Icons.assignment_ind, color: AppColors.textGray),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tipoDocumento,
                                    hint: const Text("Selecciona tipo", style: TextStyle(color: AppColors.textGray)),
                                    items: tipoDocumentoOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value, style: const TextStyle(color: AppColors.textDark)),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      setState(() {
                                        tipoDocumento = newValue;
                                        tipoDocumentoError = null;
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Documento Cliente", documentoError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: documentoCtrl,
                            icon: Icons.credit_card,
                            hint: "Ingresa tu documento",
                            onChanged: (value) => setState(() => documentoError = validateDocumento(value)),
                            isError: documentoError != null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Nombre", nombreClienteError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: nombreCtrl,
                            icon: Icons.person_outline,
                            hint: "Ingresa tu nombre completo",
                            onChanged: (value) => setState(() => nombreClienteError = validateNombreCliente(value)),
                            isError: nombreClienteError != null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Teléfono", telefonoError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: telefonoCtrl,
                            icon: Icons.phone,
                            hint: "Ingresa tu teléfono",
                            onChanged: (value) => setState(() => telefonoError = validateTelefono(value)),
                            isError: telefonoError != null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Dirección", direccionError),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: direccionCtrl,
                            icon: Icons.location_on,
                            hint: "Ingresa tu dirección",
                            onChanged: (value) => setState(() => direccionError = validateDireccion(value)),
                            isError: direccionError != null,
                          ),
                          const SizedBox(height: 28),
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
                              onPressed: isLoading ? null : registerUser,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: AppColors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Registrarse",
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, String? error) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        if (error != null) ...[
          const SizedBox(width: 10),
          Text(
            error,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
