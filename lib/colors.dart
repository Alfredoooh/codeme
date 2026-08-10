// ══════════════════════════════════════════════════════════════
// FILE: lib/colors.dart
//
// AppTheme deixou de ser InheritedNotifier consultado via
// context.dependOnInheritedWidgetOfExactType(). Isso exigia que o
// widget que chama AppTheme.of(context) estivesse sempre ligado à
// árvore no momento exato do build — frágil dentro de Stacks com
// Transform.translate e animações concorrentes.
//
// Agora AppTheme.of(context) lê diretamente o ChangeNotifier global
// (appTheme), sem lookup na árvore. Não há mais "contexto desligado"
// possível, porque não há mais contexto a consultar.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Curve kCupertino    = Cubic(0.25, 0.1,  0.25, 1.0);
const Curve kCupertinoIn  = Cubic(0.42, 0.0,  1.0,  1.0);
const Curve kCupertinoOut = Cubic(0.0,  0.0,  0.58, 1.0);

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  Color get primary            => isDark ? const Color(0xFF479EF5) : const Color(0xFF0F6CBD);
  Color get onPrimary          => isDark ? const Color(0xFF061724) : const Color(0xFFFFFFFF);
  Color get primaryContainer   => isDark ? const Color(0xFF0C3B5E) : const Color(0xFFEBF3FC);
  Color get onPrimaryContainer => isDark ? const Color(0xFFCFE4FA) : const Color(0xFF0C3B5E);

  Color get surface            => isDark ? const Color(0xFF232323) : const Color(0xFFFFFFFF);
  Color get onSurface          => isDark ? const Color(0xFFEDEDED) : const Color(0xFF1B1B1B);
  Color get onSurfaceVariant   => isDark ? const Color(0xFFB8B8B8) : const Color(0xFF616161);
  Color get pageBackground     => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF6F7F9);
  Color get cardBackground     => isDark ? const Color(0xFF303030) : const Color(0xFFFFFFFF);

  Color get floatingSurface    => isDark ? const Color(0xFF323234) : const Color(0xFFFFFFFF);

  Color get outline            => isDark ? const Color(0xFF4E4E4E) : const Color(0xFFD1D1D1);
  Color get outlineVariant     => isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E5E5);

  Color get error              => isDark ? const Color(0xFFDC626D) : const Color(0xFFC50F1F);
  Color get onError            => isDark ? const Color(0xFF3B0509) : const Color(0xFFFFFFFF);
  Color get errorContainer     => isDark ? const Color(0xFF6E0811) : const Color(0xFFEEACB2);
  Color get onErrorContainer   => isDark ? const Color(0xFFF6D1D5) : const Color(0xFF3B0509);

  Color get success            => isDark ? const Color(0xFF9FD89F) : const Color(0xFF107C10);
  Color get warning            => isDark ? const Color(0xFFFFD166) : const Color(0xFFB45309);

  Color get barrier            => const Color(0x80000000);
  Color get hover              => isDark ? const Color(0x16FFFFFF) : const Color(0x08000000);
  Color get pressed            => isDark ? const Color(0x22FFFFFF) : const Color(0x10000000);

  Color get navBarBg           => isDark ? const Color(0xFF303030) : const Color(0xFFFFFFFF);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get navIconActive      => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F6CBD);
  Color get navLabelActive     => isDark ? const Color(0xFFCFE4FA) : const Color(0xFF0C3B5E);
  Color get navIndicatorBg     => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEBF3FC);

  Color get projectsTabBg      => const Color(0xFF0F6CBD);
  Color get projectsTabFg      => const Color(0xFFFFFFFF);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 2))]
      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))]
      : [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 3))];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))]
      : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 3))];

  Color get incognitoBackground => const Color(0xFF0D0D0F);
  Color get incognitoSurface    => const Color(0xFF17171A);
  Color get incognitoOnSurface  => const Color(0xFFEDEDED);
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER — fonte única de verdade, global, sem árvore.
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  static const _kDarkKey = 'app_theme_is_dark';

  bool isDark = false;
  bool isIncognito = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDark = prefs.getBool(_kDarkKey) ?? false;
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

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDarkKey, isDark);
    } catch (_) {}
  }

  void toggleIncognito() { isIncognito = !isIncognito; notifyListeners(); }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

// ══════════════════════════════════════════════════════════════
// AppTheme — já NÃO é InheritedNotifier. É só um wrapper estático
// fino sobre o appTheme global. AppTheme.of(context) devolve sempre
// o estado atual, direto do ChangeNotifier, sem depender em que
// ponto da árvore o context se encontra. O parâmetro context fica
// só por compatibilidade de assinatura com todo o código existente
// que já chama AppTheme.of(context) — não é usado para lookup.
// ══════════════════════════════════════════════════════════════

class AppTheme extends StatelessWidget {
  final Widget child;
  const AppTheme({super.key, required this.child});

  static AppColorScheme of(BuildContext context) => AppColorScheme(appTheme.isDark);
  static bool isIncognito(BuildContext context) => appTheme.isIncognito;

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder escuta o appTheme global e reconstrói este
    // subtree sempre que toggleDark()/setDark() disparam notify —
    // é isto que substitui o antigo InheritedNotifier: continua
    // reativo, mas sem depender de lookup de contexto.
    return AnimatedBuilder(
      animation: appTheme,
      builder: (_, __) => child,
    );
  }
}