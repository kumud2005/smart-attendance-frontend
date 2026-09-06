import 'package:flutter/material.dart';

import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';

import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/faculty/faculty_dashboard_screen.dart';
import 'screens/student/student_dashboard_screen.dart'
    if (dart.library.html)
        'screens/student/student_dashboard_web_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

      home: const SessionGate(),
    );
  }
}

// ================================================================
// SESSION GATE
// ================================================================
//
// On every cold app start:
// 1. Read the locally saved access token.
// 2. Reject malformed/expired tokens.
// 3. Restore the saved role.
// 4. Open the correct dashboard without showing Login again.
//
// Explicit logout still clears the stored session.
// ================================================================

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() =>
      _SessionGateState();
}

class _SessionGateState
    extends State<SessionGate> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    Widget destination =
        const LoginScreen();

    try {
      final session =
          await TokenStorage.getValidSession();

      if (session != null) {
        final role =
            session['role_name'];

        switch (role) {
          case 'ADMIN':
            destination =
                const AdminDashboardScreen();
            break;

          case 'FACULTY':
            destination =
                const FacultyDashboardScreen();
            break;

          case 'STUDENT':
            destination =
                const StudentDashboardScreen();
            break;

          default:
            await TokenStorage.clearSession();
            destination =
                const LoginScreen();
        }
      }
    } catch (_) {
      // A corrupted local session must never trap the user
      // on the startup screen.
      await TokenStorage.clearSession();
      destination =
          const LoginScreen();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _destination = destination;
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;

    if (destination != null) {
      return destination;
    }

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
