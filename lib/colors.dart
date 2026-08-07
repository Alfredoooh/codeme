import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// CURVAS GLOBAIS
// ══════════════════════════════════════════════════════════════

const Curve kCupertino    = Cubic(0.25, 0.1,  0.25, 1.0);
const Curve kCupertinoIn  = Cubic(0.42, 0.0,  1.0,  1.0);
const Curve kCupertinoOut = Cubic(0.0,  0.0,  0.58, 1.0);

// ══════════════════════════════════════════════════════════════
// APP COLOR SCHEME — fonte única de verdade para todas as cores
// ══════════════════════════════════════════════════════════════

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  // ── Primária ────────────────────────────────────────────────
  // Cores oficiais do Microsoft Fluent 2 Design System.
  // Light: Brand-80 (#0f6cbd) — mesmo tom usado como
  //   BrandBackgroundStatic / BrandForegroundOnLight.
  // Dark: Brand-100 (#479ef5) — mesmo tom usado como
  //   BrandForeground1 / CompoundBrandBackground no tema escuro,
  //   mais claro para manter contraste sobre fundos escuros.
  Color get primary            => isDark ? const Color(0xFF479EF5) : const Color(0xFF0F6CBD);
  Color get onPrimary          => isDark ? const Color(0xFF061724) : const Color(0xFFFFFFFF);
  // Brand-40 (dark) / Brand-160 (light) — containers de marca do Fluent.
  Color get primaryContainer   => isDark ? const Color(0xFF0C3B5E) : const Color(0xFFEBF3FC);
  Color get onPrimaryContainer => isDark ? const Color(0xFFCFE4FA) : const Color(0xFF0C3B5E);

  // ── Superfície / fundo ──────────────────────────────────────
  Color get surface            => isDark ? const Color(0xFF232323) : const Color(0xFFFFFFFF);
  Color get onSurface          => isDark ? const Color(0xFFEDEDED) : const Color(0xFF1B1B1B);
  Color get onSurfaceVariant   => isDark ? const Color(0xFFB8B8B8) : const Color(0xFF616161);
  Color get pageBackground     => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF6F7F9);
  Color get cardBackground     => isDark ? const Color(0xFF303030) : const Color(0xFFFFFFFF);

  // Fundo de superfícies flutuantes (popups ancorados, bottom
  // sheets) — antes hardcoded como 0xFF2C2C2E em vários sítios,
  // dessincronizado da paleta real. Agora deriva de cardBackground,
  // ligeiramente mais claro no dark para se destacar do pageBackground
  // (que é mais escuro) sem se confundir com a superfície normal.
  Color get floatingSurface    => isDark ? const Color(0xFF323234) : const Color(0xFFFFFFFF);

  // ── Contorno ────────────────────────────────────────────────
  Color get outline            => isDark ? const Color(0xFF4E4E4E) : const Color(0xFFD1D1D1);
  Color get outlineVariant     => isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E5E5);

  // ── Semânticas ──────────────────────────────────────────────
  // Erro/destrutivo: família Cranberry do Fluent 2 (não Red — é a
  // usada oficialmente em colorStatusDanger*).
  // Light: Cranberry-Primary (#c50f1f). Dark: Cranberry-Tint30
  // (#dc626d), que é literalmente o colorStatusDangerForeground1
  // do tema escuro nos tokens oficiais.
  Color get error              => isDark ? const Color(0xFFDC626D) : const Color(0xFFC50F1F);
  Color get onError            => isDark ? const Color(0xFF3B0509) : const Color(0xFFFFFFFF);
  // Container de erro (usado em fundos suaves de aviso destrutivo)
  Color get errorContainer     => isDark ? const Color(0xFF6E0811) : const Color(0xFFEEACB2);
  Color get onErrorContainer   => isDark ? const Color(0xFFF6D1D5) : const Color(0xFF3B0509);

  Color get success            => isDark ? const Color(0xFF9FD89F) : const Color(0xFF107C10);
  Color get warning            => isDark ? const Color(0xFFFFD166) : const Color(0xFFB45309);

  // ── Interacção ──────────────────────────────────────────────
  Color get barrier            => const Color(0x80000000);
  Color get hover              => isDark ? const Color(0x16FFFFFF) : const Color(0x08000000);
  Color get pressed            => isDark ? const Color(0x22FFFFFF) : const Color(0x10000000);

  // ── Bottom Nav (mantido para compatibilidade — já não usado no shell) ──
  Color get navBarBg           => isDark ? const Color(0xFF303030) : const Color(0xFFFFFFFF);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get navIconActive      => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F6CBD);
  Color get navLabelActive     => isDark ? const Color(0xFFCFE4FA) : const Color(0xFF0C3B5E);
  // Pill do tab ativo no drawer: cinza fraquinho no dark (em vez de azul),
  // mantém-se container azul claro no light.
  Color get navIndicatorBg     => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEBF3FC);

  // ── Projetos (tab) ──────────────────────────────────────────
  Color get projectsTabBg      => const Color(0xFF0F6CBD);
  Color get projectsTabFg      => const Color(0xFFFFFFFF);

  // ── Sombras ─────────────────────────────────────────────────
  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 2))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1)),
        ];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 3)),
        ];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 3)),
        ];

  // ── Modo incógnito ──────────────────────────────────────────
  // Fundo "mais profundo" que o pageBackground normal, usado
  // quando o modo incógnito está ativo — mesmo no tema claro, o
  // app assume um tom escuro dedicado.
  Color get incognitoBackground => const Color(0xFF0D0D0F);
  Color get incognitoSurface    => const Color(0xFF17171A);
  Color get incognitoOnSurface  => const Color(0xFFEDEDED);
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  bool isDark = false;
  bool isIncognito = false;
  void toggleDark() { isDark = !isDark; notifyListeners(); }
  void toggleIncognito() { isIncognito = !isIncognito; notifyListeners(); }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

class AppTheme extends InheritedNotifier<AppThemeNotifier> {
  AppTheme({super.key, required super.child}) : super(notifier: appTheme);

  static AppColorScheme of(BuildContext context) {
    final n = context.dependOnInheritedWidgetOfExactType<AppTheme>()?.notifier;
    return AppColorScheme(n?.isDark ?? false);
  }

  static bool isIncognito(BuildContext context) {
    final n = context.dependOnInheritedWidgetOfExactType<AppTheme>()?.notifier;
    return n?.isIncognito ?? false;
  }
}