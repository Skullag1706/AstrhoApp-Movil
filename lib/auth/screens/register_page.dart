import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';
import 'package:astrhoapp/core/services/registration_service.dart';
import 'dart:developer' as developer;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  final documentoCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  String? tipoDocumento;
  final List<String> tipoDocumentoOptions = ['CC', 'CE', 'TI', 'NIT'];

  bool showPass = false;
  bool showConfirmPass = false;
  bool isLoading = false;

  String? emailError;
  String? passError;
  String? confirmPassError;
  String? emailExistsError;

  String? documentoError;
  String? nombreClienteError;
  String? telefonoError;
  String? tipoDocumentoError;
  String? direccionError;

  String? validateDireccion(String? value) {
    // La dirección es opcional, así que no retornamos error si está vacía
    if (value != null && value.isNotEmpty && value.length < 5) {
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
    if (value.length < 7) return "Mín 7 caracteres";
    if (value.length > 10) return "Máx 10 caracteres";
    return null;
  }

  String? validateNombreCliente(String? value) {
    if (value == null || value.isEmpty) return "Obligatorio";
    if (value.length < 5) return "Mín 5 caracteres";
    return null;
  }

  String? validateTelefono(String? value) {
    if (value == null || value.isEmpty) return "Obligatorio";
    if (value.length != 10) return "Debe ser 10 caracteres";
    return null;
  }

  Future<void> checkEmailExists(String value) async {
    if (value.isEmpty) {
      setState(() => emailExistsError = null);
      return;
    }
    try {
      bool exists = await RegistrationService.checkEmailExists(value);
      setState(
        () => emailExistsError = exists ? "Correo ya registrado" : null,
      );
    } catch (e) {
      developer.log('⚠️ Error al verificar email: $e');
      setState(() => emailExistsError = null);
    }
  }

  Future<void> registerUser() async {
    developer.log('🔵 INICIO DE REGISTRO DE USUARIO');
    
    setState(() {
      emailError = validateEmail(emailController.text);
      passError = validatePass(passController.text);
      confirmPassError = validateConfirmPass(confirmPassController.text);
      documentoError = validateDocumento(documentoCtrl.text);
      nombreClienteError = validateNombreCliente(nombreCtrl.text);
      telefonoError = validateTelefono(telefonoCtrl.text);
      tipoDocumentoError = tipoDocumento == null ? "Obligatorio" : null;
      direccionError = validateDireccion(direccionCtrl.text);
    });

    developer.log('📋 Validación de campos completada');

    if (emailError != null ||
        passError != null ||
        confirmPassError != null ||
        documentoError != null ||
        nombreClienteError != null ||
        telefonoError != null ||
        tipoDocumentoError != null) {
      developer.log('❌ Validación fallida: hay errores en los campos');
      showError("Corrige los errores antes de continuar");
      return;
    }

    developer.log('✅ Todos los campos son válidos');
    setState(() => isLoading = true);

    try {
      // 1️⃣ Verificar que el email no exista
      developer.log('🔄 PASO 1: Verificando si el email ya existe...');
      bool emailExists = await RegistrationService.checkEmailExists(
        emailController.text,
      );

      if (emailExists) {
        developer.log('⚠️ Email ya registrado');
        setState(() => isLoading = false);
        showError("El correo ya está registrado");
        return;
      }

      developer.log('✅ Email disponible');

      // 2️⃣ Registrar usuario
      developer.log('🔄 PASO 2: Registrando usuario en la API...');
      await RegistrationService.registerUser(
        email: emailController.text.trim(),
        password: passController.text.trim(),
        confirmPassword: confirmPassController.text.trim(),
        documento: documentoCtrl.text.trim(),
        tipoDocumento: tipoDocumento,
      );

      developer.log('✅ Usuario registrado');

      // 3️⃣ Hacer login para obtener el ID
      developer.log('🔄 PASO 3: Obteniendo ID del usuario mediante login...');
      Map<String, dynamic>? loginData = await RegistrationService.loginAfterRegistration(
        emailController.text.trim(),
        passController.text.trim(),
      );

      if (loginData == null) {
        developer.log('⚠️ No se pudo obtener datos del usuario');
        setState(() => isLoading = false);
        showError("Usuario creado, pero no se pudo obtener sus datos");
        return;
      }

      developer.log('✅ Login exitoso, datos obtenidos');

      // Extraer ID
      int? userId = loginData['idUsuario'];
      if (userId == null || userId == 0) {
        developer.log('⚠️ No se pudo obtener el ID del usuario de los datos de login');
        setState(() => isLoading = false);
        showError("Usuario creado, pero no se pudo obtener su ID");
        return;
      }

      developer.log('✅ ID del usuario: $userId');

      // 4️⃣ Registrar datos del cliente
      developer.log('🔄 PASO 4: Registrando datos del cliente...');
      
      // Extraer el token del login
      String? token = loginData['token'];
      developer.log('🔐 Token extraído: ${token != null ? token.substring(0, 20) + '...' : 'NULL'}');
      developer.log('🔐 Token length: ${token?.length}');
      developer.log('🔐 Token null check: ${token == null}');
      developer.log('🔐 Token empty check: ${token?.isEmpty}');
      
      if (token == null || token.isEmpty) {
        developer.log('⚠️ No se pudo obtener el token de autenticación');
        setState(() => isLoading = false);
        showError("Error de autenticación al registrar cliente");
        return;
      }
      
      developer.log('✅ Token obtenido para autenticación - pasando a servicio');
      
      bool clientRegistered = await RegistrationService.registerClientWithAuth(
        userId: userId,
        documento: documentoCtrl.text,
        tipoDocumento: tipoDocumento!,
        nombre: nombreCtrl.text,
        telefono: telefonoCtrl.text,
        direccion: direccionCtrl.text,
        token: token,
      );

      setState(() => isLoading = false);

      if (clientRegistered) {
        developer.log('✅ REGISTRO COMPLETADO EXITOSAMENTE');
        showSuccess("Usuario creado exitosamente");
        if (mounted) Navigator.pop(context);
      } else {
        developer.log('❌ Error al registrar cliente');
        showError("Error al guardar datos del cliente");
      }
    } catch (e) {
      developer.log('🔴 ERROR: $e');
      setState(() => isLoading = false);
      showError("Error: $e");
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
    int maxLength = 100,
    List<TextInputFormatter>? inputFormatters,
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
              inputFormatters: [
                LengthLimitingTextInputFormatter(maxLength),
                ...?inputFormatters,
              ],
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
                                    initialValue: tipoDocumento,
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
                          _buildLabel("Documento", documentoError),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBackground,
                              border: Border.all(
                                color: documentoError != null ? Colors.red : AppColors.borderLight,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                const Icon(Icons.credit_card, color: AppColors.textGray),
                                const SizedBox(width: 10),
                                if (tipoDocumento != null && tipoDocumento!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      tipoDocumento!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                if (tipoDocumento != null && tipoDocumento!.isNotEmpty)
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: AppColors.borderLight,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                Expanded(
                child: TextFormField(
                  controller: documentoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(15),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: "Ingresa tu documento",
                    hintStyle: const TextStyle(color: AppColors.textGray),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (value) => setState(() => documentoError = validateDocumento(value)),
                ),
              ),
                              ],
                            ),
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
                            maxLength: 100,
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
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                          const SizedBox(height: 16),
                          _buildLabel("Dirección", direccionError, isRequired: false),
                          const SizedBox(height: 8),
                          inputBox(
                            controller: direccionCtrl,
                            icon: Icons.location_on,
                            hint: "Ingresa tu dirección",
                            onChanged: (value) => setState(() => direccionError = validateDireccion(value)),
                            isError: direccionError != null,
                            maxLength: 100,
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: AppColors.borderLight),
                          const SizedBox(height: 20),
                          const Text(
                            "Datos de Usuario",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                            maxLength: 100,
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
                            maxLength: 15,
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
                            maxLength: 15,
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

  Widget _buildLabel(String text, String? error, {bool isRequired = true}) {
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
        if (isRequired)
          const Text(
            " *",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.red,
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
