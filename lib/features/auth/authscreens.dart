// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/authscreens.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/local_accounts_service.dart';
import '../../main.dart';
import 'widgets/auth_widgets.dart';
import 'widgets/account_picker_sheet.dart';

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
// LOGIN SCREEN (tela inicial)
// 3 botões: Google, Entrar, Criar conta. Sem tabs, sem "iniciar
// sessão com email" — é a raiz do fluxo. Saudação/streaming fica
// ACIMA dos botões, logo por baixo do logo. Botões descem um
// pouco mais (não colados ao texto).
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
    // Integração Google temporariamente indisponível.
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.of(context).cardBackground,
        content: Row(
          children: [
            AppIcon('error.svg', size: 16, color: AppTheme.of(context).error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Login com Google indisponível de momento. Usa o email para continuar.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.of(context).onSurface,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
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
                      const Spacer(flex: 3),

                      const Center(child: AnimatedAuthLogo(size: 76)),
                      const SizedBox(height: 20),

                      // Saudação/frases SEMPRE acima dos botões.
                      const SizedBox(
                        height: 52,
                        child: Center(child: StreamingPhrases()),
                      ),

                      const SizedBox(height: 40),

                      if (authController.lastError != null) ...[
                        AuthErrorBanner(
                            s: s, message: authController.lastError!),
                        const SizedBox(height: 4),
                      ],

                      AuthSecondaryButton(
                        icon: const GoogleIcon(size: 20),
                        label: 'Continuar com Google',
                        disabledLook: true,
                        onTap: _onGoogleTap,
                      ),
                      const SizedBox(height: 12),

                      AuthSecondaryButton(
                        icon: AppIcon('mail', size: 20, color: s.onSurface),
                        label: 'Entrar',
                        onTap: _goLogin,
                      ),
                      const SizedBox(height: 12),

                      AuthPrimaryButton(
                        label: 'Criar conta',
                        loading: false,
                        onTap: _goRegister,
                      ),

                      const Spacer(flex: 2),
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

// ══════════════════════════════════════════════════════════════
// EMAIL LOGIN SCREEN
// Acedida só a partir do botão "Entrar" da tela principal.
// Sem tabs Entrar/Registar aqui — link simples para registo.
// ══════════════════════════════════════════════════════════════

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
    }
    if (!ok && mounted) setState(() {});
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                          24 + MediaQuery.of(context).viewInsets.bottom,
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
                        const SizedBox(height: 32),

                        if (authController.lastError != null)
                          AuthErrorBanner(
                              s: s, message: authController.lastError!),

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
                        const SizedBox(height: 16),
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
    );
  }
}

// ══════════════════════════════════════════════════════════════
// REGISTER SCREEN
// Acedida só a partir do botão "Criar conta" da tela principal.
// Sem tabs — link simples para login.
// ══════════════════════════════════════════════════════════════

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
    }
    if (!ok && mounted) setState(() {});
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                          24 + MediaQuery.of(context).viewInsets.bottom,
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
                        const SizedBox(height: 32),

                        if (authController.lastError != null)
                          AuthErrorBanner(
                              s: s, message: authController.lastError!),

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
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FORGOT PASSWORD SCREEN
// ══════════════════════════════════════════════════════════════

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
    if (!ok && mounted) setState(() {});
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                          24 + MediaQuery.of(context).viewInsets.bottom,
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
                        const SizedBox(height: 36),

                        if (!_sent) ...[
                          if (authController.lastError != null)
                            AuthErrorBanner(
                                s: s,
                                message: authController.lastError!),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
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
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RESET PASSWORD CODE SCREEN
// ══════════════════════════════════════════════════════════════

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                          24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _done ? 'Password atualizada' : 'Introduz o código',
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
                        const SizedBox(height: 32),

                        if (!_done) ...[
                          if (authController.lastError != null)
                            AuthErrorBanner(
                                s: s,
                                message: authController.lastError!),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          const SizedBox(height: 24),
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
                                _obscureConfirm ? 'eye.svg' : 'eye_off.svg',
                                size: 16,
                                color: s.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
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
    );
  }
}