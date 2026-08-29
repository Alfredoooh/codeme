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
// PALETA FIXA DA TELA DE LOGIN — não reage a tema claro/escuro,
// espelha 1:1 as variáveis CSS do HTML de referência (:root).
// ══════════════════════════════════════════════════════════════

class _LoginPalette {
  static const Color bg = Color(0xFFD8C9A8);
  static const Color btnBg = Color(0x24FFFFFF); // rgba(255,255,255,0.14)
  static const Color btnBorder = Color(0x59FFFFFF); // rgba(255,255,255,0.35)
  static const Color btnHover = Color(0x38FFFFFF); // rgba(255,255,255,0.22)
  static const Color text = Color(0xFFFDFAF3);
  static const Color textMuted = Color(0xADFDFAF3); // rgba(...,0.68)
  static const Color accent = Color(0xFFC1502E);

  // Cores do gradiente animado do logo (mesmas 4 do CSS)
  static const List<Color> logoGradient = [
    Color(0xFFF4C98B),
    Color(0xFFC1502E),
    Color(0xFF7A8FC9),
    Color(0xFFF4C98B),
  ];
}

// ══════════════════════════════════════════════════════════════
// SHARED — logo (fallback), campo de texto, botão principal
// ══════════════════════════════════════════════════════════════

// Mantido apenas como fallback do AuthGate (estado "unknown") — a
// tela de LOGIN em si não usa isto, usa o logo animado com gradiente.
class _AuthLogo extends StatelessWidget {
  final AppColorScheme s;
  final bool pulsing;
  const _AuthLogo({required this.s, this.pulsing = false});

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

// ══════════════════════════════════════════════════════════════
// LOGO ANIMADO — gradiente de cor a rodar + shimmer diagonal por
// cima, ambos recortados na forma exata de assets/images/logo.svg,
// via ShaderMask (equivalente Flutter ao mask-image do CSS).
// Roda em loop infinito, independente do tema claro/escuro.
// ══════════════════════════════════════════════════════════════

class _AnimatedGradientLogo extends StatefulWidget {
  final double size;
  const _AnimatedGradientLogo({required this.size});

  @override
  State<_AnimatedGradientLogo> createState() => _AnimatedGradientLogoState();
}

class _AnimatedGradientLogoState extends State<_AnimatedGradientLogo>
    with TickerProviderStateMixin {
  // Espelha "animation: logoGradient 6s ease-in-out infinite;"
  late final AnimationController _gradientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Espelha "animation: shimmerSweep 3.2s ease-in-out infinite;
  // animation-delay: 1s;"
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camada 1 — gradiente de cor animado (drop-shadow incluída)
          DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _gradientCtrl,
              builder: (context, _) {
                // Reproduz o keyframe 0% -> 50% -> 100% (vai e volta)
                final t = _gradientCtrl.value;
                final pingPong = t < 0.5 ? t * 2 : (1 - t) * 2;
                return ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment(-1 + pingPong * 0.4, -1),
                    end: Alignment(1 - pingPong * 0.4, 1),
                    colors: _LoginPalette.logoGradient,
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
          ),
          // Camada 2 — shimmer diagonal (mix-blend-mode: overlay)
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, _) {
              // 0% -> -120%,-120% | 55% -> 120%,120% | 100% -> mantém
              final raw = _shimmerCtrl.value;
              final progress = raw < 0.55 ? (raw / 0.55) : 1.0;
              final pos = -1.2 + progress * 2.4;
              return Opacity(
                opacity: 0.85,
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
                    stops: const [0.40, 0.50, 0.60],
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
// FRASES EM STREAMING — 4 frases com fade suave, fonte Space
// Grotesk, cursor "_" a piscar sempre. Última frase fica fixa.
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
  static const _fadeTime = Duration(milliseconds: 600);
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
    final textStyle = GoogleFonts.spaceGrotesk(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: _LoginPalette.text,
      shadows: const [
        Shadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 1)),
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

// ── Ilustração de topo (background1.png) — só a tela de LOGIN usa,
// com fade real na base fundindo para a paleta fixa do login.
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
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
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

// Campo de texto "pill" translúcido — estilo do HTML (fundo branco
// a baixa opacidade + blur), usado nas telas SEM imagem (email,
// password, registo, esqueci-me).
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
  final bool glass; // true = estilo translúcido do HTML sobre fundo colorido

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
    this.glass = false,
  });

