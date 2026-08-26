import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Curve kCupertino    = Cubic(0.25, 0.1,  0.25, 1.0);
const Curve kCupertinoIn  = Cubic(0.42, 0.0,  1.0,  1.0);
const Curve kCupertinoOut = Cubic(0.0,  0.0,  0.58, 1.0);

// ══════════════════════════════════════════════════════════════
// PALETA DE CORES PRIMÁRIAS SELECIONÁVEIS
// ══════════════════════════════════════════════════════════════

const List<Color> kPrimaryColorOptions = [
  Color(0xFFFF6044), // Coral (padrão)
  Color(0xFF007AFF), // Azul
  Color(0xFF34C759), // Verde
  Color(0xFFFF9500), // Laranja
  Color(0xFFAF52DE), // Roxo
  Color(0xFFFF375F), // Rosa
  Color(0xFF30D158), // Verde-limão
  Color(0xFF64D2FF), // Ciano
];

const Color kDefaultPrimaryColor = Color(0xFFFF6044);

// ══════════════════════════════════════════════════════════════
// MODO DE TEMA
// ══════════════════════════════════════════════════════════════

enum AppThemeMode { light, dark, system }

extension AppThemeModeX on AppThemeMode {
  String get storageValue => const {
        AppThemeMode.light:  'light',
        AppThemeMode.dark:   'dark',
        AppThemeMode.system: 'system',
      }[this]!;

  static AppThemeMode fromStorage(String? raw) {
    switch (raw) {
      case 'light':  return AppThemeMode.light;
      case 'dark':   return AppThemeMode.dark;
      case 'system':
      default:       return AppThemeMode.system;
    }
  }
}

class AppColorScheme {
  final bool isDark;
  final Color primaryColor;
  
  const AppColorScheme(this.isDark, [this.primaryColor = kDefaultPrimaryColor]);

  // Cor primária dinâmica — calcula cores derivadas via HSL
  Color get primary            => primaryColor;
  Color get onPrimary          => isDark ? _darken(primaryColor, 0.75) : Colors.white;
  Color get primaryContainer   => isDark ? _darken(primaryColor, 0.55) : _lighten(primaryColor, 0.85);
  Color get onPrimaryContainer => isDark ? _lighten(primaryColor, 0.55) : _darken(primaryColor, 0.60);

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  // Superfícies neutras
  Color get surface            => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get onSurface          => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1C1C1E);
  Color get onSurfaceVariant   => isDark ? const Color(0xFF9B9B9F) : const Color(0xFF6E6E73);
  Color get pageBackground     => isDark ? const Color(0xFF121313) : const Color(0xFFF9F7F4);

  Color get cardBackground     => isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);
  Color get floatingSurface    => isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);

  Color get outline            => isDark ? const Color(0xFF48484A) : const Color(0xFFDCDCE0);
  Color get outlineVariant     => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFECECEE);

  // Cores de estado
  Color get error              => isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
  Color get onError            => isDark ? const Color(0xFF330705) : const Color(0xFFFFFFFF);
  Color get errorContainer     => isDark ? const Color(0xFF5C1A16) : const Color(0xFFFFD8D5);
  Color get onErrorContainer   => isDark ? const Color(0xFFFFD8D5) : const Color(0xFF5C1A16);

  Color get success            => isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
  Color get warning            => isDark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);

  Color get barrier            => const Color(0x80000000);
  Color get hover              => isDark ? const Color(0x16FFFFFF) : const Color(0x08000000);
  Color get pressed            => isDark ? const Color(0x22FFFFFF) : const Color(0x10000000);

  // Navegação e tabs
  Color get navBarBg           => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFBFBFC);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get navIconActive      => isDark ? Colors.white : primary;
  Color get navLabelActive     => onPrimaryContainer;
  Color get navIndicatorBg     => primaryContainer;

  Color get projectsTabBg      => primary;
  Color get projectsTabFg      => onPrimary;

  Color get previewBackdrop    => isDark ? const Color(0xFF242426) : const Color(0xFFEFEFF1);
  Color get downloadButtonBg   => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEFEFF1);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 7, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.38), blurRadius: 14, offset: const Offset(0, 5))]
      : [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 5))];

  List<BoxShadow> get cardShadowSoft => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 4, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 1))];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 3))]
      : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))];

  Color get incognitoBackground => const Color(0xFF121212);
  Color get incognitoSurface    => const Color(0xFF1C1C1E);
  Color get incognitoOnSurface  => const Color(0xFFFFFFFF);
  Color get sheetBackdrop => const Color(0xFF0B0B0D);

  // NOVO: estilo da barra de status
  SystemUiOverlayStyle get statusBarStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      );
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  static const _kModeKey = 'app_theme_mode';
  static const _kPrimaryColorKey = 'app_primary_color';

  AppThemeMode mode = AppThemeMode.system;
  bool isIncognito = false;
  Color primaryColor = kDefaultPrimaryColor;

  bool get _systemIsDark =>
      SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

  bool get isDark {
    switch (mode) {
      case AppThemeMode.light:  return false;
      case AppThemeMode.dark:   return true;
      case AppThemeMode.system: return _systemIsDark;
    }
  }

  AppThemeNotifier() {
    SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (mode == AppThemeMode.system) notifyListeners();
    };
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kModeKey);
      if (raw != null) {
        mode = AppThemeModeX.fromStorage(raw);
      } else {
        final legacyDark = prefs.getBool('app_theme_is_dark');
        if (legacyDark != null) {
          mode = legacyDark ? AppThemeMode.dark : AppThemeMode.light;
        }
      }
      final colorValue = prefs.getInt(_kPrimaryColorKey);
      if (colorValue != null) {
        primaryColor = Color(colorValue);
      }
      notifyListeners();
    } catch (_) {}
  }

  void setMode(AppThemeMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
    _persistMode();
  }

  void toggleDark() {
    setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }

  void setDark(bool value) {
    setMode(value ? AppThemeMode.dark : AppThemeMode.light);
  }

  void setPrimaryColor(Color color) {
    if (primaryColor.value == color.value) return;
    primaryColor = color;
    notifyListeners();
    _persistPrimaryColor();
  }

  Future<void> _persistMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModeKey, mode.storageValue);
    } catch (_) {}
  }

  Future<void> _persistPrimaryColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrimaryColorKey, primaryColor.value);
    } catch (_) {}
  }

  void toggleIncognito() { isIncognito = !isIncognito; notifyListeners(); }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

