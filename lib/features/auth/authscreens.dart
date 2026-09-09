// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/authscreens.dart
// Índice do módulo de auth. Apenas o AuthGate (roteador) vive
// aqui — cada tela tem o seu próprio ficheiro e é reexportada
// abaixo, para quem importa "authscreens.dart" continuar a
// aceder a tudo com um único import.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_widgets.dart';
import 'login_screen.dart';

export 'login_screen.dart';
export 'email_login_screen.dart';
export 'register_screen.dart';
export 'forgot_password_screen.dart';
export 'reset_password_code_screen.dart';
export 'widgets/auth_widgets.dart';
export 'widgets/account_picker_sheet.dart';

// ══════════════════════════════════════════════════════════════
// AUTH GATE
// ══════════════════════════════════════════════════════════════

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    authController.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    switch (authController.status) {
      case AuthStatus.unknown:
        return ColoredBox(
          color: s.surface,
          child: Center(child: AuthLogoFallback(s: s, pulsing: true)),
        );
      case AuthStatus.authenticated:
        return const RootShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}