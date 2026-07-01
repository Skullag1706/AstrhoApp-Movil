import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// AUTH SCREENS
import 'auth/screens/login_page.dart';
import 'auth/screens/register_page.dart';
import 'auth/screens/forgot_password_page.dart';
import 'auth/screens/confirm_code_page.dart';
import 'auth/screens/reset_password_page.dart';
import 'auth/screens/home_page.dart';
import 'auth/screens/admin_page.dart';
import 'auth/screens/assistant_page.dart';
import 'auth/screens/profile_page.dart';

// AGENDA
import 'agenda/screens/mis_citas_screen.dart';
import 'agenda/screens/appointment_flow_screen.dart';

// SERVICES
import 'services/screens/services_page.dart';

// THEME
import 'core/utils/colors.dart';

// SESSION
import 'core/services/session_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstrhoApp',
      debugShowCheckedModeBanner: false,

      // 🌍 Localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],

      // 🎨 Tema
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      // 🚦 Ruta inicial - Ahora va a una pantalla de verificación
      initialRoute: '/splash',

      // 🧭 Rutas
      routes: {
        // AUTH
        '/splash': (_) => const SplashScreen(),
        '/': (_) => LoginPage(),
        '/login': (_) => LoginPage(),
        '/register': (_) => RegisterPage(),
        '/forgot-password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final initialEmail = args?['email'] as String?;
          return ForgotPasswordPage(initialEmail: initialEmail);
        },
        '/confirm-code': (_) => ConfirmCodePage(),
        '/reset-password': (_) => ResetPasswordPage(),

        // ROLES
        '/home': (_) => HomePage(),
        '/admin': (_) => AdminPage(),
        '/assistant': (_) => AsistentePage(),

        // AGENDA
        '/mis-citas': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<dynamic, dynamic>?;
          return MisCitasScreen(
            user: args,
            token: args?['token']?.toString(),
          );
        },
        '/appointment-flow': (_) => const AppointmentFlowScreen(),

        // SERVICES
        '/services': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<dynamic, dynamic>?;
          return ServicesPage(
            user: args,
            token: args?['token']?.toString(),
            onAppointmentBooked: () {
              Navigator.pushReplacementNamed(context, '/mis-citas', arguments: args);
            },
          );
        },

        // PERFIL
        '/profile': (_) => ProfilePage(user: const {}),
      },
    );
  }
}

/// Pantalla de splash que verifica si hay sesión activa
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Esperar un poco para que la UI se renderice
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Verificar si hay sesión activa
    final sessionService = SessionService();
    final isActive = await sessionService.isSessionActive();

    print('========================================');
    print('🔍 VERIFICANDO SESIÓN AL INICIAR APP');
    print('========================================');
    print('Sesión activa: $isActive');
    print('========================================');

    if (isActive) {
      // Sesión válida, restaurar y obtener datos del usuario
      print('✅ Sesión válida, restaurando...');
      final userData = await sessionService.restoreSession(() {
        // Callback para cuando expire
        _showSessionExpiredAndNavigateToLogin();
      });
      
      if (userData != null && mounted) {
        // Obtener el rol para saber a dónde navegar
        final rol = userData["rol"].toString().toLowerCase();
        String route = "/home";

        if (rol == "administrador" || 
            rol == "super admin" || 
            rol == "superadmin" || 
            rol == "super administrador") {
          route = "/admin";
        } else if (rol == "asistente") {
          route = "/assistant";
        }

        print('✅ Navegando a: $route');
        Navigator.pushReplacementNamed(context, route, arguments: userData);
      } else if (mounted) {
        print('❌ No se pudieron obtener datos del usuario');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      // No hay sesión, ir a login
      print('❌ No hay sesión activa, ir a login');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _showSessionExpiredAndNavigateToLogin() {
    print('🔄 Sesión expirada durante app runtime');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: AppColors.lightPurpleBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primaryPurple,
                size: 45,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "AstrhoApp",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: AppColors.primaryPurple,
            ),
          ],
        ),
      ),
    );
  }
}
