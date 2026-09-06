// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/reset_password_code_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_widgets.dart';

class ResetPasswordCodeScreen extends StatefulWidget {
  final String email;
  const ResetPasswordCodeScreen({super.key, required this.email});

  @override
  State<ResetPasswordCodeScreen> createState() =>
      _ResetPasswordCodeScreenState();
}

class _ResetPasswordCodeScreenState extends State<ResetPasswordCodeScreen> {
  static const _codeLength = 6;
  late final List<TextEditingController> _digitCtrls =
      List.generate(_codeLength, (_) => TextEditingController());
  late final List<FocusNode> _digitFocus =
      List.generate(_codeLength, (_) => FocusNode());
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _codeError;
  String? _passError;
  String? _confirmError;
  bool _done = false;

  String get _code => _digitCtrls.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _digitCtrls) c.dispose();
    for (final f in _digitFocus) f.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _codeLength; i++) {
        _digitCtrls[i].text = i < digits.length ? digits[i] : '';
      }
      final nextIndex =
          digits.length >= _codeLength ? _codeLength - 1 : digits.length;
      _digitFocus[nextIndex].requestFocus();
      setState(() {});
      return;
    }
    if (value.isNotEmpty && index < _codeLength - 1) {
      _digitFocus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _digitFocus[index - 1].requestFocus();
    }
    setState(() {});
  }

  bool _validate() {
    setState(() {
      _codeError = null;
      _passError = null;
      _confirmError = null;
    });
    var ok = true;
    if (_code.length != _codeLength) {
      setState(() => _codeError = 'Introduz o código completo');
      ok = false;
    }
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.isEmpty) {
      setState(() => _passError = 'Cria uma nova password');
      ok = false;
    } else if (pass.length < 6) {
      setState(
          () => _passError = 'A password deve ter pelo menos 6 caracteres');
      ok = false;
    }
    if (confirm.isEmpty) {
      setState(() => _confirmError = 'Confirma a nova password');
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
    final ok = await authController.confirmPasswordReset(
      email: widget.email,
      code: _code,
      newPassword: _passCtrl.text,
    );
    if (ok && mounted) {
      setState(() => _done = true);
    } else if (!ok && mounted) {
      setState(() {});
      if (authController.lastError != null) {
        showAuthSnackBar(context, authController.lastError!);
      }
    }
  }

  void _backToLogin() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _buildDigitBox(int index, AppColorScheme s) {
    return SizedBox(
      width: 46,
      height: 56,
      child: Focus(
        child: TextField(
          controller: _digitCtrls[index],
          focusNode: _digitFocus[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: _codeLength,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: s.onSurface,
          ),
          cursorColor: s.primary,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: s.cardBackground,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: _codeError != null
                      ? s.error
                      : s.outline.withOpacity(0.45)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: _codeError != null
                      ? s.error
                      : s.outline.withOpacity(0.45)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: s.primary, width: 1.5),
            ),
          ),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
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
                            _done
                                ? 'Password atualizada'
                                : 'Introduz o código',
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
                            _done
                                ? 'A tua password foi alterada com sucesso. Já podes iniciar sessão.'
                                : 'Enviámos um código de 6 dígitos para ${widget.email}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                color: s.onSurfaceVariant,
                                height: 1.4),
                          ),
                          const SizedBox(height: 36),

                          if (!_done) ...[
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                _codeLength,
                                (i) => _buildDigitBox(i, s),
                              ),
                            ),
                            if (_codeError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_codeError!,
                                    style: TextStyle(
                                        fontSize: 12, color: s.error)),
                              ),
                            const SizedBox(height: 28),
                            AuthField(
                              ctrl: _passCtrl,
                              hint: 'Nova password',
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
                              hint: 'Confirmar nova password',
                              obscure: _obscureConfirm,
                              errorText: _confirmError,
                              focusNode: _confirmFocus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              suffix: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() =>
                                    _obscureConfirm = !_obscureConfirm),
                                child: AppIcon(
                                  _obscureConfirm
                                      ? 'eye.svg'
                                      : 'eye_off.svg',
                                  size: 16,
                                  color: s.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            AuthPrimaryButton(
                              label: 'Alterar password',
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
                              label: 'Iniciar sessão',
                              loading: false,
                              onTap: _backToLogin,
                            ),
                          ],
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