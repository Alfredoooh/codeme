// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/login_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/local_accounts_service.dart';
import '../../main.dart';
import 'widgets/auth_widgets.dart';
import 'widgets/account_picker_sheet.dart';
import 'email_login_screen.dart';
import 'register_screen.dart';

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

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN — tela principal ao abrir o app.
// Sem logo. Frases motivacionais com efeito de escrita + cursor
// a piscar. Rodapé de termos idêntico à imagem de referência,
// fixo no fundo desta tela.
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  void _goLogin() async {
    authController.clearError();
    final accounts = await LocalAccountsService.load();

    if (!mounted) return;

    if (accounts.isNotEmpty) {
      final chosen = await showAccountPickerSheet(
        context: context,
        accounts: accounts,
      );
      if (!mounted) return;
      if (chosen != null) {
        Navigator.of(context).push(
          AppPageRoute(
            builder: (_) =>
                EmailLoginScreen(prefillIdentifier: chosen.identifier),
          ),
        );
        return;
      }
      Navigator.of(context).push(
        AppPageRoute(builder: (_) => const EmailLoginScreen()),
      );
      return;
    }

    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const EmailLoginScreen()),
    );
  }

  void _goRegister() {
    authController.clearError();
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _onGoogleTap() {
    showAuthSnackBar(
      context,
      'Login com Google indisponível de momento. Usa o email para continuar.',
    );
  }

  void _openTerm(String label) {
    // TODO: ligar a URL real quando disponível.
  }

  TapGestureRecognizer _tapRecognizer(VoidCallback onTap) {
    return TapGestureRecognizer()..onTap = onTap;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            s.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: s.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            s.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: s.pageBackground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: authController,
            builder: (context, _) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 28,
                  right: 28,
                  top: 40,
                  bottom: 28 + MediaQuery.of(context).viewInsets.bottom,
                ),
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        40 -
                        28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo removido — componentes descem mais.
                      const Spacer(flex: 4),

                      // Frases motivacionais maiores, efeito de
                      // escrita com cursor a piscar, sem elastic.
                      const SizedBox(
                        height: 96,
                        child: Center(child: StreamingPhrases()),
                      ),

                      const SizedBox(height: 56),

                      AuthSecondaryButton(
                        icon: const GoogleIcon(size: 20),
                        label: 'Continuar com Google',
                        disabledLook: true,
                        onTap: _onGoogleTap,
                      ),
                      const SizedBox(height: 12),

                      AuthSecondaryButton(
                        icon: AppIcon('mail', size: 20, color: s.onSurface),
                        label: 'Entrar com número de telemóvel ou email',
                        onTap: _goLogin,
                      ),
                      const SizedBox(height: 12),

                      AuthPrimaryButton(
                        label: 'Criar conta',
                        loading: false,
                        onTap: _goRegister,
                      ),

                      const Spacer(flex: 2),

                      // ── Rodapé de termos, idêntico à imagem ──
                      // Fica nesta tela (LoginScreen) porque é a
                      // que aparece ao abrir o app.
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: s.onSurfaceVariant,
                            ),
                            children: [
                              const TextSpan(
                                  text: 'Ao continuar, concordas com os '),
                              TextSpan(
                                text: 'Termos do Consumidor',
                                style: TextStyle(
                                  color: s.onSurfaceVariant,
                                  decoration: TextDecoration.underline,
                                  decorationColor: s.onSurfaceVariant,
                                ),
                                recognizer: _tapRecognizer(
                                    () => _openTerm('consumidor')),
                              ),
                              const TextSpan(text: ' e a '),
                              TextSpan(
                                text: 'Política de Utilização',
                                style: TextStyle(
                                  color: s.onSurfaceVariant,
                                  decoration: TextDecoration.underline,
                                  decorationColor: s.onSurfaceVariant,
                                ),
                                recognizer: _tapRecognizer(
                                    () => _openTerm('utilizacao')),
                              ),
                              const TextSpan(
                                  text:
                                      ' da Anthropic, e reconheces a sua '),
                              TextSpan(
                                text: 'Política de Privacidade',
                                style: TextStyle(
                                  color: s.onSurfaceVariant,
                                  decoration: TextDecoration.underline,
                                  decorationColor: s.onSurfaceVariant,
                                ),
                                recognizer: _tapRecognizer(
                                    () => _openTerm('privacidade')),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}