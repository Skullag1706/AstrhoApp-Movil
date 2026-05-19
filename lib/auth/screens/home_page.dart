import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/agenda/screens/appointment_flow_screen.dart';
import 'package:astrhoapp/agenda/screens/mis_citas_screen.dart';
// SERVICES
import 'package:astrhoapp/services/screens/services_page.dart';
import 'package:astrhoapp/auth/screens/profile_page.dart';

class HomePage extends StatefulWidget {
  final Map<dynamic, dynamic>? user;

  const HomePage({super.key, this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<dynamic, dynamic>? user;
  bool loading = false;
  int _currentPageIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
                  "¡Hola, ${user?['nombre'] ?? 'Usuario'}!",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "¿Qué deseas hacer hoy?",
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
                          Icons.auto_awesome,
                          color: AppColors.primaryPurple,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "¡Bienvenido a AstrhoApp!",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Tu aplicación para gestionar tu perfil y citas",
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AppointmentFlowScreen(
                                  user: user,
                                  token: user?['token']?.toString(),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Agendar Cita",
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
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.white),
              onPressed: () => _scaffoldKey.currentState!.openDrawer(),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.white,
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
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentPageIndex = 3;
                  _pageController.jumpToPage(3);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final role = user?['rol']?.toString().toLowerCase();
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0XFF9D26F2), Color(0XFFE9418C)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Color(0XFF9D26F2),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  user?['nombre'] ?? "Usuario",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user?['email'] ?? "",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(
                  Icons.home,
                  "Inicio",
                  () {
                    Navigator.pop(context);
                    setState(() {
                      _currentPageIndex = 0;
                      _pageController.jumpToPage(0);
                    });
                  },
                ),
                if (role == "administrador" ||
                    role == "super admin" ||
                    role == "superadmin" ||
                    role == "super administrador")
                  _drawerItem(
                    Icons.admin_panel_settings,
                    "Panel Admin",
                    () async {
                      Navigator.pop(context);
                      setState(() => loading = true);
                      try {
                        await http.get(
                          Uri.parse("http://www.astrhoapp.somee.com/api/Auth/token"),
                        );
                        if (mounted) {
                          Navigator.pushNamed(context, '/admin', arguments: user);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => loading = false);
                        }
                      }
                    },
                  ),
                if (role == "empleado" || role == "asistente")
                  _drawerItem(
                    Icons.assignment,
                    "Panel Asistente",
                    () async {
                      Navigator.pop(context);
                      setState(() => loading = true);
                      try {
                        await http.get(
                          Uri.parse("http://www.astrhoapp.somee.com/api/Auth/token"),
                        );
                        if (mounted) {
                          Navigator.pushNamed(context, '/assistant', arguments: user);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => loading = false);
                        }
                      }
                    },
                  ),
                _drawerItem(
                  Icons.person,
                  "Mi Perfil",
                  () {
                    Navigator.pop(context);
                    setState(() {
                      _currentPageIndex = 3;
                      _pageController.jumpToPage(3);
                    });
                  },
                ),
                const Divider(),
                _drawerItem(
                  Icons.logout,
                  "Cerrar Sesión",
                  () {
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  },
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF7926F7)),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      onTap: onTap,
    );
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffoldBackground,
      drawer: _buildDrawer(context),
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
    );
  }
}
