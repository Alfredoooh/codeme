// ══════════════════════════════════════════════════════════════
// FILE: lib/colors.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Curve kCupertinoIn  = Cubic(0.42, 0.0,  1.0,  1.0);
const Curve kCupertinoOut = Cubic(0.0,  0.0,  0.58, 1.0);

// ══════════════════════════════════════════════════════════════
// COLOR SCHEME
// ══════════════════════════════════════════════════════════════

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

  Color get hover              => isDark ? const Color(0x16FFFFFF) : const Color(0x08000000);
  Color get pressed            => isDark ? const Color(0x22FFFFFF) : const Color(0x10000000);

  Color get navBarBg           => isDark ? const Color(0xFF303030) : const Color(0xFFFFFFFF);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get navIconActive      => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F6CBD);
  Color get navLabelActive     => isDark ? const Color(0xFFCFE4FA) : const Color(0xFF0C3B5E);
  Color get navIndicatorBg     => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEBF3FC);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
      : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 8))]
      : [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]
      : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))];
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER — persistência local de isDark via SharedPreferences.
// load() é chamado em main() antes de runApp(); toggleDark() grava de
// imediato. Enquanto load() não terminar, isDark mantém o default
// (false) para não bloquear o primeiro frame.
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  static const _kDarkKey = 'nexa_dark_mode';

  bool isDark = false;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool(_kDarkKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  void toggleDark() {
    isDark = !isDark;
    _persist();
    notifyListeners();
  }

  void setDark(bool value) {
    if (isDark == value) return;
    isDark = value;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkKey, isDark);
  }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

// ══════════════════════════════════════════════════════════════
// APP THEME — InheritedNotifier que expõe AppColorScheme via
// AppTheme.of(context). CRÍTICO: nunca deve cair silenciosamente
// para um scheme errado quando o lookup falha — isso mascarava
// bugs reais (drawer a reabrir com tema light por cima do dark)
// como "cor errada" em vez de um crash visível e diagnosticável.
// Se o InheritedWidget não for encontrado, isso agora é um erro
// alto e claro em vez de um fallback mudo para isDark: false.
// ══════════════════════════════════════════════════════════════

class AppTheme extends InheritedNotifier<AppThemeNotifier> {
  const AppTheme({super.key, required AppThemeNotifier super.notifier, required super.child});

  static AppColorScheme of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(
      widget != null,
      'AppTheme.of() foi chamado a partir de um context que não está '
      'sob o AppTheme InheritedNotifier. Isto costuma acontecer quando '
      'um widget é inserido no Overlay/Navigator interno do Flutter '
      '(ex.: Drawer nativo, rota, dialog) antes de estar plenamente '
      'montado sob a árvore principal do app. Garante que o widget que '
      'chama AppTheme.of() está sempre dentro da árvore de RootShell, '
      'e evita construir a UI a partir de um context isolado nesse frame.',
    );
    final n = widget?.notifier;
    if (n == null) {
      // Em release (sem asserts), preferimos um scheme visualmente
      // ÓBVIO e errado (dark forçado) a um fallback para light que
      // se disfarça de "cor errada mas plausível" dentro de um app
      // que é maioritariamente dark. Isto torna qualquer recorrência
      // deste bug imediatamente visível outra vez, em vez de voltar
      // a ser confundido com um problema de asset ou de dados.
      return const AppColorScheme(true);
    }
    return AppColorScheme(n.isDark);
  }

  @override
  bool updateShouldNotify(AppTheme oldWidget) => true;
}