  @override State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  bool _focused = false;

  static const double _radius = 999;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    final Color bg = widget.glass ? _LoginPalette.btnBg : s.cardBackground;
    final Color borderColor = hasError
        ? s.error
        : (widget.glass
            ? (_focused ? _LoginPalette.text : _LoginPalette.btnBorder)
            : (_focused ? s.primary : s.outline.withOpacity(0.5)));
    final Color textColor = widget.glass ? _LoginPalette.text : s.onSurface;
    final Color hintColor = widget.glass
        ? _LoginPalette.textMuted
        : s.onSurfaceVariant.withOpacity(0.7);
    final Color cursorColor = widget.glass ? _LoginPalette.text : s.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: kCupertinoOut,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: borderColor,
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
              style: TextStyle(fontSize: 15, color: textColor),
              cursorColor: cursorColor,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                hintText: widget.hint,
                hintStyle: TextStyle(fontSize: 15, color: hintColor),
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

// Botão primário — cor sólida, usado nas telas de app (Registo,
// Esqueci-me, tela de password). A tela de login em si usa os
// botões glass próprios (_GlassAuthButton).
class _AuthPrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _AuthPrimaryButton({
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
    final s = AppTheme.of(context);
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

// ── Botão "glass" da tela de login — pill translúcida com blur,
// espelha exatamente .btn do HTML (background rgba + backdrop-filter).
class _GlassAuthButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _GlassAuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_GlassAuthButton> createState() => _GlassAuthButtonState();
}

class _GlassAuthButtonState extends State<_GlassAuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 54,
            decoration: BoxDecoration(
              color: _pressed ? _LoginPalette.btnHover : _LoginPalette.btnBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _LoginPalette.btnBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.icon,
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _LoginPalette.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  final AppColorScheme s;
  final Color? iconColor;
  const _AuthBackButton({required this.s, this.iconColor});

  @override
  Widget build(BuildContext context) => AppTap(
        onTap: () => Navigator.of(context).pop(),
        s: s,
        child: AppIcon('back.svg', color: iconColor ?? s.onSurface, size: 17),
      );
}

// Botão de voltar circular — mesmo estilo do settings.dart
// (_CircularBackButton), reutilizado nas telas glass do login.
class _CircularGlassBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CircularGlassBackButton({required this.onTap});
  @override
  State<_CircularGlassBackButton> createState() => _CircularGlassBackButtonState();
}

class _CircularGlassBackButtonState extends State<_CircularGlassBackButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _p ? _LoginPalette.btnHover : _LoginPalette.btnBg,
              shape: BoxShape.circle,
              border: Border.all(color: _LoginPalette.btnBorder),
            ),
            child: const AppIcon('back', color: _LoginPalette.text, size: 18),
          ),
        ),
      ),
    );
  }
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
// LOGIN SCREEN — réplica 1:1 do HTML: fundo background1.png fixo
// (sem depender de tema), logo animado no topo, frases streaming
// no centro, subtítulo colado ao primeiro botão, botões glass
// (Google + Continuar com email) ancorados na base.
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  // MOCK — Google Sign-In real fica para uma próxima iteração.
  // Por agora só dá feedback visual (loading fake) e não faz nada.
  bool _googleLoading = false;

  Future<void> _continueWithGoogle() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _googleLoading = false);
    // TODO: ligar Google Sign-In real aqui quando estiver pronto.
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: _LoginPalette.bg,
            image: DecorationImage(
              image: AssetImage('assets/images/background1.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: AnimatedBuilder(
            animation: authController,
            builder: (context, _) {
              return SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
                  child: Column(
                    children: [
                      // ── hero: logo animado ──────────────────
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const _AnimatedGradientLogo(size: 120),
                          ],
                        ),
                      ),

                      // ── centro: frases em streaming ─────────
                      const Expanded(
                        flex: 3,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: _StreamingPhrases(),
                          ),
                        ),
                      ),

                      // ── base: subtítulo + botões + criar conta
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (authController.lastError != null) ...[
                              _AuthErrorBanner(
                                s: AppTheme.of(context),
                                message: authController.lastError!,
                              ),
                              const SizedBox(height: 4),
                            ],
                            const Text(
                              'Entre na sua conta para continuar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: _LoginPalette.textMuted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _GlassAuthButton(
                              icon: _googleLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation(
                                            _LoginPalette.text),
                                      ),
                                    )
                                  : const _GoogleIcon(size: 20),
                              label: _googleLoading
                                  ? 'A continuar...'
                                  : 'Continuar com Google',
                              onTap: _continueWithGoogle,
                            ),
                            const SizedBox(height: 14),
                            _GlassAuthButton(
                              icon: const AppIcon('mail',
                                  size: 20, color: _LoginPalette.text),
                              label: 'Continuar com email',
                              onTap: _goEmailLogin,
                            ),
                            const SizedBox(height: 28),
                            Center(
                              child: GestureDetector(
                                onTap: _goRegister,
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                        fontSize: 14, color: _LoginPalette.textMuted),
                                    children: [
                                      TextSpan(text: 'Ainda não tens conta? '),
                                      TextSpan(
                                        text: 'Cria uma',
                                        style: TextStyle(
                                            color: _LoginPalette.text,
                                            fontWeight: FontWeight.w700),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Ícone oficial do Google (4 cores, flat) — SVG inline, sem depender
// de asset externo.
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
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: size, height: size);
  }
}

