// ══════════════════════════════════════════════════════════════
// FILE: lib/colors.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// ══════════════════════════════════════════════════════════════
// PALETA DE CORES PRIMÁRIAS (Pares Claro/Escuro)
// ══════════════════════════════════════════════════════════════

const Color kMicrosoftBlueLight = Color(0xFF0F6CBD);
const Color kMicrosoftBlueDark  = Color(0xFF479EF5);
const Color kDefaultPrimaryColor = kMicrosoftBlueLight;

class FluentColorPair {
  final Color light;
  final Color dark;
  const FluentColorPair(this.light, this.dark);
}

const List<FluentColorPair> kPrimaryColorPairs = [
  FluentColorPair(Color(0xFF0F6CBD), Color(0xFF479EF5)),
  FluentColorPair(Color(0xFF8764B8), Color(0xFFB4A0FF)),
  FluentColorPair(Color(0xFFC239B3), Color(0xFFE68AD8)),
  FluentColorPair(Color(0xFFD13438), Color(0xFFF1707B)),
  FluentColorPair(Color(0xFFCA5010), Color(0xFFFF8C5A)),
  FluentColorPair(Color(0xFF986F0B), Color(0xFFFFCC66)),
  FluentColorPair(Color(0xFF0B6A0B), Color(0xFF6BCB6B)),
  FluentColorPair(Color(0xFF00767A), Color(0xFF4DD0D6)),
  FluentColorPair(Color(0xFF038387), Color(0xFF3FD9DE)),
  FluentColorPair(Color(0xFF515C6B), Color(0xFF9BA7B4)),
];

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
  final int primaryPairIndex;
  const AppColorScheme(this.isDark, [this.primaryPairIndex = 0]);

  FluentColorPair get _pair =>
      kPrimaryColorPairs[primaryPairIndex.clamp(0, kPrimaryColorPairs.length - 1)];

  Color get primary => isDark ? _pair.dark : _pair.light;

  /// Cor primária atual em formato "#RRGGBB", pronta para injetar
  /// no HTML do editor via editorApi.setPrimaryColor(hex). Usa
  /// sempre a variante correta (light/dark) porque lê de `primary`.
  String get primaryColorHex =>
      '#${primary.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Color get onPrimary          => isDark ? _darken(primary, 0.75) : Colors.white;
  Color get primaryContainer   => isDark ? _darken(primary, 0.55) : _lighten(primary, 0.85);
  Color get onPrimaryContainer => isDark ? _lighten(primary, 0.55) : _darken(primary, 0.60);

  // Cores da bolha do usuário
  Color get userBubbleBg   => isDark ? cardBackground : primary;
  Color get userBubbleText => isDark ? onSurface : onPrimary;

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  // Superfícies neutras
  // NOTA: fundo e cards escuros atualizados para tons mais escuros
  // (#0D0D0D / #141414), conforme pedido. As cores claras mantêm-se.
  Color get surface            => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  Color get onSurface          => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1C1C1E);
  Color get onSurfaceVariant   => isDark ? const Color(0xFF9B9B9F) : const Color(0xFF6E6E73);
  Color get pageBackground     => isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F7F4);

  Color get cardBackground     => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  Color get floatingSurface    => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);

  Color get outline            => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFDCDCE0);
  Color get outlineVariant     => isDark ? const Color(0xFF2A2A2C) : const Color(0xFFECECEE);

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
  Color get navBarBg           => isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFBFBFC);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get navIconActive      => isDark ? Colors.white : primary;
  Color get navLabelActive     => onPrimaryContainer;
  Color get navIndicatorBg     => primaryContainer;

  Color get projectsTabBg      => primary;
  Color get projectsTabFg      => onPrimary;

  Color get previewBackdrop    => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEFEFF1);
  Color get downloadButtonBg   => isDark ? const Color(0xFF262626) : const Color(0xFFEFEFF1);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 7, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 14, offset: const Offset(0, 5))]
      : [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 5))];

  List<BoxShadow> get cardShadowSoft => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 4, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 1))];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 3))]
      : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))];

  Color get incognitoBackground => const Color(0xFF0D0D0D);
  Color get incognitoSurface    => const Color(0xFF141414);
  Color get incognitoOnSurface  => const Color(0xFFFFFFFF);
  Color get sheetBackdrop => const Color(0xFF000000);

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
  static const _kPrimaryPairKey = 'app_primary_pair_index';

  AppThemeMode mode = AppThemeMode.system;
  bool isIncognito = false;
  int primaryPairIndex = 0;

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
      final pairIdx = prefs.getInt(_kPrimaryPairKey);
      if (pairIdx != null && pairIdx >= 0 && pairIdx < kPrimaryColorPairs.length) {
        primaryPairIndex = pairIdx;
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

  void setPrimaryPairIndex(int index) {
    if (primaryPairIndex == index) return;
    primaryPairIndex = index;
    notifyListeners();
    _persistPrimaryPair();
  }

  Future<void> _persistMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModeKey, mode.storageValue);
    } catch (_) {}
  }

  Future<void> _persistPrimaryPair() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrimaryPairKey, primaryPairIndex);
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

  Future<void> setEmojiFrequencyRemote(EmojiFrequency freq, String? token) async {
    setEmojiFrequency(freq);
    if (token == null) return;
    try {
      await ProfileApiService.updateAccount(token, preferences: {
        'emojiFrequency': freq.storageValue,
      });
    } catch (_) {}
  }

  Future<void> setPromptRemote(String value, String? token) async {
    setPrompt(value);
    if (token == null) return;
    try {
      await ProfileApiService.updateAccount(token, preferences: {
        'customPrompt': value,
      });
    } catch (_) {}
  }

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
      AppColorScheme(appTheme.isDark, appTheme.primaryPairIndex);

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