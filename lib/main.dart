import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GHRCE Smart Attendance',
      debugShowCheckedModeBanner: false,

      // ============================================================
      // GH RAISONI APPLICATION THEME
      // ============================================================

      theme: AppTheme.lightTheme,

      // ============================================================
      // ROUTES
      // ============================================================

      routes: {
        '/login': (_) => const LoginScreen(),
      },

      // ============================================================
      // START SCREEN
      // ============================================================

      home: const LoginScreen(),
    );
  }
}