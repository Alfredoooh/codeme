// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/forgot_password_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_widgets.dart';
import 'reset_password_code_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  String? _emailError;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    setState(() => _emailError = null);
    if (email.isEmpty) {
      setState(() => _emailError = 'Introduz o teu email');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Email inválido');
      return;
    }
    authController.clearError();
    final ok = await authController.requestPasswordResetCode(email);
    if (ok && mounted) setState(() => _sent = true);
    if (!ok && mounted) {
      setState(() {});
      if (authController.lastError != null) {
        showAuthSnackBar(context, authController.lastError!);
      }
    }
  }

  void _goEnterCode() {
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) =>
            ResetPasswordCodeScreen(email: _emailCtrl.text.trim()),
      ),
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
                            _sent
                                ? 'Verifica o teu email'
                                : 'Recuperar password',
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
                            _sent
                                ? 'Se existir uma conta com esse email, enviámos um código de 6 dígitos.'
                                : 'Introduz o teu email para receberes um código de verificação.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: s.onSurfaceVariant),
                          ),
                          const SizedBox(height: 40),

                          if (!_sent) ...[
                            AuthField(
                              ctrl: _emailCtrl,
                              hint: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              errorText: _emailError,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 28),
                            AuthPrimaryButton(
                              label: 'Enviar código',
                              loading: authController.busy,
                              onTap: _submit,
                            ),
                          ] else ...[
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: s.success
                                      .withOpacity(s.isDark ? 0.18 : 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: AppIcon('check.svg',
                                      color: s.success, size: 26),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AuthPrimaryButton(
                              label: 'Já tenho o código',
                              loading: false,
                              onTap: _goEnterCode,
                            ),
                          ],

                          const SizedBox(height: 48),
                          if (!_sent)
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context)
                                    .popUntil((r) => r.isFirst),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: s.onSurfaceVariant),
                                      children: [
                                        const TextSpan(text: 'Lembraste? '),
                                        TextSpan(
                                          text: 'Volta ao início',
                                          style: TextStyle(
                                              color: s.primary,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
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