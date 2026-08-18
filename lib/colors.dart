// ══════════════════════════════════════════════════════════════
// FILE: lib/colors.dart
//
// Sistema de cores completo baseado em Fluent Design System
// (Windows 11 / Microsoft Apps). Cobre:
//   • Neutral tokens (fundo de página, layers, cards, strokes)
//   • Fill colors (control, subtle, transparent, accent)
//   • Stroke/outline (surface, card, focus, divider)
//   • Elevation / shadow tokens (inkl. Acrylic backdrop)
//   • Semantic colors (error, warning, success, info, caution)
//   • Nav / shell tokens
//   • App-specific tokens (previewBackdrop, downloadButtonBg, etc.)
//   • Tema reativo via ChangeNotifier singleton (appTheme)
//   • Mixin ThemeReactive<T> para reconstrução automática
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// CURVAS DE ANIMAÇÃO (estilo Fluent / Cupertino)
// ─────────────────────────────────────────────────────────────

const Curve kCupertino     = Cubic(0.25, 0.1,  0.25, 1.0);
const Curve kCupertinoIn   = Cubic(0.42, 0.0,  1.0,  1.0);
const Curve kCupertinoOut  = Cubic(0.0,  0.0,  0.58, 1.0);

/// Fluent: Fast Out, Slow In (standard deceleration)
const Curve kFluentStandard   = Cubic(0.33, 0.0,  0.0,  1.0);
/// Fluent: Fast Out, Slow In (entrada de elementos)
const Curve kFluentDecelerate = Cubic(0.0,  0.0,  0.0,  1.0);
/// Fluent: Fast Out (saída de elementos)
const Curve kFluentAccelerate = Cubic(0.9,  0.0,  1.0,  1.0);

// ─────────────────────────────────────────────────────────────
// DURAÇÕES DE ANIMAÇÃO (Fluent Motion)
// ─────────────────────────────────────────────────────────────

const Duration kDurationFast     = Duration(milliseconds: 83);
const Duration kDurationNormal   = Duration(milliseconds: 167);
const Duration kDurationSlow     = Duration(milliseconds: 250);
const Duration kDurationSlower   = Duration(milliseconds: 333);
const Duration kDurationPage     = Duration(milliseconds: 400);

// ─────────────────────────────────────────────────────────────
// BORDER RADIUS TOKENS (Fluent)
// ─────────────────────────────────────────────────────────────

const double kRadiusNone     = 0.0;
const double kRadiusSmall    = 2.0;
const double kRadiusMedium   = 4.0;
const double kRadiusLarge    = 8.0;
const double kRadiusXLarge   = 12.0;
const double kRadiusCircle   = 9999.0;

// ─────────────────────────────────────────────────────────────
// SPACING / LAYOUT TOKENS
// ─────────────────────────────────────────────────────────────

const double kSpaceXXS  = 2.0;
const double kSpaceXS   = 4.0;
const double kSpaceS    = 8.0;
const double kSpaceM    = 12.0;
const double kSpaceL    = 16.0;
const double kSpaceXL   = 20.0;
const double kSpaceXXL  = 24.0;
const double kSpaceXXXL = 32.0;

// ─────────────────────────────────────────────────────────────
// TIPOGRAFIA — TYPE RAMP TOKENS (Fluent)
// ─────────────────────────────────────────────────────────────

const double kTypeCaption     = 12.0;
const double kTypeBody        = 14.0;
const double kTypeBodyStrong  = 14.0;
const double kTypeBodyLarge   = 16.0;
const double kTypeSubtitle    = 20.0;
const double kTypeTitle       = 28.0;
const double kTypeTitleLarge  = 40.0;
const double kTypeDisplay     = 68.0;

