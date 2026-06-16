import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';

class ConfirmCodePage extends StatefulWidget {
  const ConfirmCodePage({super.key});

  @override
  _ConfirmCodePageState createState() => _ConfirmCodePageState();
}

class _ConfirmCodePageState extends State<ConfirmCodePage> {
  final List<TextEditingController> codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());
  bool loading = false;
  String? codeError;

  String? validateCode() {
    for (var controller in codeControllers) {
      if (controller.text.isEmpty) {
        return "Obligatorio";
      }
    }
    return null;
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (var controller in codeControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> confirmCode() async {
    setState(() {
      codeError = validateCode();
    });

    if (codeError != null) {
      return;
    }

    setState(() => loading = true);

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final token = args?['token'] as String?;
    final email = args?['email'] as String?;

    if (token == null) {
      setState(() => loading = false);
      if (mounted) {
        CustomAlert.showError(context, "Token no encontrado");
      }
      return;
    }

    try {
      String code = codeControllers.map((c) => c.text).join();
      final validationResult = await AuthService.validarCodigoRecuperacion(
        token,
        code,
      );

      setState(() => loading = false);

      if (validationResult != null && validationResult['valid'] == true) {
        final resetToken = validationResult['resetToken'];
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/reset-password',
            arguments: {"resetToken": resetToken, "email": email},
          );
        }
      } else {
        if (mounted) {
          CustomAlert.showError(context, "Código inválido");
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
                            Icons.key,
                            color: AppColors.primaryPurple,
                            size: 45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Confirmar código",
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ingresa el código enviado a tu correo",
                          style: TextStyle(color: AppColors.textGray, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          email,
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
                                "Código de seguridad",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(6, (index) {
                                  return Container(
                                    width: 48,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.scaffoldBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: codeError != null
                                            ? Colors.red
                                            : AppColors.borderLight,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: codeControllers[index],
                                      focusNode: focusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onChanged: (value) =>
                                          _onCodeChanged(index, value),
                                    ),
                                  );
                                }),
                              ),
                              if (codeError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    codeError!,
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
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
                                  onPressed: loading ? null : confirmCode,
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
                                          "Confirmar código",
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
