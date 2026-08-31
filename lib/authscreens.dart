// ══════════════════════════════════════════════════════════════
// FILE: lib/authscreens.dart
// ══════════════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'main.dart';

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
          child: Center(child: _AuthLogoFallback(s: s, pulsing: true)),
        );
      case AuthStatus.authenticated:
        return const RootShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// LOGO FALLBACK (AuthGate estado unknown)
// ══════════════════════════════════════════════════════════════

class _AuthLogoFallback extends StatelessWidget {
  final AppColorScheme s;
  final bool pulsing;
  const _AuthLogoFallback({required this.s, this.pulsing = false});

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/images/logo.png',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('N',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: s.onPrimary)),
        ),
      ),
    );
    if (!pulsing) return logo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.ease,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: value, child: child),
      ),
      child: logo,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LOGO ANIMADO — adapta ao tema do sistema.
// Tema escuro: gradiente prata/branco com shimmer brilhante.
// Tema claro:  gradiente cor primária do app.
// ══════════════════════════════════════════════════════════════

class _AnimatedLogo extends StatefulWidget {
  final double size;
  const _AnimatedLogo({required this.size});

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with TickerProviderStateMixin {
  late final AnimationController _gradientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _shimmerCtrl.repeat();
    });
  }

  @override
  void dispose() {
    _gradientCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final isDark = s.isDark;

    // Tema escuro: prata → branco → prata (metálico)
    // Tema claro:  cor primária do app em gradiente suave
    final List<Color> gradientColors = isDark
        ? const [
            Color(0xFFB8BEC7),
            Color(0xFFE8ECF0),
            Color(0xFFFFFFFF),
            Color(0xFFCDD2D8),
            Color(0xFFB8BEC7),
          ]
        : [
            s.primary.withOpacity(0.7),
            s.primary,
            s.primary.withOpacity(0.85),
            s.primary,
          ];

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camada 1 — gradiente animado
          AnimatedBuilder(
            animation: _gradientCtrl,
            builder: (context, _) {
              final t = _gradientCtrl.value;
              final pingPong = t < 0.5 ? t * 2 : (1 - t) * 2;
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(-1 + pingPong * 0.4, -1),
                  end: Alignment(1 - pingPong * 0.4, 1),
                  colors: gradientColors,
                ).createShader(rect),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),

          // Camada 2 — shimmer diagonal (mais intenso no escuro)
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, _) {
              final raw = _shimmerCtrl.value;
              final progress = raw < 0.55 ? (raw / 0.55) : 1.0;
              final pos = -1.2 + progress * 2.4;
              return Opacity(
                opacity: isDark ? 0.95 : 0.55,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment(pos - 0.35, pos - 0.35),
                    end: Alignment(pos + 0.35, pos + 0.35),
                    colors: const [
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: const [0.35, 0.50, 0.65],
                  ).createShader(rect),
                  child: SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FRASES EM STREAMING
// ══════════════════════════════════════════════════════════════

class _StreamingPhrases extends StatefulWidget {
  const _StreamingPhrases();

  @override
  State<_StreamingPhrases> createState() => _StreamingPhrasesState();
}

class _StreamingPhrasesState extends State<_StreamingPhrases>
    with TickerProviderStateMixin {
  static const _phrases = [
    'Descubra mais sobre o universo com a nexa ai',
    'Explore ideias sem limites, uma pergunta de cada vez',
    'Inteligência que aprende com você, todos os dias',
    'Bem-vindo ao nexa ai',
  ];

  static const _holdTime = Duration(milliseconds: 2200);
  static const _fadeTime = Duration(milliseconds: 700);
  static const _gapTime = Duration(milliseconds: 300);

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: _fadeTime,
  );
  late final AnimationController _cursorCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _runCycle();
  }

  Future<void> _runCycle() async {
    while (mounted) {
      await _fadeCtrl.forward();
      final isLast = _index == _phrases.length - 1;
      if (isLast) return;
      await Future.delayed(_holdTime);
      if (!mounted) return;
      await _fadeCtrl.reverse();
      if (!mounted) return;
      await Future.delayed(_gapTime);
      if (!mounted) return;
      setState(() => _index++);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final textStyle = GoogleFonts.spaceGrotesk(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: s.onSurface,
      shadows: [
        Shadow(
            color: s.isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 1)),
      ],
    );

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: _phrases[_index]),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: AnimatedBuilder(
              animation: _cursorCtrl,
              builder: (context, _) => Opacity(
                opacity: 0.15 + (_cursorCtrl.value * 0.85),
                child: Text('_', style: textStyle),
              ),
            ),
          ),
        ]),
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CAMPO DE TEXTO — estilo settings.dart (sem curva excessiva)
// ══════════════════════════════════════════════════════════════

