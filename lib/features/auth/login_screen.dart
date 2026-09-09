// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/login_screen.dart
// Tela principal ao abrir o app — design alinhado à referência:
// "Contacte-nos" no topo, logo grande centralizado, botões
// descidos para o fim, radio de termos por baixo dos botões.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _termsAccepted = false;

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

  void _onContactTap() {
    showAuthSnackBar(context, 'Contacte-nos ainda não está disponível.');
  }

  void _onTermsTap() {
    // TODO: ligar a URL real quando disponível.
  }

  void _onPrivacyTap() {
    // TODO: ligar a URL real quando disponível.
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

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
              return Column(
                children: [
                  // ── "Contacte-nos" no topo, canto direito ──
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 16),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onContactTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 4),
                          child: Text(
                            'Contacte-nos',
                            style: TextStyle(
                              fontSize: 14,
                              color: s.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Logo grande centralizado, com espaço fixo
                  // acima e abaixo, sem depender de Spacer dentro
                  // de scroll (que colapsa em telas pequenas). ──
                  SizedBox(height: screenHeight * 0.09),
                  const Center(child: AnimatedAuthLogo(size: 96)),
                  SizedBox(height: screenHeight * 0.16),

                  // ── Bloco de botões + termos, sempre no fim. ──
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 28,
                        right: 28,
                        bottom: 28 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (authController.lastError != null) ...[
                            AuthErrorBanner(
                                s: s, message: authController.lastError!),
                            const SizedBox(height: 4),
                          ],

                          AuthSecondaryButton(
                            icon: const GoogleIcon(size: 20),
                            label: 'Continuar com Google',
                            onTap: _onGoogleTap,
                          ),
                          const SizedBox(height: 12),

                          AuthSecondaryButton(
                            icon: LockIcon(size: 20, color: s.onSurface),
                            label: 'Entrar com email ou telemóvel',
                            onTap: _goLogin,
                          ),
                          const SizedBox(height: 12),

                          AuthPrimaryButton(
                            label: 'Criar conta',
                            loading: false,
                            onTap: _goRegister,
                          ),

                          const SizedBox(height: 20),

                          AuthTermsRadio(
                            value: _termsAccepted,
                            onChanged: (v) =>
                                setState(() => _termsAccepted = v),
                            onTapTerms: _onTermsTap,
                            onTapPrivacy: _onPrivacyTap,
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}