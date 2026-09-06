// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/register_screen.dart
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
import 'email_login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _nameError;
  String? _identifierError;
  String? _passError;
  String? _confirmError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _identifierFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String v) => v.contains('@');

  bool _validate() {
    setState(() {
      _nameError = null;
      _identifierError = null;
      _passError = null;
      _confirmError = null;
    });
    final name = _nameCtrl.text.trim();
    final identifier = _identifierCtrl.text.trim();
    var ok = true;
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty) {
      setState(() => _nameError = 'Introduz o teu nome');
      ok = false;
    }
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
      setState(() => _passError = 'Cria uma password');
      ok = false;
    } else if (pass.length < 6) {
      setState(
          () => _passError = 'A password deve ter pelo menos 6 caracteres');
      ok = false;
    }
    if (confirm.isEmpty) {
      setState(() => _confirmError = 'Confirma a password');
      ok = false;
    } else if (confirm != pass) {
      setState(() => _confirmError = 'As passwords não coincidem');
      ok = false;
    }
    return ok;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    authController.clearError();
    final identifier = _identifierCtrl.text.trim();
    final ok = await authController.register(
      identifier: identifier,
      password: _passCtrl.text,
      name: _nameCtrl.text.trim(),
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
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    if (!ok && mounted) {
      setState(() {});
      if (authController.lastError != null) {
        showAuthSnackBar(context, authController.lastError!);
      }
    }
  }

  void _goLogin() {
    authController.clearError();
    Navigator.of(context).pushReplacement(
      AppPageRoute(builder: (_) => const EmailLoginScreen()),
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
                            'Cria a tua conta',
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
                            'É rápido e gratuito.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: s.onSurfaceVariant),
                          ),
                          const SizedBox(height: 40),

                          AuthField(
                            ctrl: _nameCtrl,
                            hint: 'Nome',
                            errorText: _nameError,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) =>
                                _identifierFocus.requestFocus(),
                          ),
                          const SizedBox(height: 12),
                          AuthField(
                            ctrl: _identifierCtrl,
                            hint: 'Email ou telemóvel',
                            keyboardType: TextInputType.emailAddress,
                            errorText: _identifierError,
                            focusNode: _identifierFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _passFocus.requestFocus(),
                          ),
                          const SizedBox(height: 12),
                          AuthField(
                            ctrl: _passCtrl,
                            hint: 'Password',
                            obscure: _obscurePass,
                            errorText: _passError,
                            focusNode: _passFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) =>
                                _confirmFocus.requestFocus(),
                            suffix: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(
                                  () => _obscurePass = !_obscurePass),
                              child: AppIcon(
                                _obscurePass ? 'eye.svg' : 'eye_off.svg',
                                size: 16,
                                color: s.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AuthField(
                            ctrl: _confirmCtrl,
                            hint: 'Confirmar password',
                            obscure: _obscureConfirm,
                            errorText: _confirmError,
                            focusNode: _confirmFocus,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            suffix: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                              child: AppIcon(
                                _obscureConfirm ? 'eye.svg' : 'eye_off.svg',
                                size: 16,
                                color: s.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          AuthPrimaryButton(
                            label: 'Criar conta',
                            loading: authController.busy,
                            onTap: _submit,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: _goLogin,
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant),
                                  children: [
                                    const TextSpan(text: 'Já tens conta? '),
                                    TextSpan(
                                      text: 'Iniciar sessão',
                                      style: TextStyle(
                                          color: s.primary,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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