// ══════════════════════════════════════════════════════════════
// EMAIL LOGIN SCREEN — dois inputs (email + password), sem imagem
// de fundo, corrige o problema de teclado a tapar os campos com
// scroll reativo a MediaQuery.viewInsets.bottom.
// ══════════════════════════════════════════════════════════════

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});
  @override State<EmailLoginScreen> createState() => _EmailLoginScreenState();
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
    final ok = await authController.login(_emailCtrl.text.trim(), _passCtrl.text);
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
    // resizeToAvoidBottomInset garante que o Scaffold encolhe quando
    // o teclado abre; o SingleChildScrollView por baixo garante que
    // o campo focado consegue subir até ficar visível.
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: s.surface,
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
                        left: 24,
                        right: 24,
                        top: 92,
                        // Empurra o conteúdo para cima do teclado —
                        // é este padding reativo que faltava nas
                        // outras telas.
                        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 92 - 24,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Iniciar sessão',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: s.onSurface)),
                              const SizedBox(height: 32),
                              if (authController.lastError != null)
                                _AuthErrorBanner(
                                    s: s, message: authController.lastError!),
                              _AuthField(
                                ctrl: _emailCtrl,
                                hint: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                errorText: _emailError,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _passFocus.requestFocus(),
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
                                label: 'Iniciar sessão',
                                loading: authController.busy,
                                onTap: _submit,
                              ),
                              const Spacer(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              top: 8, left: 4,
              child: _AuthBackButton(s: s),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// REGISTER SCREEN — sem imagem, fundo s.surface, corrigido para
// reagir ao teclado (o problema estava no padding fixo antigo).
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: s.surface,
      body: SafeArea(
        child: Stack(children: [
          AnimatedBuilder(
            animation: authController,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 92,
                      bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Cria a tua conta',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800, color: s.onSurface)),
                        const SizedBox(height: 32),
                        if (authController.lastError != null)
                          _AuthErrorBanner(s: s, message: authController.lastError!),
                        _AuthField(
                          ctrl: _nameCtrl,
                          hint: 'Nome',
                          errorText: _nameError,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _emailFocus.requestFocus(),
                        ),
                        const SizedBox(height: 12),
                        _AuthField(
                          ctrl: _emailCtrl,
                          hint: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          focusNode: _emailFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passFocus.requestFocus(),
                        ),
                        const SizedBox(height: 12),
                        _AuthField(
                          ctrl: _passCtrl,
                          hint: 'Password',
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
              );
            },
          ),
          Positioned(
            top: 8, left: 4,
            child: _AuthBackButton(s: s),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FORGOT PASSWORD SCREEN — sem imagem, corrigido para reagir ao
// teclado.
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: s.surface,
      body: SafeArea(
        child: Stack(children: [
          AnimatedBuilder(
            animation: authController,
            builder: (context, _) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 92,
                  bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_sent ? 'Verifica o teu email' : 'Recuperar password',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800, color: s.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                      _sent
                          ? 'Se existir uma conta com esse email, vais receber instruções.'
                          : 'Introduz o teu email para receberes instruções.',
                      style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    if (!_sent) ...[
                      if (authController.lastError != null)
                        _AuthErrorBanner(s: s, message: authController.lastError!),
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
    );
  }
}