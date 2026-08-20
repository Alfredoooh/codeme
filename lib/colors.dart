import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Curve kCupertino    = Cubic(0.25, 0.1,  0.25, 1.0);
const Curve kCupertinoIn  = Cubic(0.42, 0.0,  1.0,  1.0);
const Curve kCupertinoOut = Cubic(0.0,  0.0,  0.58, 1.0);

// ══════════════════════════════════════════════════════════════
// MODO DE TEMA — três estados reais: claro, escuro, automático.
// "Automático" acompanha o Brightness do sistema operativo e
// atualiza-se sozinho quando o utilizador muda o tema do telemóvel
// enquanto a app está aberta (via SchedulerBinding platform
// dispatcher callback, sem precisar reabrir a app).
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

  /// Fundo dos cards no tema claro é agora branco puro absoluto —
  /// pedido explícito do utilizador para diferenciar claramente do
  /// pageBackground (que continua ligeiramente acinzentado) e dar
  /// aquele "brilho" de card sólido tipo iOS. Dark mode inalterado.
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
  /// preview tal como a imagem de referência mostra.
  Color get previewBackdrop    => isDark ? const Color(0xFF242426) : const Color(0xFFEFEFF1);

  /// Fundo do container que embrulha a barra de ações do
  /// DocumentWidgetCard (botão pill "Abrir direto no editor" + botão
  /// circular de download). Pedido explícito do utilizador: este
  /// container tem de variar com o tema, nunca fixo.
  Color get downloadButtonBg   => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEFEFF1);

  /// Sombra de cards e botões isolados (drawer, contas, resultados
  /// de pesquisa, settings). REDUZIDA a pedido do utilizador — em
  /// modo claro passa a ser quase imperceptível (0.05/blur 8, sem
  /// segunda camada de reforço), só o suficiente para separar o
  /// card branco puro do pageBackground sem parecer "flutuante
  /// pesado". Dark mode também reduzido proporcionalmente.
  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 7, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.38), blurRadius: 14, offset: const Offset(0, 5))]
      : [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 5))];

  /// Sombra reduzida — usada nos cards de lista de settings, para
  /// não competir visualmente com o cardShadow "profundo" do drawer
  /// (pedido explícito: mesmo estilo dos cards do drawer, mas sem
  /// sombra tão profunda). Já era a mais leve; acompanhou a redução
  /// geral proporcionalmente.
  List<BoxShadow> get cardShadowSoft => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 4, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 1))];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 3))]
      : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))];

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
// Agora com 3 modos reais: light / dark / system. Em modo system,
// isDark é derivado do Brightness atual da plataforma e atualiza-se
// sozinho em runtime via PlatformDispatcher.onPlatformBrightness
// ChangedCallback, sem precisar reiniciar a app nem navegar.
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  static const _kModeKey = 'app_theme_mode';

  AppThemeMode mode = AppThemeMode.system;
  bool isIncognito = false;

  /// Resolve o Brightness atual do sistema operativo diretamente do
  /// PlatformDispatcher — não depende de um BuildContext, por isso
  /// pode ser lido a partir do ChangeNotifier global sem árvore.
  bool get _systemIsDark =>
      SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

  /// Valor efetivo consumido por AppTheme.of(context) — resolve
  /// "system" para o Brightness real do SO em tempo real.
  bool get isDark {
    switch (mode) {
      case AppThemeMode.light:  return false;
      case AppThemeMode.dark:   return true;
      case AppThemeMode.system: return _systemIsDark;
    }
  }

  AppThemeNotifier() {
    // Regista-se para saber quando o utilizador muda o tema do
    // telemóvel enquanto a app está aberta, e só reage a isso
    // quando o modo ativo é "system" — caso contrário o notify
    // seria desnecessário (o tema já está fixo por escolha do
    // utilizador).
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
        // Migração: instalações antigas guardavam só um bool.
        final legacyDark = prefs.getBool('app_theme_is_dark');
        if (legacyDark != null) {
          mode = legacyDark ? AppThemeMode.dark : AppThemeMode.light;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void setMode(AppThemeMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
    _persist();
  }

  /// Mantido por compatibilidade com chamadas existentes
  /// (appTheme.toggleDark() em drawermenu.dart) — alterna
  /// diretamente entre claro e escuro, saindo do modo automático.
  void toggleDark() {
    setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }

  void setDark(bool value) {
    setMode(value ? AppThemeMode.dark : AppThemeMode.light);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModeKey, mode.storageValue);
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