import 'package:flutter/material.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';
import 'package:astrhoapp/agenda/screens/mis_citas_screen.dart';
import 'package:astrhoapp/services/screens/services_page.dart';
import 'package:astrhoapp/auth/screens/profile_page.dart';
import 'package:astrhoapp/core/services/session_service.dart';

class AsistentePage extends StatefulWidget {
  final Map<dynamic, dynamic>? user;

  const AsistentePage({super.key, this.user});

  @override
  State<AsistentePage> createState() => _AsistentePageState();
}

class _AsistentePageState extends State<AsistentePage> {
  Map<dynamic, dynamic>? user;
  bool loading = false;
  int _currentPageIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      if (widget.user != null) {
        user = widget.user;
      } else {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args != null && args is Map) {
          user = args;
        }
      }
      _isInitialized = true;
    }
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _topBar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  "¡Hola, ${user?['nombre'] ?? 'Asistente'}!",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Panel de Asistencia",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textGray,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightPurpleBackground,
                        ),
                        child: const Icon(
                          Icons.support_agent,
                          color: AppColors.primaryPurple,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "¡Bienvenido Asistente!",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Gestiona servicios, citas y clientes",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentPageIndex = 2;
                              _pageController.jumpToPage(2);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Gestionar Citas",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            const Text(
              "AstrhoApp",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.white),
              onPressed: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    CustomAlert.showConfirmDialog(
      context,
      title: 'Cerrar Sesión',
      message: '¿Estás seguro de que deseas cerrar sesión?',
      confirmText: 'Cerrar Sesión',
      cancelText: 'Cancelar',
      isDangerous: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        // Cerrar sesión
        await SessionService().closeSession();
        
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
    });
  }

  Widget _bottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_outlined, 'Inicio', 0),
          _navItem(Icons.auto_awesome, 'Servicios', 1),
          _navItem(Icons.calendar_month, 'Mis Citas', 2),
          _navItem(Icons.person_outline, 'Perfil', 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentPageIndex == index;
    return GestureDetector(
      onTap: () {
        // Renovar sesión en cada actividad del usuario
        SessionService().renewSession();
        
        setState(() {
          _currentPageIndex = index;
          _pageController.jumpToPage(index);
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primaryPurple : AppColors.textGray,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.primaryPurple : AppColors.textGray,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print('========================================');
        print('🔙 BOTÓN ATRÁS PRESIONADO (ASISTENTE)');
        print('========================================');
        print('Current Page Index: $_currentPageIndex');
        
        if (_currentPageIndex == 0) {
          print('📍 Estamos en Home - Mostrando diálogo de logout');
          // Estamos en la pantalla raíz, mostrar diálogo de logout
          _showLogoutDialog();
          return false; // No permitir pop
        } else {
          print('📍 Estamos en otra pantalla - Volviendo a Home');
          // Volver a la pantalla anterior
          setState(() {
            _currentPageIndex = 0;
            _pageController.jumpToPage(0);
          });
          return false; // No permitir pop, nosotros manejamos la navegación
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: user == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
            : PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildHomeScreen(),
                  const ServicesPage(showBottomNav: false),
                  MisCitasScreen(
                    user: user,
                    token: user?['token']?.toString(),
                    showBottomNav: false,
                  ),
                  ProfilePage(user: user!),
                ],
              ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }
}