// ══════════════════════════════════════════════════════════════
// AppColorScheme — todos os tokens num único objeto imutável
// ══════════════════════════════════════════════════════════════

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  // ─── ACCENT / PRIMARY ────────────────────────────────────

  /// Accent Default — cor de destaque principal (azul Fluent)
  Color get primary              => isDark ? const Color(0xFF479EF5) : const Color(0xFF0F6CBD);

  /// Texto/ícone sobre superfície accent
  Color get onPrimary            => isDark ? const Color(0xFF061724) : const Color(0xFFFFFFFF);

  /// Accent Light 3 / Dark 3 — fundo de containers de destaque (chips, badges)
  Color get primaryContainer     => isDark ? const Color(0xFF0C3B5E) : const Color(0xFFEBF3FC);

  /// Texto sobre primaryContainer
  Color get onPrimaryContainer   => isDark ? const Color(0xFFCFE4FA) : const Color(0xFF0C3B5E);

  /// Accent Light 2 — hover sobre accent (botão primário hovered)
  Color get primaryHover         => isDark ? const Color(0xFF62ABFF) : const Color(0xFF0E5BA8);

  /// Accent Light 1 — pressed sobre accent
  Color get primaryPressed       => isDark ? const Color(0xFF3B90E8) : const Color(0xFF0E5BA8);

  /// Accent Dark 1 — estado desativado / subtle accent
  Color get primarySubtle        => isDark ? const Color(0xFF1E4C7A) : const Color(0xFFBDD7EF);

  /// Accent secundário (usado em gráficos, highlights adicionais)
  Color get secondary            => isDark ? const Color(0xFF9CDCFE) : const Color(0xFF005FB7);
  Color get onSecondary          => isDark ? const Color(0xFF012B4A) : const Color(0xFFFFFFFF);
  Color get secondaryContainer   => isDark ? const Color(0xFF003A5C) : const Color(0xFFDCEEFC);
  Color get onSecondaryContainer => isDark ? const Color(0xFFB8D9F5) : const Color(0xFF003A5C);

  // ─── NEUTRAL BACKGROUNDS (Fluent Layers) ─────────────────

  /// Solid Background — fundo de toda a app (Layer 0)
  Color get solidBackground      => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFEEEEEE);

  /// Page Background — fundo de conteúdo principal (Layer 1)
  Color get pageBackground       => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F3F3);

  /// Card Background — fundo de cards, painéis, superfícies elevadas (Layer 2)
  Color get cardBackground       => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);

  /// Surface — superfície de diálogos, menus, flyouts (Layer 3)
  Color get surface              => isDark ? const Color(0xFF3C3C3C) : const Color(0xFFFFFFFF);

  /// Floating Surface — tooltips, menus suspensos (Layer 4)
  Color get floatingSurface      => isDark ? const Color(0xFF454545) : const Color(0xFFFFFFFF);

  /// Layer Subtle — fundo alternado em listas, tabelas (faixa zebra)
  Color get layerSubtle          => isDark ? const Color(0xFF26262A) : const Color(0xFFF0F0F0);

  /// Layer Default — camada de item selecionado em listas
  Color get layerDefault         => isDark ? const Color(0xFF323232) : const Color(0xFFFFFFFF);

  /// Acrylic Background (blur host fallback, sem suporte nativo Flutter)
  Color get acrylicBackground    => isDark
      ? const Color(0xCC232323)
      : const Color(0xCCF3F3F3);

  // ─── FILL COLORS ─────────────────────────────────────────

  /// Control Default — fundo de inputs, botões secundários
  Color get controlDefault       => isDark ? const Color(0x1AFFFFFF) : const Color(0xFFFFFFFF);

  /// Control Secondary — fundo de checkboxes, radios (estado off)
  Color get controlSecondary     => isDark ? const Color(0x0FFFFFFF) : const Color(0xFFF6F6F6);

  /// Control Tertiary — fundo de toggle/slider track (inativo)
  Color get controlTertiary      => isDark ? const Color(0x09FFFFFF) : const Color(0xFFF0F0F0);

  /// Control Quaternary — fundo desativado de controles
  Color get controlQuaternary    => isDark ? const Color(0x06FFFFFF) : const Color(0xFFE6E6E6);

  /// Control Disabled — fill de controle explicitamente desativado
  Color get controlDisabled      => isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF6F6F6);

  /// Control Input Active — fundo de input com foco / text field ativo
  Color get controlInputActive   => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);

  /// Subtle Fill Default — fundo de hover sobre item de lista
  Color get subtleFillDefault    => const Color(0x00000000); // transparente
  Color get subtleFillHover      => isDark ? const Color(0x16FFFFFF) : const Color(0x09000000);
  Color get subtleFillPressed    => isDark ? const Color(0x0DFFFFFF) : const Color(0x06000000);
  Color get subtleFillDisabled   => const Color(0x00000000);

  /// Accent Fill — variantes de fill colorido para botões accent
  Color get accentFillDefault    => isDark ? const Color(0xFF479EF5) : const Color(0xFF0F6CBD);
  Color get accentFillHover      => isDark ? const Color(0xFF62ABFF) : const Color(0xFF1176C1);
  Color get accentFillPressed    => isDark ? const Color(0xFF3789DE) : const Color(0xFF1579C5);
  Color get accentFillDisabled   => isDark ? const Color(0x29FFFFFF) : const Color(0x29000000);

  // ─── TEXT / ON-SURFACE COLORS ────────────────────────────

  /// Texto primário sobre superfície
  Color get onSurface            => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);

  /// Texto secundário (metadados, labels de apoio)
  Color get onSurfaceVariant     => isDark ? const Color(0xFFC8C8C8) : const Color(0xFF4A4A4A);

  /// Texto terciário (placeholders, hints)
  Color get onSurfaceTertiary    => isDark ? const Color(0xFF898989) : const Color(0xFF767676);

  /// Texto desativado
  Color get onSurfaceDisabled    => isDark ? const Color(0x5DFFFFFF) : const Color(0x5D000000);

  /// Texto sobre accent / sobre cor primária
  Color get textOnAccent         => isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  // ─── STROKE / OUTLINE ────────────────────────────────────

  /// Surface Stroke — borda exterior de janelas, cards elevados
  Color get strokeSurface        => isDark ? const Color(0xFF6C6C6C) : const Color(0xFFE5E5E5);

  /// Card Stroke — borda de cards não elevados
  Color get strokeCard           => isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000);

  /// Divider — linha de separação entre seções
  Color get strokeDivider        => isDark ? const Color(0x15FFFFFF) : const Color(0x13000000);

  /// Focus Ring — anel de foco acessível
  Color get strokeFocus          => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get strokeFocusInner     => isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  /// Outline padrão (campos, borders gerais)
  Color get outline              => isDark ? const Color(0xFF4E4E4E) : const Color(0xFFD1D1D1);
  Color get outlineVariant       => isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E5E5);

  /// Control Stroke — borda de controles interativos (input, button)
  Color get controlStroke        => isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000);
  Color get controlStrokeSecondary => isDark ? const Color(0x14FFFFFF) : const Color(0x29000000);

  // ─── ELEVATION / SHADOW ──────────────────────────────────

  List<BoxShadow> get elevation0 => const [];

  List<BoxShadow> get elevation1 => isDark
      ? [BoxShadow(color: const Color(0x33000000), blurRadius: 4,  offset: const Offset(0, 2))]
      : [BoxShadow(color: const Color(0x12000000), blurRadius: 4,  offset: const Offset(0, 2))];

  List<BoxShadow> get elevation2 => isDark
      ? [BoxShadow(color: const Color(0x45000000), blurRadius: 8,  offset: const Offset(0, 4))]
      : [
          BoxShadow(color: const Color(0x12000000), blurRadius: 8,  offset: const Offset(0, 4)),
          BoxShadow(color: const Color(0x08000000), blurRadius: 2,  offset: const Offset(0, 0)),
        ];

  List<BoxShadow> get elevation4 => isDark
      ? [BoxShadow(color: const Color(0x55000000), blurRadius: 16, offset: const Offset(0, 8))]
      : [
          BoxShadow(color: const Color(0x14000000), blurRadius: 16, offset: const Offset(0, 8)),
          BoxShadow(color: const Color(0x0A000000), blurRadius: 4,  offset: const Offset(0, 2)),
        ];

  List<BoxShadow> get elevation8 => isDark
      ? [BoxShadow(color: const Color(0x66000000), blurRadius: 32, offset: const Offset(0, 16))]
      : [
          BoxShadow(color: const Color(0x18000000), blurRadius: 32, offset: const Offset(0, 16)),
          BoxShadow(color: const Color(0x0C000000), blurRadius: 8,  offset: const Offset(0, 4)),
        ];

  List<BoxShadow> get elevation16 => isDark
      ? [BoxShadow(color: const Color(0x77000000), blurRadius: 54, offset: const Offset(0, 27))]
      : [
          BoxShadow(color: const Color(0x1E000000), blurRadius: 54, offset: const Offset(0, 27)),
          BoxShadow(color: const Color(0x0E000000), blurRadius: 12, offset: const Offset(0, 6)),
        ];

  /// Atalhos semânticos para compatibilidade com código anterior
  List<BoxShadow> get cardShadow      => elevation2;
  List<BoxShadow> get floatingShadow  => elevation8;
  List<BoxShadow> get navBarShadow    => elevation4;

  // ─── SEMANTIC: ERROR ─────────────────────────────────────

  Color get error              => isDark ? const Color(0xFFDC626D) : const Color(0xFFC50F1F);
  Color get onError            => isDark ? const Color(0xFF3B0509) : const Color(0xFFFFFFFF);
  Color get errorContainer     => isDark ? const Color(0xFF6E0811) : const Color(0xFFEEACB2);
  Color get onErrorContainer   => isDark ? const Color(0xFFF6D1D5) : const Color(0xFF3B0509);
  Color get errorHover         => isDark ? const Color(0xFFE37B83) : const Color(0xFFB00E1A);
  Color get errorSubtle        => isDark ? const Color(0xFF4A1417) : const Color(0xFFFDE7E9);

  // ─── SEMANTIC: WARNING ───────────────────────────────────

  Color get warning            => isDark ? const Color(0xFFFFD166) : const Color(0xFF9D5D00);
  Color get onWarning          => isDark ? const Color(0xFF3D2900) : const Color(0xFFFFFFFF);
  Color get warningContainer   => isDark ? const Color(0xFF4A3400) : const Color(0xFFFFF4CE);
  Color get onWarningContainer => isDark ? const Color(0xFFFFE792) : const Color(0xFF4A3400);
  Color get warningSubtle      => isDark ? const Color(0xFF3A2800) : const Color(0xFFFFF8DC);

  // ─── SEMANTIC: SUCCESS ───────────────────────────────────

  Color get success            => isDark ? const Color(0xFF9FD89F) : const Color(0xFF107C10);
  Color get onSuccess          => isDark ? const Color(0xFF063006) : const Color(0xFFFFFFFF);
  Color get successContainer   => isDark ? const Color(0xFF0A3E0A) : const Color(0xFFDFF6DD);
  Color get onSuccessContainer => isDark ? const Color(0xFFC8F0C8) : const Color(0xFF0A3E0A);
  Color get successSubtle      => isDark ? const Color(0xFF092909) : const Color(0xFFEEFBEE);

  // ─── SEMANTIC: INFO ──────────────────────────────────────

  Color get info               => isDark ? const Color(0xFF68C6FF) : const Color(0xFF0072C6);
  Color get onInfo             => isDark ? const Color(0xFF002B50) : const Color(0xFFFFFFFF);
  Color get infoContainer      => isDark ? const Color(0xFF003665) : const Color(0xFFCCEAFF);
  Color get onInfoContainer    => isDark ? const Color(0xFF99D5FF) : const Color(0xFF003665);
  Color get infoSubtle         => isDark ? const Color(0xFF002244) : const Color(0xFFE5F3FF);

  // ─── SEMANTIC: CAUTION (Fluent-only, entre warning e error) ─

  Color get caution            => isDark ? const Color(0xFFFFBA44) : const Color(0xFF835B00);
  Color get cautionContainer   => isDark ? const Color(0xFF3D2C00) : const Color(0xFFFFF3D0);
  Color get cautionSubtle      => isDark ? const Color(0xFF2A1E00) : const Color(0xFFFFF8E8);

  // ─── INTERAÇÃO GENÉRICA ──────────────────────────────────

  Color get barrier            => const Color(0x80000000);
  Color get barrierLight       => const Color(0x40000000);

  /// Overlay de hover sobre qualquer superfície neutra
  Color get hover              => isDark ? const Color(0x16FFFFFF) : const Color(0x08000000);

  /// Overlay de pressed sobre qualquer superfície neutra
  Color get pressed            => isDark ? const Color(0x22FFFFFF) : const Color(0x10000000);

  /// Overlay de selecionado (ex: item selecionado em lista)
  Color get selected           => isDark ? const Color(0x1FFFFFFF) : const Color(0x0D000000);

  // ─── NAVIGATION BAR / SHELL ──────────────────────────────

  Color get navBarBg           => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF616161);
  Color get navIconActive      => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F6CBD);
  Color get navLabelActive     => isDark ? const Color(0xFFCFE4FA) : const Color(0xFF0C3B5E);
  Color get navIndicatorBg     => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEBF3FC);

  /// Shell nav rail (lateral, estilo Windows)
  Color get navRailBg          => isDark ? const Color(0xFF282828) : const Color(0xFFF3F3F3);
  Color get navRailItemHover   => isDark ? const Color(0x14FFFFFF) : const Color(0x08000000);
  Color get navRailItemActive  => isDark ? const Color(0x1FFFFFFF) : const Color(0xFFEBF3FC);

  // ─── TAB BAR ─────────────────────────────────────────────

  Color get tabBarBg           => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
  Color get tabDefault         => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F3F3);
  Color get tabActive          => isDark ? const Color(0xFF3C3C3C) : const Color(0xFFFFFFFF);
  Color get tabHover           => isDark ? const Color(0xFF343434) : const Color(0xFFF8F8F8);
  Color get tabStrokeActive    => isDark ? const Color(0xFF6C6C6C) : const Color(0xFFE5E5E5);

  // ─── APP-SPECIFIC TOKENS (Nexa / CraftLab) ───────────────

  /// Tab "Projetos" / CraftLab brand — pill fixo azul
  Color get projectsTabBg      => const Color(0xFF0F6CBD);
  Color get projectsTabFg      => const Color(0xFFFFFFFF);

  /// Área de preview A4 no DocumentWidgetCard
  Color get previewBackdrop    => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFDEDEDE);

  /// Container da barra de ações do DocumentWidgetCard
  Color get downloadButtonBg   => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);

  /// Canvas / whiteboard background
  Color get canvasBackground   => isDark ? const Color(0xFF161616) : const Color(0xFFF8F9FA);
  Color get canvasGrid         => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);

  /// Shimmer (skeleton loading)
  Color get shimmerBase        => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  Color get shimmerHighlight   => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

  /// AI process pill
  Color get processPillBg      => isDark ? const Color(0xFF1E2A3A) : const Color(0xFFE8F2FF);
  Color get processPillFg      => isDark ? const Color(0xFF479EF5) : const Color(0xFF0F6CBD);
  Color get processPillBorder  => isDark ? const Color(0xFF2A3F5A) : const Color(0xFFBDD7EF);

  /// Chat message bubbles
  Color get bubbleUser         => isDark ? const Color(0xFF0C3B5E) : const Color(0xFF0F6CBD);
  Color get bubbleUserFg       => const Color(0xFFFFFFFF);
  Color get bubbleAssistant    => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
  Color get bubbleAssistantFg  => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);

  // ─── INCOGNITO ───────────────────────────────────────────

  Color get incognitoBackground => const Color(0xFF0D0D0F);
  Color get incognitoSurface    => const Color(0xFF17171A);
  Color get incognitoCardBg     => const Color(0xFF1E1E22);
  Color get incognitoOnSurface  => const Color(0xFFEDEDED);
  Color get incognitoAccent     => const Color(0xFF8F72D4);
  Color get incognitoStroke     => const Color(0xFF2E2E35);

  // ─── UTILITÁRIOS ─────────────────────────────────────────

  /// Produz MaterialColor de um único Color (útil para ThemeData)
  static MaterialColor buildMaterial(Color color) {
    final swatch = <int, Color>{};
    for (final factor in [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]) {
      final t = 1.0 - (factor / 1000.0);
      swatch[factor] = Color.lerp(Colors.white, color, 1.0 - t)!;
    }
    return MaterialColor(color.value, swatch);
  }

  /// Aplica alpha sobre uma cor base (equivalente ao withOpacity
  /// mas semântico e type-safe)
  static Color alpha(Color base, double opacity) =>
      base.withOpacity(opacity.clamp(0.0, 1.0));
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER — fonte única de verdade, global, sem árvore.
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  static const _kDarkKey       = 'app_theme_is_dark';
  static const _kContrastKey   = 'app_theme_high_contrast';

  bool isDark        = false;
  bool isIncognito   = false;
  bool isHighContrast = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDark         = prefs.getBool(_kDarkKey)       ?? false;
      isHighContrast = prefs.getBool(_kContrastKey)   ?? false;
      notifyListeners();
    } catch (_) {}
  }

  void toggleDark() {
    isDark = !isDark;
    notifyListeners();
    _persist();
  }

  void setDark(bool value) {
    if (isDark == value) return;
    isDark = value;
    notifyListeners();
    _persist();
  }

  void setHighContrast(bool value) {
    if (isHighContrast == value) return;
    isHighContrast = value;
    notifyListeners();
    _persistContrast();
  }

  void toggleIncognito() {
    isIncognito = !isIncognito;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDarkKey, isDark);
    } catch (_) {}
  }

  Future<void> _persistContrast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kContrastKey, isHighContrast);
    } catch (_) {}
  }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

