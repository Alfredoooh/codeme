import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Curve kCupertino    = Cubic(0.25, 0.1,  0.25, 1.0);
const Curve kCupertinoIn  = Cubic(0.42, 0.0,  1.0,  1.0);
const Curve kCupertinoOut = Cubic(0.0,  0.0,  0.58, 1.0);

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  // Apple System Blue
  Color get primary            => isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get onPrimary          => isDark ? const Color(0xFF001A33) : const Color(0xFFFFFFFF);
  Color get primaryContainer   => isDark ? const Color(0xFF0D2847) : const Color(0xFFE5F1FF);
  Color get onPrimaryContainer => isDark ? const Color(0xFFCFE4FF) : const Color(0xFF0D2847);

  // Apple System Gray palette (surfaces)
  Color get surface            => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get onSurface          => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1C1C1E);
  Color get onSurfaceVariant   => isDark ? const Color(0xFF9B9B9F) : const Color(0xFF6E6E73);
  Color get pageBackground     => isDark ? const Color(0xFF121212) : const Color(0xFFF7F7F9);
  Color get cardBackground     => isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);

  Color get floatingSurface    => isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);

  Color get outline            => isDark ? const Color(0xFF48484A) : const Color(0xFFDCDCE0);
  Color get outlineVariant     => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFECECEE);

  // Apple System Red
  Color get error              => isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
  Color get onError            => isDark ? const Color(0xFF330705) : const Color(0xFFFFFFFF);
  Color get errorContainer     => isDark ? const Color(0xFF5C1A16) : const Color(0xFFFFD8D5);
  Color get onErrorContainer   => isDark ? const Color(0xFFFFD8D5) : const Color(0xFF5C1A16);

  // Apple System Green / Orange
  Color get success            => isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
  Color get warning            => isDark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);

  Color get barrier            => const Color(0x80000000);
  Color get hover              => isDark ? const Color(0x16FFFFFF) : const Color(0x08000000);
  Color get pressed            => isDark ? const Color(0x22FFFFFF) : const Color(0x10000000);

  Color get navBarBg           => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFBFBFC);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get navIconActive      => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF007AFF);
  Color get navLabelActive     => isDark ? const Color(0xFFCFE4FF) : const Color(0xFF0D2847);
  Color get navIndicatorBg     => isDark ? const Color(0xFF2C3E50) : const Color(0xFFE5F1FF);

  Color get projectsTabBg      => const Color(0xFF007AFF);
  Color get projectsTabFg      => const Color(0xFFFFFFFF);

  /// Fundo da área de preview (grande, topo) do DocumentWidgetCard —
  /// onde a InAppWebView em miniatura / stack de páginas A4 aparece.
  /// Cinza claro neutro em light, cinza escuro neutro em dark — nunca
  /// a mesma cor do cardBackground, para dar profundidade visual ao
  /// preview tal como a imagem de referência (Image 1) mostra.
  Color get previewBackdrop    => isDark ? const Color(0xFF242426) : const Color(0xFFEFEFF1);

  /// Fundo do container que embrulha a barra de ações do
  /// DocumentWidgetCard (botão pill "Abrir direto no editor" + botão
  /// circular de download). Pedido explícito do utilizador: este
  /// container tem de variar com o tema, nunca fixo.
  Color get downloadButtonBg   => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEFEFF1);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 2))]
      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 22, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1)),
        ];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))]
      : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 3))];

  Color get incognitoBackground => const Color(0xFF121212);
  Color get incognitoSurface    => const Color(0xFF1C1C1E);
  Color get incognitoOnSurface  => const Color(0xFFFFFFFF);

  /// Fundo do "encolhimento" atrás de um CupertinoSheetRoute.
  /// Tem de ser SEMPRE escuro profundo, independente do tema —
  /// nunca ligado a isDark. É o que aparece nas bordas/cantos da
  /// tela que fica visível por trás do modal quando esta encolhe.
  Color get sheetBackdrop => const Color(0xFF0B0B0D);
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
// AppTheme — wrapper estático fino sobre o appTheme global.
// AppTheme.of(context) devolve sempre o estado atual, direto do
// ChangeNotifier, sem depender em que ponto da árvore o context se
// encontra.
//
// O AnimatedBuilder aqui dentro só garante reatividade para o
// subtree imediato do MaterialApp (theme/darkTheme/themeMode). Para
// que telas mais profundas (RootShell, EditTab, SettingsScreen)
// também reconstruam sozinhas quando appTheme notifica — sem
// precisar de navegar para disparar outro setState por acidente —
// cada uma dessas telas agora regista o seu próprio
// appTheme.addListener no initState. Ver main.dart/edittab.dart.
// ══════════════════════════════════════════════════════════════

class AppTheme extends StatelessWidget {
  final Widget child;
  const AppTheme({super.key, required this.child});

  static AppColorScheme of(BuildContext context) => AppColorScheme(appTheme.isDark);
  static bool isIncognito(BuildContext context) => appTheme.isIncognito;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTheme,
      builder: (_, __) => child,
    );
  }
}

/// Mixin de conveniência: State<T> que precisa de reconstruir sempre
/// que o tema global muda, sem depender de outro setState acidental
/// (navegação, envio de mensagem, etc.) para "empurrar" o rebuild.
/// Usar assim:
///   class _MyScreenState extends State<MyScreen> with ThemeReactive<MyScreen> {
/// Chama automaticamente addListener no initState e removeListener no
/// dispose — não precisa de mais nada além do mixin na declaração.
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