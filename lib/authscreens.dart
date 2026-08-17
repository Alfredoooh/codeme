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
// SHARED — logo (fallback), ilustração de topo, back button, error banner
// ══════════════════════════════════════════════════════════════

class _AuthLogo extends StatelessWidget {
  final AppColorScheme s;
  final bool pulsing;
  const _AuthLogo({required this.s, this.pulsing = false});

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusXLarge),
      child: Image.asset(
        'assets/logo.png',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary,
            borderRadius: BorderRadius.circular(kRadiusXLarge),
          ),
          child: Text(
            'N',
            style: TextStyle(
              fontSize: kTypeTitle,
              fontWeight: FontWeight.w800,
              color: s.onPrimary,
            ),
          ),
        ),
      ),
    );
    if (!pulsing) return logo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: kFluentStandard,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: value, child: child),
      ),
      child: logo,
    );
  }
}

class _AuthHeroImage extends StatelessWidget {
  final double height;
  final Color fadeToColor;
  const _AuthHeroImage({required this.height, required this.fadeToColor});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.45, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/background1.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.5,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [fadeToColor.withOpacity(0.0), fadeToColor],
                      stops: const [0.0, 0.92],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _AuthBackButton extends StatelessWidget {
  final AppColorScheme s;
  final Color? iconColor;
  const _AuthBackButton({required this.s, this.iconColor});

  @override
  Widget build(BuildContext context) => AppTap(
        onTap: () => Navigator.of(context).pop(),
        s: s,
        child: AppIcon('back.svg', color: iconColor ?? s.onSurface, size: 18),
      );
}

class _AuthErrorBanner extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  const _AuthErrorBanner({required this.s, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: kSpaceL),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceL,
          vertical: kSpaceM,
        ),
        decoration: BoxDecoration(
          color: s.errorContainer,
          borderRadius: BorderRadius.circular(kRadiusXLarge),
          border: Border.all(color: s.error),
        ),
        child: Row(
          children: [
            AppIcon('error.svg', color: s.error, size: 16),
            SizedBox(width: kSpaceS),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: kTypeBody,
                  color: s.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
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
    final heroHeight = (screenHeight * 0.34).clamp(220.0, 340.0);

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.surface,
        child: AnimatedBuilder(
          animation: authController,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthHeroImage(height: heroHeight, fadeToColor: s.surface),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kSpaceXXL,
                      kSpaceS,
                      kSpaceXXL,
                      kSpaceXXL,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bem-vindo de volta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: kTypeSubtitle,
                            fontWeight: FontWeight.w800,
                            color: s.onSurface,
                          ),
                        ),
                        SizedBox(height: kSpaceXXXL),
                        if (authController.lastError != null)
                          _AuthErrorBanner(
                            s: s,
                            message: authController.lastError!,
                          ),
                        FluentTextField(
                          s: s,
                          controller: _emailCtrl,
                          hint: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passFocus.requestFocus(),
                        ),
                        SizedBox(height: kSpaceM),
                        FluentTextField(
                          s: s,
                          controller: _passCtrl,
                          hint: 'Password',
                          obscureText: _obscure,
                          errorText: _passError,
                          focusNode: _passFocus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          suffixIcon: AppTap(
                            onTap: () => setState(() => _obscure = !_obscure),
                            s: s,
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
                            padding: const EdgeInsets.only(
                              top: kSpaceS,
                              right: kSpaceXS,
                            ),
                            child: AppTap(
                              onTap: _goForgot,
                              s: s,
                              child: Text(
                                'Esqueceste-te da password?',
                                style: TextStyle(
                                  fontSize: kTypeBody,
                                  fontWeight: FontWeight.w600,
                                  color: s.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: kSpaceXXXL),
                        FluentButton(
                          s: s,
                          label: 'Iniciar sessão',
                          loading: authController.busy,
                          onTap: _submit,
                          style: FluentButtonStyle.primary,
                        ),
                        SizedBox(height: kSpaceXXL),
                        Center(
                          child: AppTap(
                            onTap: _goRegister,
                            s: s,
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: kTypeBody,
                                  color: s.onSurfaceVariant,
                                ),
                                children: [
                                  const TextSpan(text: 'Ainda não tens conta? '),
                                  TextSpan(
                                    text: 'Cria uma',
                                    style: TextStyle(
                                      color: s.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
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
// REGISTER SCREEN
// ══════════════════════════════════════════════════════════════

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
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
        color: s.surface,
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: authController,
                builder: (context, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      kSpaceXXL,
                      kSpaceXXXL + kSpaceXL,
                      kSpaceXXL,
                      kSpaceXXL,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Cria a tua conta',
                          style: TextStyle(
                            fontSize: kTypeSubtitle,
                            fontWeight: FontWeight.w800,
                            color: s.onSurface,
                          ),
                        ),
                        SizedBox(height: kSpaceXXXL),
                        if (authController.lastError != null)
                          _AuthErrorBanner(
                            s: s,
                            message: authController.lastError!,
                          ),
                        FluentTextField(
                          s: s,
                          controller: _nameCtrl,
                          hint: 'Nome',
                          errorText: _nameError,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _emailFocus.requestFocus(),
                        ),
                        SizedBox(height: kSpaceM),
                        FluentTextField(
                          s: s,
                          controller: _emailCtrl,
                          hint: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          focusNode: _emailFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passFocus.requestFocus(),
                        ),
                        SizedBox(height: kSpaceM),
                        FluentTextField(
                          s: s,
                          controller: _passCtrl,
                          hint: 'Password',
                          obscureText: _obscurePass,
                          errorText: _passError,
                          focusNode: _passFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _confirmFocus.requestFocus(),
                          suffixIcon: AppTap(
                            onTap: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            s: s,
                            child: AppIcon(
                              _obscurePass ? 'eye.svg' : 'eye_off.svg',
                              size: 16,
                              color: s.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(height: kSpaceM),
                        FluentTextField(
                          s: s,
                          controller: _confirmCtrl,
                          hint: 'Confirmar password',
                          obscureText: _obscureConfirm,
                          errorText: _confirmError,
                          focusNode: _confirmFocus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          suffixIcon: AppTap(
                            onTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            s: s,
                            child: AppIcon(
                              _obscureConfirm ? 'eye.svg' : 'eye_off.svg',
                              size: 16,
                              color: s.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(height: kSpaceXXXL),
                        FluentButton(
                          s: s,
                          label: 'Criar conta',
                          loading: authController.busy,
                          onTap: _submit,
                          style: FluentButtonStyle.primary,
                        ),
                        SizedBox(height: kSpaceXXL),
                        Center(
                          child: AppTap(
                            onTap: () => Navigator.of(context).pop(),
                            s: s,
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: kTypeBody,
                                  color: s.onSurfaceVariant,
                                ),
                                children: [
                                  const TextSpan(text: 'Já tens conta? '),
                                  TextSpan(
                                    text: 'Iniciar sessão',
                                    style: TextStyle(
                                      color: s.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                top: kSpaceS,
                left: kSpaceXS,
                child: _AuthBackButton(s: s),
              ),
            ],
          ),
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
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
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
        color: s.surface,
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: authController,
                builder: (context, _) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kSpaceXXL,
                      kSpaceXXXL + kSpaceXL,
                      kSpaceXXL,
                      kSpaceXXL,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _sent
                              ? 'Verifica o teu email'
                              : 'Recuperar password',
                          style: TextStyle(
                            fontSize: kTypeSubtitle,
                            fontWeight: FontWeight.w800,
                            color: s.onSurface,
                          ),
                        ),
                        SizedBox(height: kSpaceXS),
                        Text(
                          _sent
                              ? 'Se existir uma conta com esse email, vais receber instruções.'
                              : 'Introduz o teu email para receberes instruções.',
                          style: TextStyle(
                            fontSize: kTypeBody,
                            color: s.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: kSpaceXXXL),
                        if (!_sent) ...[
                          if (authController.lastError != null)
                            _AuthErrorBanner(
                              s: s,
                              message: authController.lastError!,
                            ),
                          FluentTextField(
                            s: s,
                            controller: _emailCtrl,
                            hint: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          SizedBox(height: kSpaceXXXL),
                          FluentButton(
                            s: s,
                            label: 'Enviar instruções',
                            loading: authController.busy,
                            onTap: _submit,
                            style: FluentButtonStyle.primary,
                          ),
                        ] else ...[
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              margin: const EdgeInsets.symmetric(
                                vertical: kSpaceM,
                              ),
                              decoration: BoxDecoration(
                                color: s.successContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AppIcon(
                                  'check.svg',
                                  color: s.success,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: kSpaceL),
                          FluentButton(
                            s: s,
                            label: 'Voltar ao início de sessão',
                            onTap: () =>
                                Navigator.of(context).popUntil((r) => r.isFirst),
                            style: FluentButtonStyle.primary,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              Positioned(
                top: kSpaceS,
                left: kSpaceXS,
                child: _AuthBackButton(s: s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}