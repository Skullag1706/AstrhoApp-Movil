import 'package:flutter/material.dart';
import 'package:astrhoapp/core/services/auth_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;
  
  const ForgotPasswordPage({super.key, this.initialEmail});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailCtrl = TextEditingController();
  bool loading = false;
  String? emailError;

  @override
  void initState() {
    super.initState();
    // Si se proporciona un email inicial, cargarlo en el campo
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
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
        if (mounted) {
          CustomAlert.showSuccess(context, "Código enviado a tu correo");
          Navigator.pushNamed(
            context,
            '/confirm-code',
            arguments: {"token": token, "email": emailCtrl.text.trim()},
          );
        }
      } else {
        if (mounted) {
          CustomAlert.showError(context, "Error al recuperar contraseña");
        }
      }
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        // Limpiar el mensaje de error para no mostrar códigos internos
        String errorMessage = "Error de conexión";
        if (e.toString().contains('500') || e.toString().contains('502')) {
          errorMessage = "Este servicio no se encuentra disponible actualmente";
        }
        CustomAlert.showError(context, errorMessage);
      }
    }
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: AppColors.lightPurpleBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset,
                            color: AppColors.primaryPurple,
                            size: 45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Recuperar contraseña",
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ingresa tu correo para recibir el código",
                          style: TextStyle(color: AppColors.textGray, fontSize: 15),
                        ),
                        const SizedBox(height: 32),
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
                                  controller: emailCtrl,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.alternate_email, color: AppColors.textGray),
                                    hintText: "Ingresa tu correo",
                                    hintStyle: const TextStyle(color: AppColors.textGray),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    errorText: emailError,
                                  ),
                                  onChanged: (value) =>
                                      setState(() => emailError = validateEmail(value)),
                                ),
                              ),
                              const SizedBox(height: 24),
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
                                  onPressed: loading ? null : requestRecovery,
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
                                          "Enviar código",
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
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Text(
                                    "Volver al inicio de sesión",
                                    style: TextStyle(
                                      color: AppColors.primaryPurple,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
