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
          builder: (_, child) => ColoredBox(color: s.sheetBackdrop, child: child!),
          home: const AuthGate(),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ROOT SHELL — drawer tradicional (overlay push, tela cheia)
// O drawer entra deslizando da esquerda por cima do conteúdo.
// O conteúdo principal apenas sofre um leve deslocamento horizontal.
// ══════════════════════════════════════════════════════════════

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with ThemeReactive<RootShell>, SingleTickerProviderStateMixin {
  late final AnimationController _drawerCtrl = AnimationController(
    vsync: this,
    duration: _drawerAnim,
    value: 0.0,
  );

  bool get _drawerOpen => _drawerCtrl.value > 0.5;

  AppTab     _tab        = AppTab.ai;
  EditorType _editorType = EditorType.docs;
  bool       _hasMessages = false;

  final GlobalKey<AiTabState> _aiTabKey = GlobalKey<AiTabState>();

  void _openDrawer()  => _drawerCtrl.animateTo(1.0, curve: _drawerCurve);
  void _closeDrawer() => _drawerCtrl.animateTo(0.0, curve: _drawerCurve);
  void _toggleDrawer() => _drawerOpen ? _closeDrawer() : _openDrawer();

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
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

  /// Quando a IA cria um canvas, apenas carregamos o item no
  /// controller. A navegação para o editor NÃO é automática — o
  /// utilizador toca no card do documento para abrir.
  void _onCanvasCreated(LocalCanvasItem item) {
    editTabController.requestLoadLocal(item);
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

  static const Duration _drawerAnim = Duration(milliseconds: 320);
  static const Curve _drawerCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final isAiTab = _tab == AppTab.ai;
    final _drawerWidth = MediaQuery.of(context).size.width;

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

    return RootShellNavigation(
      switchToEditTab: (type) {
        setState(() {
          _editorType = type;
          _tab = AppTab.edit;
        });
      },
      child: Scaffold(
        backgroundColor: s.surface,
        body: Stack(
          children: [
            // Conteúdo principal — sofre leve deslocamento horizontal
            // quando o drawer abre (efeito push subtil).
            GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onHorizontalDragStart: (_) {
                _drawerCtrl.stop();
              },
              onHorizontalDragUpdate: (d) {
                final delta = d.delta.dx / _drawerWidth;
                _drawerCtrl.value = (_drawerCtrl.value + delta).clamp(0.0, 1.0);
              },
              onHorizontalDragEnd: (d) {
                final velocity = d.velocity.pixelsPerSecond.dx;
                if (velocity.abs() > 300) {
                  if (velocity > 0) {
                    _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                  } else {
                    _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                  }
                } else if (_drawerCtrl.value > 0.5) {
                  _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                } else {
                  _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                }
              },
              child: AnimatedBuilder(
                animation: _drawerCtrl,
                builder: (_, child) {
                  final t = _drawerCtrl.value;
                  return Transform.translate(
                    offset: Offset(_drawerWidth * 0.25 * t, 0),
                    child: child,
                  );
                },
                child: bodyContent,
              ),
            ),
            // Drawer — entra deslizando da esquerda por cima de tudo.
            Positioned(
              top: 0, bottom: 0, left: 0,
              width: _drawerWidth,
              child: AnimatedBuilder(
                animation: _drawerCtrl,
                builder: (_, child) {
                  final t = _drawerCtrl.value;
                  return Transform.translate(
                    offset: Offset(-_drawerWidth * (1.0 - t), 0),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    final delta = d.delta.dx / _drawerWidth;
                    _drawerCtrl.value = (_drawerCtrl.value + delta).clamp(0.0, 1.0);
                  },
                  onHorizontalDragEnd: (d) {
                    final velocity = d.velocity.pixelsPerSecond.dx;
                    if (velocity.abs() > 300) {
                      if (velocity > 0) {
                        _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                      } else {
                        _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                      }
                    } else if (_drawerCtrl.value > 0.5) {
                      _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                    } else {
                      _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                    }
                  },
                  child: Material(
                    color: s.surface,
                    child: AnimatedBuilder(
                      animation: _AiTabHeaderRefresh.of(context),
                      builder: (_, __) => AppDrawer(
                        s: s,
                        onClose: _closeDrawer,
                        onSettings: _openSettings,
                        currentTab: _tab,
                        onSelectTab: _selectTab,
                        onOpenConversation: _onOpenConversation,
                        onNewChat: () =>
                            _onConversationAction(ConversationAction.newChat),
                        activeConversationId: _aiTabKey.currentState?.conversationId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        // Botão de menu em container circular
        GestureDetector(
          onTap: onMenu,
          child: Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.cardBackground,
              shape: BoxShape.circle,
              boxShadow: s.cardShadow,
            ),
            child: Icon(CupertinoIcons.bars, color: s.onSurface, size: 20),
          ),
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
        if (trailing != null)
          // Envolver trailing em container circular também
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.cardBackground,
              shape: BoxShape.circle,
              boxShadow: s.cardShadow,
            ),
            child: trailing,
          ),
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