class _AuthField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final String? errorText;
  final Widget? suffix;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const _AuthField({
    required this.ctrl,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.suffix,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? s.error
                  : _focused
                      ? s.primary.withOpacity(0.6)
                      : s.outline.withOpacity(0.45),
              width: _focused || hasError ? 1.5 : 1.0,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: s.primary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                hintText: widget.hint,
                hintStyle: TextStyle(
                    fontSize: 15,
                    color: s.onSurfaceVariant.withOpacity(0.6)),
                suffixIcon: widget.suffix,
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 24),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(widget.errorText!,
                style: TextStyle(fontSize: 12, color: s.error)),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO PRIMÁRIO — igual ao do settings (pill sólida)
// ══════════════════════════════════════════════════════════════

class _AuthPrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _AuthPrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<_AuthPrimaryButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final disabled = widget.onTap == null || widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!disabled) setState(() => _p = true);
      },
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: disabled ? null : widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled ? s.primary.withOpacity(0.5) : s.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: s.primary.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: widget.loading
              ? SizedBox(
                  width: 20,
                  height: 20,
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

// ══════════════════════════════════════════════════════════════
// BOTÃO SECUNDÁRIO — contorno suave, mesmo estilo das rows do settings
// ══════════════════════════════════════════════════════════════

class _AuthSecondaryButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _AuthSecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  State<_AuthSecondaryButton> createState() => _AuthSecondaryButtonState();
}

