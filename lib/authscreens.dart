// ══════════════════════════════════════════════════════════════
// FILE: lib/authscreens.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'main.dart';

// ══════════════════════════════════════════════════════════════
// AUTH GATE — decide entre Login/Register e a app, conforme sessão
// ══════════════════════════════════════════════════════════════

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
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

  void _onAuthChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    switch (authController.status) {
      case AuthStatus.unknown:
        return ColoredBox(
          color: s.pageBackground,
          child: Center(
            child: _AuthLogo(s: s, pulsing: true),
          ),
        );
      case AuthStatus.authenticated:
        return const RootShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED — logo (fallback), campo de texto, botão principal
// ══════════════════════════════════════════════════════════════

// Mantido apenas como fallback do AuthGate (estado "unknown", antes
// de sabermos se há sessão) e para o pulsing inicial — a tela de
// LOGIN em si já não usa isto, usa background1.png no topo.
class _AuthLogo extends StatelessWidget {
  final AppColorScheme s;
  final bool pulsing;
  const _AuthLogo({required this.s, this.pulsing = false});

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/logo.png',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 64, height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('N',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: s.onPrimary,
              )),
        ),
      ),
    );
    if (!pulsing) return logo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: kCupertino,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: value, child: child),
      ),
      child: logo,
    );
  }
}

// ── Ilustração de topo (background1.png) — usada só no Login. Altura
// própria (não full-bleed até ao fim), com o título/tagline sobrepostos
// na base da imagem, exatamente como o padrão de referência (Kimi):
// imagem → título → formulário como blocos empilhados, não como
// overlay semi-transparente por cima de tudo.
class _AuthHeroImage extends StatelessWidget {
  final double height;
  const _AuthHeroImage({required this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: Image.asset(
          'assets/images/background1.jpg',
          fit: BoxFit.cover,
          // Fallback silencioso: se o asset faltar, não quebra o
          // layout — some e o título sobe naturalmente para o topo.
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      );
}

// Campo de texto com borda totalmente arredondada (pill). Ícones de
// suffix reduzidos (19 → 16) para não dominarem visualmente o campo.
class _AuthField extends StatefulWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final String? errorText;
  final Widget? suffix;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const _AuthField({
    required this.s,
    required this.ctrl,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.suffix,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.focusNode,
  });

  @override State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  bool _focused = false;

  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 18, bottom: 6),
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: s.onSurfaceVariant)),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: kCupertinoOut,
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: hasError
                  ? s.error
                  : (_focused ? s.primary : s.outline.withOpacity(0.5)),
              width: hasError || _focused ? 1.5 : 1,
            ),
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: TextField(
              controller: widget.ctrl,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              focusNode: widget.focusNode,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(fontSize: 15, color: s.onSurface),
              cursorColor: s.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                hintText: widget.hint,
                hintStyle: TextStyle(fontSize: 15, color: s.onSurfaceVariant.withOpacity(0.7)),
                suffixIcon: widget.suffix,
                suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 24),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 6),
            child: Text(widget.errorText!,
                style: TextStyle(fontSize: 12, color: s.error)),
          ),
      ],
    );
  }
}

// Botão primário — cor sólida sem boxShadow (item pedido: botões com
// cor não podem ter sombra). Mantém apenas o AnimatedScale de toque.
class _AuthPrimaryButton extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _AuthPrimaryButton({
    required this.s,
    required this.label,
    required this.loading,
    required this.onTap,
  });
  @override State<_AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<_AuthPrimaryButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final disabled = widget.onTap == null || widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) { if (!disabled) setState(() => _p = true); },
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap:       disabled ? null : widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled ? s.primary.withOpacity(0.5) : s.primary,
            borderRadius: BorderRadius.circular(999),
            // boxShadow removido — botões com cor não levam sombra.
          ),
          child: widget.loading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(s.onPrimary),
                  ),
                )
              : Text(widget.label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: s.onPrimary)),
        ),
      ),
    );
  }
}

// Botão de voltar — ícone reduzido (20 → 17), alinhado com a redução
// geral pedida.
class _AuthBackButton extends StatelessWidget {
  final AppColorScheme s;
  const _AuthBackButton({required this.s});

