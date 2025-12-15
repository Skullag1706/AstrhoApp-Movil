import 'package:flutter/material.dart';
import 'package:astrhoapp/core/utils/colors.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuPressed;

  const AppHeader({
    super.key,
    required this.title,
    this.onBackPressed,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: Column(
        children: [
          Row(
            children: [
              if (onMenuPressed != null)
                IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.white),
                  onPressed: onMenuPressed,
                ),
              const SizedBox(width: 8),
              const Icon(Icons.auto_awesome, color: AppColors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'AstrhoApp',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (onBackPressed != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.darkPurple,
                    ),
                    onPressed: onBackPressed,
                  ),
                  const Text(
                    'Volver',
                    style: TextStyle(
                      color: AppColors.darkPurple,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