class _AuthSecondaryButtonState extends State<_AuthSecondaryButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 54,
          decoration: BoxDecoration(
            color: _p ? s.hover : s.cardBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: s.outline.withOpacity(0.45)),
            boxShadow: s.cardShadowSoft,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(s.onSurface),
                  ),
                )
              else ...[
                widget.icon,
                const SizedBox(width: 10),
                Text(widget.label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: s.onSurface)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO VOLTAR CIRCULAR — idêntico ao do settings.dart
// ══════════════════════════════════════════════════════════════

class _AuthBackButton extends StatefulWidget {
  final AppColorScheme s;
  const _AuthBackButton({required this.s});

  @override
  State<_AuthBackButton> createState() => _AuthBackButtonState();
}

class _AuthBackButtonState extends State<_AuthBackButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: AppIcon('back', color: s.onSurface, size: 18),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BANNER DE ERRO
// ══════════════════════════════════════════════════════════════

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
          color: s.error.withOpacity(s.isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s.error.withOpacity(0.35)),
        ),
        child: Row(children: [
          AppIcon('error.svg', color: s.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: s.error,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN — fundo s.pageBackground (igual ao settings),
// logo adaptado ao tema, botões no estilo settings, teclado
// sobe a tela suavemente.
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _googleLoading = false;

  void _goEmailLogin() {
    authController.clearError();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const EmailLoginScreen()),
    );
  }

  void _goRegister() {
    authController.clearError();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> _continueWithGoogle() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _googleLoading = false);
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
        // Sobe TUDO quando o teclado aparece
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: authController,
            builder: (context, _) {
              return SingleChildScrollView(
                // Padding bottom reativo ao teclado para subida suave
                padding: EdgeInsets.only(
                  left: 28,
                  right: 28,
                  top: 52,
                  bottom: 32 + MediaQuery.of(context).viewInsets.bottom,
                ),
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        52 -
                        32,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ── Logo ──────────────────────────────────
                        const SizedBox(height: 16),
                        const _AnimatedLogo(size: 88),
                        const SizedBox(height: 28),

                        // ── Saudação ──────────────────────────────
                        Text(
                          'Bem-vindo',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: s.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── Frases streaming ──────────────────────
                        const SizedBox(
                          height: 52,
                          child: Center(child: _StreamingPhrases()),
                        ),

                        const Spacer(),

                        // ── Erro global ───────────────────────────
                        if (authController.lastError != null) ...[
                          _AuthErrorBanner(
                              s: s, message: authController.lastError!),
                          const SizedBox(height: 4),
                        ],

                        // ── Subtítulo ─────────────────────────────
                        Text(
                          'Entre na sua conta para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: s.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Botão Google ──────────────────────────
                        _AuthSecondaryButton(
                          icon: const _GoogleIcon(size: 20),
                          label: 'Continuar com Google',
                          loading: _googleLoading,
                          onTap: _continueWithGoogle,
                        ),
                        const SizedBox(height: 12),

                        // ── Botão Email ───────────────────────────
                        _AuthSecondaryButton(
                          icon: AppIcon('mail',
                              size: 20, color: s.onSurface),
                          label: 'Continuar com email',
                          onTap: _goEmailLogin,
                        ),
                        const SizedBox(height: 28),

                        // ── Criar conta ───────────────────────────
                        GestureDetector(
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
                      ],
                    ),
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
// ══════════════════════════════════════════════════════════════

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
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
    final ok =
        await authController.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!ok && mounted) setState(() {});
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
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 28,
                          right: 28,
                          top: 92,
                          bottom:
                              24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 92 - 24,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Título centrado bold
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
                                  'Bem-vindo de volta.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant),
                                ),
                                const SizedBox(height: 36),

                                if (authController.lastError != null)
                                  _AuthErrorBanner(
                                      s: s,
                                      message: authController.lastError!),

                                _AuthField(
                                  ctrl: _emailCtrl,
                                  hint: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  errorText: _emailError,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) =>
                                      _passFocus.requestFocus(),
                                ),
                                const SizedBox(height: 12),
                                _AuthField(
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
                                const SizedBox(height: 28),
                                _AuthPrimaryButton(
                                  label: 'Iniciar sessão',
                                  loading: authController.busy,
                                  onTap: _submit,
                                ),

                                const Spacer(),

                                // Esqueceste a password — sempre visível na base
                                Center(
                                  child: GestureDetector(
                                    onTap: _goForgot,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        'Esqueceste-te da password?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: s.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Botão voltar circular
              Positioned(
                top: 8,
                left: 12,
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
                  return LayoutBuilder(
                    builder: (context, constraints) {
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
                                  fontSize: 14,
                                  color: s.onSurfaceVariant),
                            ),
                            const SizedBox(height: 36),

                            if (authController.lastError != null)
                              _AuthErrorBanner(
                                  s: s,
                                  message: authController.lastError!),

                            _AuthField(
                              ctrl: _nameCtrl,
                              hint: 'Nome',
                              errorText: _nameError,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  _emailFocus.requestFocus(),
                            ),
                            const SizedBox(height: 12),
                            _AuthField(
                              ctrl: _emailCtrl,
                              hint: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              errorText: _emailError,
                              focusNode: _emailFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  _passFocus.requestFocus(),
                            ),
                            const SizedBox(height: 12),
                            _AuthField(
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
                                  _obscurePass
                                      ? 'eye.svg'
                                      : 'eye_off.svg',
                                  size: 16,
                                  color: s.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AuthField(
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
                                    () =>
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
                            const SizedBox(height: 28),
                            _AuthPrimaryButton(
                              label: 'Criar conta',
                              loading: authController.busy,
                              onTap: _submit,
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: s.onSurfaceVariant),
                                    children: [
                                      const TextSpan(
                                          text: 'Já tens conta? '),
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
                  );
                },
              ),
              Positioned(
                top: 8,
                left: 12,
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
    final ok = await authController.forgotPassword(email);
    if (ok && mounted) setState(() => _sent = true);
    if (!ok && mounted) setState(() {});
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
                              ? 'Se existir uma conta com esse email, vais receber instruções.'
                              : 'Introduz o teu email para receberes instruções.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              color: s.onSurfaceVariant),
                        ),
                        const SizedBox(height: 36),

                        if (!_sent) ...[
                          if (authController.lastError != null)
                            _AuthErrorBanner(
                                s: s,
                                message: authController.lastError!),
                          _AuthField(
                            ctrl: _emailCtrl,
                            hint: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 28),
                          _AuthPrimaryButton(
                            label: 'Enviar instruções',
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
                                color: s.success.withOpacity(
                                    s.isDark ? 0.18 : 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AppIcon('check.svg',
                                    color: s.success, size: 26),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AuthPrimaryButton(
                            label: 'Voltar ao início de sessão',
                            loading: false,
                            onTap: () => Navigator.of(context)
                                .popUntil((r) => r.isFirst),
                          ),
                        ],

                        // Esqueceste a password — sempre fixo na base
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
                                      const TextSpan(
                                          text: 'Lembraste? '),
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
// ÍCONE GOOGLE
// ══════════════════════════════════════════════════════════════

class _GoogleIcon extends StatelessWidget {
  final double size;
  const _GoogleIcon({required this.size});

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>
<path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/>
<path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>
<path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 0 1-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: size, height: size);
}