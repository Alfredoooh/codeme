// ══════════════════════════════════════════════════════════════
// FILE: lib/main.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'widgets.dart';
import 'drawermenu.dart';
import 'aitab.dart';
import 'edittab.dart';
import 'templatestab.dart';
import 'projectstab.dart';
import 'settingsscreen.dart';
import 'sheets.dart';
import 'auth_service.dart';
import 'authscreens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await appTheme.load();
  runApp(const CraftLabApp());
}

// ══════════════════════════════════════════════════════════════
// APP ROOT
// ══════════════════════════════════════════════════════════════

class CraftLabApp extends StatelessWidget {
  const CraftLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTheme(
      child: Builder(builder: (ctx) {
        final s = AppTheme.of(ctx);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: s.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              s.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ));
        return MaterialApp(
          title: 'CraftLab',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7BF6)),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2F7BF6),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: s.isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (_, child) => ColoredBox(color: s.surface, child: child!),
          home: const AuthGate(),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ROOT SHELL
// ══════════════════════════════════════════════════════════════

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with TickerProviderStateMixin {
  late final SpringNav _springNav;
  bool _drawerOpen = false;

  AppTab     _tab        = AppTab.ai;
  EditorType _editorType = EditorType.docs;
  bool       _hasMessages = false;

  final GlobalKey<AiTabState> _aiTabKey = GlobalKey<AiTabState>();

  /// Fonte única de verdade sobre o drawer estar em modo 280px ou
  /// ecrã inteiro. Passado diretamente ao AppDrawer (que o controla
  /// via toque/gesto) e lido aqui no Positioned para dimensionar-se
  /// de forma sempre coerente com o que o drawer realmente desenha —
  /// é isto que elimina o bug da faixa cinza (Positioned largo demais
  /// para um drawer interno ainda estreito, ou vice-versa).
  final ValueNotifier<bool> _drawerExpanded = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _springNav = SpringNav(vsync: this);
    _springNav.slideCtrl.value = 1.0;
    _drawerExpanded.addListener(_onDrawerExpandedChanged);
  }

  @override
  void dispose() {
    _drawerExpanded.removeListener(_onDrawerExpandedChanged);
    _drawerExpanded.dispose();
    _springNav.dispose();
    super.dispose();
  }

  void _onDrawerExpandedChanged() { if (mounted) setState(() {}); }

  void _openDrawer()  { setState(() => _drawerOpen = true);  _springNav.open(); }
  void _closeDrawer() {
    setState(() => _drawerOpen = false);
    _springNav.close();
    // Ao fechar por completo, o drawer volta sempre ao estado
    // colapsado (280px) para a próxima abertura — evita reabrir já
    // expandido inesperadamente por um estado esquecido do gesto.
    _drawerExpanded.value = false;
  }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _selectTab(AppTab t) {
    _closeDrawer();
    if (t != _tab) setState(() => _tab = t);
  }

  void _setEditorType(EditorType t) => setState(() => _editorType = t);
  void _onMessageSent() {
    if (!_hasMessages) setState(() => _hasMessages = true);
  }

  ConversationAction? _pendingConversationAction;
  int _aiTabInstance = 0;
  String? _pendingConversationLoad;

  void _onConversationAction(ConversationAction action) {
    setState(() {
      _pendingConversationAction = action;
      if (action == ConversationAction.newChat || action == ConversationAction.incognito) {
        _hasMessages = action == ConversationAction.newChat ? false : _hasMessages;
      }
    });
  }

  void _onOpenConversation(String id) {
    setState(() {
      _tab = AppTab.ai;
      _pendingConversationLoad = id;
      _hasMessages = true;
    });
  }

  void _onConversationLoadConsumed() {
    setState(() => _pendingConversationLoad = null);
  }

  String get _tabTitle {
    switch (_tab) {
      case AppTab.ai:        return '';
      case AppTab.edit:      return _editorType.label;
      case AppTab.templates: return 'Modelos';
      case AppTab.projects:  return 'Projectos';
    }
  }

  Widget _buildTab() {
    switch (_tab) {
      case AppTab.ai:
        return AiTabHost(
          key: ValueKey('ai_$_aiTabInstance'),
          aiTabKey: _aiTabKey,
          onFirstMessage: _onMessageSent,
          externalAction: _pendingConversationAction,
          onExternalActionConsumed: () => setState(() => _pendingConversationAction = null),
          initialConversationId: _pendingConversationLoad,
          onConversationLoadConsumed: _onConversationLoadConsumed,
          onHasMessagesChanged: (v) => setState(() => _hasMessages = v),
        );
      case AppTab.edit:
        return EditTab(editorType: _editorType);
      case AppTab.templates:
        return const TemplatesTab();
      case AppTab.projects:
        return const ProjectsTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final isAiTab = _tab == AppTab.ai;
    final screenWidth = MediaQuery.of(context).size.width;
    // Largura EXATA do próprio Positioned, lida do mesmo notifier que
    // o AppDrawer usa internamente — nunca mais divergem.
    final drawerWidth = _drawerExpanded.value ? screenWidth : 280.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        ColoredBox(
          color: isAiTab ? s.pageBackground : s.surface,
          child: isAiTab
              ? Stack(children: [
                  Positioned.fill(
                    top: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: kCupertinoOut,
                      switchOutCurve: kCupertinoIn,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: KeyedSubtree(key: ValueKey(_tab), child: _buildTab()),
                    ),
                  ),
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: AnimatedBuilder(
                      animation: _AiTabHeaderRefresh.of(context),
                      builder: (_, __) {
                        final st = _aiTabKey.currentState;
                        return _AppHeader(
                          s: s,
                          title: _tabTitle,
                          onMenu: _openDrawer,
                          transparent: true,
                          headerBackground: s.pageBackground,
                          trailing: AiConversationMenuButton(
                            s: s,
                            hasMessages: _hasMessages,
                            onSelect: _onConversationAction,
                            canvasCount: st?.canvasCount ?? 0,
                            onOpenCanvas: () => st?.openCanvasPopupExternally(),
                            webSearchEnabled: st?.webSearchEnabled ?? false,
                            onToggleWebSearch: (v) => st?.setWebSearchEnabled(v),
                            widgetsEnabled: st?.widgetsEnabled ?? false,
                            onToggleWidgets: (v) => st?.setWidgetsEnabled(v),
                          ),
                        );
                      },
                    ),
                  ),
                ])
              : Column(children: [
                  _AppHeader(
                    s: s,
                    title: _tabTitle,
                    onMenu: _openDrawer,
                    transparent: false,
                    headerBackground: s.surface,
                    trailing: _tab == AppTab.edit
                        ? EditTypeButton(
                            s: s, current: _editorType, onSelect: _setEditorType)
                        : null,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve:  kCupertinoOut,
                      switchOutCurve: kCupertinoIn,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: KeyedSubtree(key: ValueKey(_tab), child: _buildTab()),
                    ),
                  ),
                ]),
        ),

        if (_drawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDrawer,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: kCupertinoOut,
                // O barrier (fundo escurecido) só é visível na fatia da
                // tela NÃO coberta pelo drawer — evita qualquer resíduo
                // cinza sobre a área onde o drawer já desenha o próprio
                // fundo (s.surface). Quando drawerWidth == screenWidth
                // (expandido), o barrier fica com largura zero — nunca
                // mais aparece cinza por cima do drawer expandido.
                margin: EdgeInsets.only(left: drawerWidth),
                color: s.barrier,
              ),
            ),
          ),

        AnimatedBuilder(
          animation: _springNav.slideCtrl,
          builder: (_, child) {
            final v = _springNav.slideCtrl.value.clamp(0.0, 1.0);
            return Positioned(
              top: 0, bottom: 0,
              width: drawerWidth,
              left: -drawerWidth + drawerWidth * (1.0 - v),
              child: child!,
            );
          },
          child: AppDrawer(
            s: s,
            onClose: _closeDrawer,
            onSettings: _openSettings,
            currentTab: _tab,
            onSelectTab: _selectTab,
            onOpenConversation: _onOpenConversation,
            onNewChat: () => _onConversationAction(ConversationAction.newChat),
            expandedNotifier: _drawerExpanded,
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI TAB HEADER REFRESH
// ══════════════════════════════════════════════════════════════

class _AiTabHeaderRefresh extends ChangeNotifier {
  static final _AiTabHeaderRefresh _instance = _AiTabHeaderRefresh._();
  _AiTabHeaderRefresh._();
  static _AiTabHeaderRefresh of(BuildContext context) => _instance;
  void ping() => notifyListeners();
}

// ══════════════════════════════════════════════════════════════
// AI TAB HOST
// ══════════════════════════════════════════════════════════════

class AiTabHost extends StatefulWidget {
  final GlobalKey<AiTabState> aiTabKey;
  final VoidCallback onFirstMessage;
  final ConversationAction? externalAction;
  final VoidCallback onExternalActionConsumed;
  final String? initialConversationId;
  final VoidCallback? onConversationLoadConsumed;
  final ValueChanged<bool>? onHasMessagesChanged;
  const AiTabHost({
    super.key,
    required this.aiTabKey,
    required this.onFirstMessage,
    required this.externalAction,
    required this.onExternalActionConsumed,
    this.initialConversationId,
    this.onConversationLoadConsumed,
    this.onHasMessagesChanged,
  });
  @override State<AiTabHost> createState() => _AiTabHostState();
}

class _AiTabHostState extends State<AiTabHost> {
  @override
  void didUpdateWidget(covariant AiTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConversationId != null &&
        widget.initialConversationId != oldWidget.initialConversationId) {
      widget.onConversationLoadConsumed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AiTab(
      key: widget.aiTabKey,
      onFirstMessage: widget.onFirstMessage,
      externalAction: widget.externalAction,
      onExternalActionConsumed: widget.onExternalActionConsumed,
      initialConversationId: widget.initialConversationId,
      onHasMessagesChanged: widget.onHasMessagesChanged,
      onHeaderStateChanged: () => _AiTabHeaderRefresh.of(context).ping(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APP HEADER
// ══════════════════════════════════════════════════════════════

class _AppHeader extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onMenu;
  final Widget? trailing;
  final bool transparent;
  final Color headerBackground;

  const _AppHeader({
    required this.s,
    required this.title,
    required this.onMenu,
    required this.headerBackground,
    this.trailing,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 10, left: 6, right: 10,
      ),
      child: Row(children: [
        AppTap(
          onTap: onMenu, s: s,
          child: AppIcon('menu.svg', color: s.onSurface, size: 20),
        ),
        const SizedBox(width: 8),
        if (title.isNotEmpty)
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: s.onSurface,
            ),
          ),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );

    if (!transparent) {
      return Container(color: headerBackground, child: content);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            headerBackground,
            headerBackground.withOpacity(0.0),
          ],
        ),
      ),
      child: content,
    );
  }
}