// ══════════════════════════════════════════════════════════════
// PREFERÊNCIAS GLOBAIS
// ══════════════════════════════════════════════════════════════

enum EmojiFrequency { never, rare, medium, often }

extension EmojiFrequencyX on EmojiFrequency {
  String get storageValue => const {
        EmojiFrequency.never:  'never',
        EmojiFrequency.rare:   'rare',
        EmojiFrequency.medium: 'medium',
        EmojiFrequency.often:  'often',
      }[this]!;

  String get displayName => const {
        EmojiFrequency.never:  'Nunca',
        EmojiFrequency.rare:   'Raramente',
        EmojiFrequency.medium: 'Médio',
        EmojiFrequency.often:  'Muito',
      }[this]!;

  static EmojiFrequency fromStorage(String? raw) {
    switch (raw) {
      case 'rare':   return EmojiFrequency.rare;
      case 'medium': return EmojiFrequency.medium;
      case 'often':  return EmojiFrequency.often;
      case 'never':
      default:       return EmojiFrequency.never;
    }
  }
}

class AppPreferencesNotifier extends ChangeNotifier {
  static const _kPromptKey = 'app_preferences_prompt';
  static const _kEmojiKey = 'app_preferences_emoji';
  static const _kFontScaleKey = 'app_preferences_font_scale';

  String prompt = '';
  EmojiFrequency emojiFrequency = EmojiFrequency.never;
  double fontScale = 0.35;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prompt = prefs.getString(_kPromptKey) ?? '';
      final emojiRaw = prefs.getString(_kEmojiKey);
      if (emojiRaw != null) {
        emojiFrequency = EmojiFrequencyX.fromStorage(emojiRaw);
      }
      fontScale = prefs.getDouble(_kFontScaleKey) ?? 0.35;
      notifyListeners();
    } catch (_) {}
  }

  void setPrompt(String value) {
    if (prompt == value) return;
    prompt = value;
    notifyListeners();
    _persistPrompt();
  }

  void setEmojiFrequency(EmojiFrequency freq) {
    if (emojiFrequency == freq) return;
    emojiFrequency = freq;
    notifyListeners();
    _persistEmoji();
  }

  void setFontScale(double value) {
    if ((fontScale - value).abs() < 0.001) return;
    fontScale = value;
    notifyListeners();
    _persistFontScale();
  }

  /// Multiplicador real aplicado ao tamanho de fonte base — mapeia o
  /// slider (0.0–1.0) para um intervalo de escala visualmente útil
  /// (85% a 135% do tamanho base), espelhando o cálculo que já
  /// existia isolado dentro de _FontSizeCard.
  double get textScaleFactor => 0.85 + (fontScale * 0.5);

  Future<void> _persistPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPromptKey, prompt);
    } catch (_) {}
  }

  Future<void> _persistEmoji() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kEmojiKey, emojiFrequency.storageValue);
    } catch (_) {}
  }

  Future<void> _persistFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kFontScaleKey, fontScale);
    } catch (_) {}
  }
}

final AppPreferencesNotifier appPreferences = AppPreferencesNotifier();

// ══════════════════════════════════════════════════════════════
// AppTheme — wrapper estático
// ══════════════════════════════════════════════════════════════

class AppTheme extends StatelessWidget {
  final Widget child;
  const AppTheme({super.key, required this.child});

  static AppColorScheme of(BuildContext context) =>
      AppColorScheme(appTheme.isDark, appTheme.primaryColor);

  static bool isIncognito(BuildContext context) => appTheme.isIncognito;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appTheme, appPreferences]),
      builder: (_, __) => child,
    );
  }
}

mixin ThemeReactive<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(_onThemeChanged);
    appPreferences.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appTheme.removeListener(_onThemeChanged);
    appPreferences.removeListener(_onThemeChanged);
    super.dispose();
  }
}