  @override
  Widget build(BuildContext context) => AppTap(
        onTap: () => Navigator.of(context).pop(),
        s: s,
        child: AppIcon('back.svg', color: s.onSurface, size: 17),
      );
}

class _AuthErrorBanner extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  const _AuthErrorBanner({required this.s, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: s.error.withOpacity(s.isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: s.error.withOpacity(0.4)),
        ),
        child: Row(children: [
          AppIcon('error.svg', color: s.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: s.error, fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN — imagem background1.png no topo (ilustração pura,
// sem logo.png), título/tagline logo abaixo dela, formulário desce
// mais para dar respiro (padrão "app premium" pedido).
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _obscure = true;
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _passError = null;
    });
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    var ok = true;
    if (email.isEmpty) {
      setState(() => _emailError = 'Introduz o teu email');
      ok = false;
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Email inválido');
      ok = false;
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
    final ok = await authController.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!ok && mounted) setState(() {});
  }

  // Navegação com transição nativa iOS (slide + parallax + edge swipe
  // to back), via CupertinoPageRoute — substitui o antigo
  // PageRouteBuilder com SlideTransition manual.
  void _goRegister() {
    authController.clearError();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _goForgot() {
    authController.clearError();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    // Altura da ilustração: proporcional ao ecrã (≈34%), mantendo
    // espaço suficiente para o formulário respirar por baixo — mesmo
    // princípio do padrão de referência, sem fixar um valor absoluto
    // que quebraria em ecrãs pequenos.
    final heroHeight = (screenHeight * 0.34).clamp(220.0, 340.0);

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: AnimatedBuilder(
          animation: authController,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthHeroImage(height: heroHeight),
                  Padding(
                    // Formulário desce mais (padding top maior) para
                    // criar respiro visual entre a ilustração e os
                    // campos — o "ajuste premium" pedido.
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Bem-vindo de volta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800, color: s.onSurface)),
                        const SizedBox(height: 6),
                        Text('Inicia sessão para continuar na Nexa',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)),
                        const SizedBox(height: 36),
                        if (authController.lastError != null)
                          _AuthErrorBanner(s: s, message: authController.lastError!),
                        _AuthField(
                          s: s,
                          ctrl: _emailCtrl,
                          label: 'Email',
                          hint: 'nome@exemplo.com',
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        _AuthField(
                          s: s,
                          ctrl: _passCtrl,
                          label: 'Password',
                          hint: '••••••••',
                          obscure: _obscure,
                          errorText: _passError,
                          focusNode: _passFocus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          suffix: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: AppIcon(
                              _obscure ? 'eye.svg' : 'eye_off.svg',
                              size: 16,
                              color: s.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, right: 6),
                            child: GestureDetector(
                              onTap: _goForgot,
                              child: Text('Esqueceste-te da password?',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: s.primary)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _AuthPrimaryButton(
                          s: s,
                          label: 'Iniciar sessão',
                          loading: authController.busy,
                          onTap: _submit,
                        ),
                        const SizedBox(height: 24),
                        Row(children: [
                          Expanded(child: Divider(color: s.outline, height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou',
                                style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
                          ),
                          Expanded(child: Divider(color: s.outline, height: 1)),
                        ]),
                        const SizedBox(height: 24),
                        Center(
                          child: GestureDetector(
                            onTap: _goRegister,
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                                children: [
                                  const TextSpan(text: 'Ainda não tens conta? '),
                                  TextSpan(
                                    text: 'Cria uma',
                                    style: TextStyle(
                                        color: s.primary, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// REGISTER SCREEN — sem PNG (pedido explícito), formulário também
// desce mais para manter a mesma respiração vertical do login.
// ══════════════════════════════════════════════════════════════

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass = true;
  bool _obscureConfirm = true;

  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _confirmError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passError = null;
      _confirmError = null;
    });
    var ok = true;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty) {
      setState(() => _nameError = 'Introduz o teu nome');
      ok = false;
    }
    if (email.isEmpty) {
      setState(() => _emailError = 'Introduz o teu email');
      ok = false;
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Email inválido');
      ok = false;
    }
    if (pass.isEmpty) {
      setState(() => _passError = 'Cria uma password');
      ok = false;
    } else if (pass.length < 6) {
      setState(() => _passError = 'A password deve ter pelo menos 6 caracteres');
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
    final ok = await authController.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(children: [
            AnimatedBuilder(
              animation: authController,
              builder: (context, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 92, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Cria a tua conta',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800, color: s.onSurface)),
                      const SizedBox(height: 6),
                      Text('Junta-te à Nexa e começa a criar',
                          style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)),
                      const SizedBox(height: 32),
                      if (authController.lastError != null)
                        _AuthErrorBanner(s: s, message: authController.lastError!),
                      _AuthField(
                        s: s,
                        ctrl: _nameCtrl,
                        label: 'Nome',
                        hint: 'O teu nome completo',
                        errorText: _nameError,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),
                      _AuthField(
                        s: s,
                        ctrl: _emailCtrl,
                        label: 'Email',
                        hint: 'nome@exemplo.com',
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),
                      _AuthField(
                        s: s,
                        ctrl: _passCtrl,
                        label: 'Password',
                        hint: 'Mínimo 6 caracteres',
                        obscure: _obscurePass,
                        errorText: _passError,
                        focusNode: _passFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _confirmFocus.requestFocus(),
                        suffix: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _obscurePass = !_obscurePass),
                          child: AppIcon(
                            _obscurePass ? 'eye.svg' : 'eye_off.svg',
                            size: 16,
                            color: s.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AuthField(
                        s: s,
                        ctrl: _confirmCtrl,
                        label: 'Confirmar password',
                        hint: 'Repete a password',
                        obscure: _obscureConfirm,
                        errorText: _confirmError,
                        focusNode: _confirmFocus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        suffix: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          child: AppIcon(
                            _obscureConfirm ? 'eye.svg' : 'eye_off.svg',
                            size: 16,
                            color: s.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _AuthPrimaryButton(
                        s: s,
                        label: 'Criar conta',
                        loading: authController.busy,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ao criar conta concordas com os nossos Termos de Serviço e Política de Privacidade.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: s.onSurfaceVariant.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                              children: [
                                const TextSpan(text: 'Já tens conta? '),
                                TextSpan(
                                  text: 'Iniciar sessão',
                                  style: TextStyle(
                                      color: s.primary, fontWeight: FontWeight.w700),
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
              top: 8, left: 4,
              child: _AuthBackButton(s: s),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FORGOT PASSWORD SCREEN
// ══════════════════════════════════════════════════════════════

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
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
    final ok = await authController.forgotPassword(email);
    if (ok && mounted) setState(() => _sent = true);
    if (!ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(children: [
            AnimatedBuilder(
              animation: authController,
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 92, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_sent ? 'Verifica o teu email' : 'Recuperar password',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800, color: s.onSurface)),
                      const SizedBox(height: 6),
                      Text(
                        _sent
                            ? 'Se existir uma conta com esse email, vais receber instruções para repor a password.'
                            : 'Introduz o teu email e enviamos-te instruções para criares uma nova password.',
                        style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      if (!_sent) ...[
                        if (authController.lastError != null)
                          _AuthErrorBanner(s: s, message: authController.lastError!),
                        _AuthField(
                          s: s,
                          ctrl: _emailCtrl,
                          label: 'Email',
                          hint: 'nome@exemplo.com',
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 28),
                        _AuthPrimaryButton(
                          s: s,
                          label: 'Enviar instruções',
                          loading: authController.busy,
                          onTap: _submit,
                        ),
                      ] else ...[
                        Center(
                          child: Container(
                            width: 72, height: 72,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: s.success.withOpacity(s.isDark ? 0.18 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: AppIcon('check.svg', color: s.success, size: 26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AuthPrimaryButton(
                          s: s,
                          label: 'Voltar ao início de sessão',
                          loading: false,
                          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 8, left: 4,
              child: _AuthBackButton(s: s),
            ),
          ]),
        ),
      ),
    );
  }
}