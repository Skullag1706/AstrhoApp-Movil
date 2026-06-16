import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:astrhoapp/core/services/auth_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController newPassCtrl = TextEditingController();
  final TextEditingController confirmPassCtrl = TextEditingController();

  bool loading = false;
  bool obscureNew = true;
  bool obscureConfirm = true;

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
      if (mounted) {
        CustomAlert.showError(context, "Token no encontrado");
      }
      return;
    }

    try {
      final success = await AuthService.resetPassword(
        resetToken,
        newPassCtrl.text.trim(),
        confirmPassCtrl.text.trim(),
      );

      setState(() => loading = false);

      if (success) {
        if (mounted) {
          CustomAlert.showSuccess(context, "Contraseña cambiada exitosamente");
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        if (mounted) {
          CustomAlert.showError(context, "Error al cambiar contraseña");
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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String? ?? '';

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
                          "Restablecer contraseña",
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ingresa nueva contraseña",
                          style: TextStyle(color: AppColors.textGray, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Correo: $email",
                          style: TextStyle(color: AppColors.textGray, fontSize: 14),
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
                                "Nueva contraseña",
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
                                  controller: newPassCtrl,
                                  obscureText: obscureNew,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(15),
                                  ],
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textGray),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscureNew
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppColors.textGray,
                                      ),
                                      onPressed: () {
                                        setState(() => obscureNew = !obscureNew);
                                      },
                                    ),
                                    hintText: "Ingresa nueva contraseña",
                                    hintStyle: const TextStyle(color: AppColors.textGray),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    errorText: newPassError,
                                  ),
                                  onChanged: (value) => setState(
                                    () => newPassError = validateNewPass(value),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Confirmar contraseña",
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
                                  controller: confirmPassCtrl,
                                  obscureText: obscureConfirm,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(15),
                                  ],
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textGray),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscureConfirm
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppColors.textGray,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => obscureConfirm = !obscureConfirm,
                                        );
                                      },
                                    ),
                                    hintText: "Confirma nueva contraseña",
                                    hintStyle: const TextStyle(color: AppColors.textGray),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    errorText: confirmPassError,
                                  ),
                                  onChanged: (value) => setState(
                                    () =>
                                        confirmPassError = validateConfirmPass(value),
                                  ),
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
                                  onPressed: loading ? null : resetPassword,
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
                                          "Cambiar contraseña",
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
                                    "Volver",
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
