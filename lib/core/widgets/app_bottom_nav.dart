import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;
  final Map<dynamic, dynamic>? user;

  const AppBottomNav({
    super.key,
    required this.currentRoute,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            Icons.home,
            "Inicio",
            '/home',
            currentRoute == '/home',
          ),
          _buildNavItem(
            context,
            Icons.auto_awesome,
            "Servicios",
            '/services',
            currentRoute == '/services',
          ),
          _buildNavItem(
            context,
            Icons.calendar_today,
            "Mis Citas",
            '/mis-citas',
            currentRoute == '/mis-citas',
          ),
          _buildNavItem(
            context,
            Icons.person,
            "Perfil",
            '/profile',
            currentRoute == '/profile',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
    bool isActive,
  ) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.pushReplacementNamed(context, route, arguments: user);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF8B5CF6) : Colors.grey[600],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF8B5CF6) : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}