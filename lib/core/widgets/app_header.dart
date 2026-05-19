import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? trailing;
  final bool showLogo;

  const AppHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.trailing,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6), // Púrpura
            Color(0xFFEC4899), // Rosa
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón de regreso o espacio vacío
              showBackButton
                  ? IconButton(
                      onPressed: onBackPressed ?? () => _handleBackPress(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                  : const SizedBox(width: 48),
              
              // Logo y título
              showLogo
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title.isEmpty ? "AstrhoApp" : title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
              
              // Widget trailing o espacio vacío
              trailing ?? const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBackPress(BuildContext context) {
    // Lógica de navegación inteligente
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // Si no hay páginas en el stack, ir al home
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}

// Widget para el botón de perfil en el header
class ProfileButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const ProfileButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: GestureDetector(
        onTap: onPressed ?? () => Navigator.pushNamed(context, '/profile'),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}