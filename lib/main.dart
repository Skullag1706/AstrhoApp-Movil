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

// THEME
import 'core/utils/colors.dart';

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

      // 🚦 Ruta inicial
      initialRoute: '/login',

      // 🧭 Rutas
      routes: {
        // AUTH
        '/': (_) => LoginPage(),
        '/login': (_) => LoginPage(),
        '/register': (_) => RegisterPage(),
        '/forgot-password': (_) => ForgotPasswordPage(),
        '/confirm-code': (_) => ConfirmCodePage(),
        '/reset-password': (_) => ResetPasswordPage(),

        // ROLES
        '/home': (_) => HomePage(),
        '/admin': (_) => AdminPage(),
        '/assistant': (_) => AsistentePage(),

        // AGENDA
        '/mis-citas': (_) => const MisCitasScreen(),

        // PERFIL
        '/profile': (_) => ProfilePage(user: const {}),
      },
    );
  }
}