// ══════════════════════════════════════════════════════════════
// AppTheme — wrapper estático fino sobre o appTheme global.
// ══════════════════════════════════════════════════════════════

class AppTheme extends StatelessWidget {
  final Widget child;
  const AppTheme({super.key, required this.child});

  /// Devolve o AppColorScheme atual. Não depende da posição na árvore.
  static AppColorScheme of(BuildContext context) =>
      AppColorScheme(appTheme.isDark);

  static bool isIncognito(BuildContext context) => appTheme.isIncognito;
  static bool isHighContrast(BuildContext context) => appTheme.isHighContrast;

  /// Constrói ThemeData compatível com Material 3 a partir dos tokens
  static ThemeData buildTheme({required bool isDark}) {
    final c = AppColorScheme(isDark);
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness:       isDark ? Brightness.dark : Brightness.light,
        primary:          c.primary,
        onPrimary:        c.onPrimary,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.onPrimaryContainer,
        secondary:        c.secondary,
        onSecondary:      c.onSecondary,
        secondaryContainer: c.secondaryContainer,
        onSecondaryContainer: c.onSecondaryContainer,
        tertiary:         c.info,
        onTertiary:       c.onInfo,
        tertiaryContainer: c.infoContainer,
        onTertiaryContainer: c.onInfoContainer,
        error:            c.error,
        onError:          c.onError,
        errorContainer:   c.errorContainer,
        onErrorContainer: c.onErrorContainer,
        surface:          c.surface,
        onSurface:        c.onSurface,
        surfaceContainerHighest: c.layerSubtle,
        outline:          c.outline,
        outlineVariant:   c.outlineVariant,
        shadow:           Colors.black,
        scrim:            c.barrier,
        inverseSurface:   isDark ? const Color(0xFFF3F3F3) : const Color(0xFF2C2C2C),
        onInverseSurface: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
        inversePrimary:   isDark ? const Color(0xFF0F6CBD) : const Color(0xFF479EF5),
      ),
      scaffoldBackgroundColor: c.pageBackground,
      cardColor: c.cardBackground,
      dividerColor: c.strokeDivider,
      fontFamily: 'Segoe UI',
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTheme,
      builder: (_, __) => child,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MIXIN ThemeReactive<T> — reconstrução automática em qualquer
// State que precise de reagir a mudanças de tema sem depender
// de setState acidentais (navegação, envio de mensagem, etc.)
//
// Uso:
//   class _MyScreenState extends State<MyScreen>
//       with ThemeReactive<MyScreen> {
//     // sem initState/dispose extras para o tema — o mixin trata
//   }
// ══════════════════════════════════════════════════════════════

mixin ThemeReactive<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appTheme.removeListener(_onThemeChanged);
    super.dispose();
  }
}