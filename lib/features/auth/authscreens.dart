// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/authscreens.dart
// Índice do módulo de auth. Apenas o AuthGate (roteador) vive
// aqui — cada tela tem o seu próprio ficheiro e é reexportada
// abaixo, para quem importa "authscreens.dart" continuar a
// aceder a tudo com um único import.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/navigation/app_page_route.dart';
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
// Mantém o seu próprio Navigator interno. Isto garante que:
// - a troca entre LoginScreen e RootShell usa a mesma transição
//   (AppPageRoute) que todas as outras telas de auth já usam;
// - o botão "voltar" de cada tela de auth faz sempre pop() para
//   a tela anterior real, nunca cai de novo na LoginScreen à
//   força — porque a LoginScreen só volta a aparecer quando o
//   AuthGate decide substituí-la (logout), não por navegação
//   normal do utilizador.
// ══════════════════════════════════════════════════════════════

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AuthStatus _lastStatus = AuthStatus.unknown;

  @override
  void initState() {
    super.initState();
    _lastStatus = authController.status;
    authController.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final newStatus = authController.status;
    if (newStatus == _lastStatus) return;
    final previousStatus = _lastStatus;
    _lastStatus = newStatus;

    final nav = _navigatorKey.currentState;
    if (nav == null) {
      // Navigator ainda não montado (primeiro build) — o valor
      // inicial do switch abaixo já vai tratar disto.
      if (mounted) setState(() {});
      return;
    }

    switch (newStatus) {
      case AuthStatus.authenticated:
        nav.pushAndRemoveUntil(
          AppPageRoute(builder: (_) => const RootShell()),
          (route) => false,
        );
        break;
      case AuthStatus.unauthenticated:
        if (previousStatus == AuthStatus.authenticated) {
          nav.pushAndRemoveUntil(
            AppPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        break;
      case AuthStatus.unknown:
        break;
    }
  }

  Widget _initialScreen(AppColorScheme s) {
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

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) => AppPageRoute(
        builder: (_) => _initialScreen(s),
        settings: settings,
      ),
    );
  }
}