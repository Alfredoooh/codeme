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
import 'editorscreen.dart';
import 'settingsscreen.dart';
import 'sheets.dart';
import 'auth_service.dart';
import 'authscreens.dart';
import 'home/home.dart';

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
// ROOT SHELL — drawer estilo "push": o drawer fica sempre fixo por
// baixo, a ocupar a largura _drawerWidth encostado à esquerda; é o
// conteúdo principal (bodyContent) que desliza para a direita quando
// abre, revelando o drawer que já lá estava — nunca o drawer que se
// move para dentro do ecrã. Sem o pacote flutter_slider_drawer.
//
// FIX (alinhamento): a versão anterior tinha o drawer dentro de um
// AnimatedPositioned que também animava a sua própria posição
// (left: -_drawerWidth → 0), ao mesmo tempo que o conteúdo também
// animava via transform. As duas animações concorrentes causavam o
// desalinhamento visto no ecrã (drawer a aparecer fora da área
// revelada). Agora o drawer fica num Positioned estático (sempre em
// left:0, sempre montado), e só o conteúdo acima dele anima.
// ══════════════════════════════════════════════════════════════

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with ThemeReactive<RootShell> {
  bool _drawerOpen = false;

  AppTab     _tab        = AppTab.ai;
  EditorType _editorType = EditorType.docs;
  bool       _hasMessages = false;

  final GlobalKey<AiTabState> _aiTabKey = GlobalKey<AiTabState>();

  void _openDrawer()  => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);
  void _toggleDrawer() => setState(() => _drawerOpen = !_drawerOpen);

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _goHome() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const HomeScreen()));
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

  void _onCanvasCreated(LocalCanvasItem item) {
    editTabController.requestLoadLocal(item);
    setState(() {
      _editorType = item.kind.editorType;
      _tab = AppTab.edit;
    });
  }

  String get _tabTitle {
    switch (_tab) {
      case AppTab.ai:   return '';
      case AppTab.edit: return _editorType.label;
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
          onCanvasCreated: _onCanvasCreated,
        );
      case AppTab.edit:
        return EditorScreen(editorType: _editorType);
    }
  }

  static const double _drawerWidth = 280;
  static const Duration _drawerAnim = Duration(milliseconds: 380);
  static const Curve _drawerCurve = Curves.easeOutQuint;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final isAiTab = _tab == AppTab.ai;

    final bodyContent = isAiTab
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
                    onMenu: _toggleDrawer,
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
              onMenu: _toggleDrawer,
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
          ]);

    return Scaffold(
      backgroundColor: s.surface,
      body: Stack(
        children: [
          // Drawer — sempre montado, sempre fixo na mesma posição
          // por baixo do conteúdo. Nunca se move; é revelado quando
          // o conteúdo por cima desliza para a direita.
          Positioned(
            top: 0, bottom: 0, left: 0,
            width: _drawerWidth,
            child: Material(
              color: s.surface,
              child: AppDrawer(
                s: s,
                onClose: _closeDrawer,
                onSettings: _openSettings,
                onGoHome: _goHome,
                currentTab: _tab,
                onSelectTab: _selectTab,
                onOpenConversation: _onOpenConversation,
                onNewChat: () =>
                    _onConversationAction(ConversationAction.newChat),
              ),
            ),
          ),
          // Conteúdo principal — desliza inteiro para a direita numa
          // só peça (sombra própria incluída), revelando o drawer por
          // baixo. Curva mais suave e ligeiramente mais longa para a
          // sensação premium pedida.
          AnimatedContainer(
            duration: _drawerAnim,
            curve: _drawerCurve,
            transform: Matrix4.translationValues(
              _drawerOpen ? _drawerWidth : 0, 0, 0,
            ),
            decoration: BoxDecoration(
              boxShadow: _drawerOpen
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(-4, 0),
                      ),
                    ]
                  : const [],
            ),
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                if (_drawerOpen && d.delta.dx < -6) _closeDrawer();
              },
              behavior: HitTestBehavior.deferToChild,
              child: AbsorbPointer(
                absorbing: _drawerOpen,
                child: bodyContent,
              ),
            ),
          ),
          // Área tocável sobre o conteúdo deslocado, quando o drawer
          // está aberto — toque em qualquer ponto do conteúdo
          // (agora revelado ao lado) fecha o drawer.
          if (_drawerOpen)
            Positioned(
              top: 0, bottom: 0,
              left: _drawerWidth, right: 0,
              child: GestureDetector(
                onTap: _closeDrawer,
                behavior: HitTestBehavior.translucent,
              ),
            ),
        ],
      ),
    );
  }
}

class _AiTabHeaderRefresh extends ChangeNotifier {
  static final _AiTabHeaderRefresh _instance = _AiTabHeaderRefresh._();
  _AiTabHeaderRefresh._();
  static _AiTabHeaderRefresh of(BuildContext context) => _instance;
  void ping() => notifyListeners();
}

class AiTabHost extends StatefulWidget {
  final GlobalKey<AiTabState> aiTabKey;
  final VoidCallback onFirstMessage;
  final ConversationAction? externalAction;
  final VoidCallback onExternalActionConsumed;
  final String? initialConversationId;
  final VoidCallback? onConversationLoadConsumed;
  final ValueChanged<bool>? onHasMessagesChanged;
  final ValueChanged<LocalCanvasItem>? onCanvasCreated;
  const AiTabHost({
    super.key,
    required this.aiTabKey,
    required this.onFirstMessage,
    required this.externalAction,
    required this.onExternalActionConsumed,
    this.initialConversationId,
    this.onConversationLoadConsumed,
    this.onHasMessagesChanged,
    this.onCanvasCreated,
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

  void _goToEditTab(EditorType type) {
    RootShellNavigation.of(context)?.switchToEditTab(type);
  }

  @override
  Widget build(BuildContext context) {
    return AiTabHostNavigation(
      goToEditTab: _goToEditTab,
      child: AiTab(
        key: widget.aiTabKey,
        onFirstMessage: widget.onFirstMessage,
        externalAction: widget.externalAction,
        onExternalActionConsumed: widget.onExternalActionConsumed,
        initialConversationId: widget.initialConversationId,
        onHasMessagesChanged: widget.onHasMessagesChanged,
        onHeaderStateChanged: () => _AiTabHeaderRefresh.of(context).ping(),
        onCanvasCreated: widget.onCanvasCreated,
      ),
    );
  }
}

class RootShellNavigation extends InheritedWidget {
  final ValueChanged<EditorType> switchToEditTab;
  const RootShellNavigation({
    super.key,
    required this.switchToEditTab,
    required super.child,
  });

  static RootShellNavigation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RootShellNavigation>();

  @override
  bool updateShouldNotify(RootShellNavigation oldWidget) => true;
}

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