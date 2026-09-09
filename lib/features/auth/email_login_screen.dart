// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/email_login_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/local_accounts_service.dart';
import 'widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  final String? prefillIdentifier;
  const EmailLoginScreen({super.key, this.prefillIdentifier});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  late final _identifierCtrl =
      TextEditingController(text: widget.prefillIdentifier ?? '');
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _obscure = true;
  String? _identifierError;
  String? _passError;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String v) => v.contains('@');

  bool _validate() {
    setState(() {
      _identifierError = null;
      _passError = null;
    });
    final identifier = _identifierCtrl.text.trim();
    final pass = _passCtrl.text;
    var ok = true;

    if (identifier.isEmpty) {
      setState(() => _identifierError = 'Introduz o teu email ou telemóvel');
      ok = false;
    } else if (_looksLikeEmail(identifier)) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(identifier)) {
        setState(() => _identifierError = 'Email inválido');
        ok = false;
      }
    } else {
      if (!RegExp(r'^\+?\d{8,15}$').hasMatch(identifier)) {
        setState(() => _identifierError = 'Número de telemóvel inválido');
        ok = false;
      }
    }

    if (pass.isEmpty) {
      setState(() => _passError = 'Introduz a tua password');
      ok = false;
    }
    return ok;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    authController.clearError();
    final identifier = _identifierCtrl.text.trim();
    final ok = await authController.login(
      identifier: identifier,
      password: _passCtrl.text,
    );
    if (ok && mounted) {
      final user = authController.user;
      if (user != null) {
        await LocalAccountsService.remember(
          identifier: identifier,
          name: user.name,
          avatar: user.avatar,
          isEmail: _looksLikeEmail(identifier),
        );
      }
      // Login OK: authController já notificou o AuthGate. Aguarda o
      // próximo frame (garante que o AuthGate já reconstruiu para
      // RootShell) antes de fechar esta pilha — corrige o bug de
      // ser preciso "voltar" uma segunda vez para entrar na conta.
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
      return;
    }
    if (!ok && mounted) {
      setState(() {});
      if (authController.lastError != null) {
        showAuthSnackBar(context, authController.lastError!);
      }
    }
  }

  void _goForgot() {
    authController.clearError();
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _goRegister() {
    authController.clearError();
    Navigator.of(context).pushReplacement(
      AppPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return PopScope(
      canPop: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              s.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: s.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              s.isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: s.pageBackground,
          body: SafeArea(
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: authController,
                  builder: (context, _) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 28,
                        right: 28,
                        top: 92,
                        bottom:
                            32 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Iniciar sessão',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: s.onSurface,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Introduz os teus dados para continuar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: s.onSurfaceVariant),
                          ),
                          const SizedBox(height: 40),

                          AuthField(
                            ctrl: _identifierCtrl,
                            hint: 'Email ou telemóvel',
                            keyboardType: TextInputType.emailAddress,
                            errorText: _identifierError,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _passFocus.requestFocus(),
                          ),
                          const SizedBox(height: 12),
                          AuthField(
                            ctrl: _passCtrl,
                            hint: 'Password',
                            obscure: _obscure,
                            errorText: _passError,
                            focusNode: _passFocus,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            suffix: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  setState(() => _obscure = !_obscure),
                              child: AppIcon(
                                _obscure ? 'eye.svg' : 'eye_off.svg',
                                size: 16,
                                color: s.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _goForgot,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'Esqueceste-te da password?',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: s.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          AuthPrimaryButton(
                            label: 'Entrar',
                            loading: authController.busy,
                            onTap: _submit,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: _goRegister,
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant),
                                  children: [
                                    const TextSpan(
                                        text: 'Ainda não tens conta? '),
                                    TextSpan(
                                      text: 'Cria uma',
                                      style: TextStyle(
                                          color: s.primary,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  left: 12,
                  child: AuthBackButton(s: s),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}