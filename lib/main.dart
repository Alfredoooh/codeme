// ══════════════════════════════════════════════════════════════
// FILE: lib/main.dart
// ══════════════════════════════════════════════════════════════
import 'dart:ui';
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
          theme: AppTheme.buildTheme(isDark: false),
          darkTheme: AppTheme.buildTheme(isDark: true),
          themeMode: s.isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (_, child) => ColoredBox(color: s.surface, child: child!),
          home: const AuthGate(),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ROOT SHELL — drawer estilo "push" com gesto contínuo.
// O drawer fica sempre fixo por baixo; o conteúdo principal desliza
// para a direita conforme o dedo, com encolhimento e cantos que
// arredondam proporcionalmente ao progresso do gesto.
// ══════════════════════════════════════════════════════════════

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with ThemeReactive<RootShell>, SingleTickerProviderStateMixin {
  late final AnimationController _drawerCtrl = AnimationController(
    vsync: this,
    duration: kDurationSlower,
    value: 0.0,
  );

  bool get _drawerOpen => _drawerCtrl.value > 0.5;

  AppTab _tab = AppTab.ai;
  EditorType _editorType = EditorType.docs;
  bool _hasMessages = false;

  final GlobalKey<AiTabState> _aiTabKey = GlobalKey<AiTabState>();

  void _openDrawer() => _drawerCtrl.animateTo(1.0, curve: kFluentStandard);
  void _closeDrawer() => _drawerCtrl.animateTo(0.0, curve: kFluentStandard);
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
      if (action == ConversationAction.newChat ||
          action == ConversationAction.incognito) {
        _hasMessages =
            action == ConversationAction.newChat ? false : _hasMessages;
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
  }

  String get _tabTitle {
    switch (_tab) {
      case AppTab.ai:
        return '';
      case AppTab.edit:
        return _editorType.label;
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
          onExternalActionConsumed: () =>
              setState(() => _pendingConversationAction = null),
          initialConversationId: _pendingConversationLoad,
          onConversationLoadConsumed: _onConversationLoadConsumed,
          onHasMessagesChanged: (v) => setState(() => _hasMessages = v),
          onCanvasCreated: _onCanvasCreated,
        );
      case AppTab.edit:
        return EditorScreen(editorType: _editorType);
    }
  }

  static const double _drawerWidth = 304;
  static const double _drawerRadius = 30.0;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final isAiTab = _tab == AppTab.ai;

    final bodyContent = isAiTab
        ? Stack(children: [
            Positioned.fill(
              top: 0,
              child: AnimatedSwitcher(
                duration: kDurationSlow,
                switchInCurve: kFluentDecelerate,
                switchOutCurve: kFluentAccelerate,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(key: ValueKey(_tab), child: _buildTab()),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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
                      s: s,
                      current: _editorType,
                      onSelect: _setEditorType,
                    )
                  : null,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: kDurationSlow,
                switchInCurve: kFluentDecelerate,
                switchOutCurve: kFluentAccelerate,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(key: ValueKey(_tab), child: _buildTab()),
              ),
            ),
          ]);

    return Scaffold(
      backgroundColor: s.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _drawerCtrl.stop(),
              onHorizontalDragUpdate: (details) {
                final delta = details.delta.dx / _drawerWidth;
                _drawerCtrl.value =
                    (_drawerCtrl.value + delta).clamp(0.0, 1.0);
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.velocity.pixelsPerSecond.dx;
                final shouldOpen = velocity > 300 ||
                    (velocity.abs() <= 300 && _drawerCtrl.value > 0.5);
                _drawerCtrl.animateTo(
                  shouldOpen ? 1.0 : 0.0,
                  curve: Curves.easeOutCubic,
                  duration: const Duration(milliseconds: 280),
                );
              },
              child: AbsorbPointer(
                absorbing: _drawerOpen,
                child: bodyContent,
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _drawerCtrl,
              builder: (_, __) {
                final t = _drawerCtrl.value;
                return IgnorePointer(
                  ignoring: t <= 0.01,
                  child: GestureDetector(
                    onTap: _closeDrawer,
                    behavior: HitTestBehavior.opaque,
                    child: ColoredBox(
                      color: Colors.black.withOpacity(0.22 * t),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: _drawerWidth,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _drawerCtrl,
                _AiTabHeaderRefresh.of(context),
              ]),
              builder: (_, __) {
                final t = _drawerCtrl.value;
                return Transform.translate(
                  offset: Offset(-_drawerWidth * (1.0 - t), 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _drawerCtrl.stop(),
                    onHorizontalDragUpdate: (details) {
                      final delta = details.delta.dx / _drawerWidth;
                      _drawerCtrl.value =
                          (_drawerCtrl.value + delta).clamp(0.0, 1.0);
                    },
                    onHorizontalDragEnd: (details) {
                      final velocity = details.velocity.pixelsPerSecond.dx;
                      final shouldRemainOpen = velocity > 300 ||
                          (velocity.abs() <= 300 && _drawerCtrl.value > 0.5);
                      _drawerCtrl.animateTo(
                        shouldRemainOpen ? 1.0 : 0.0,
                        curve: Curves.easeOutCubic,
                        duration: const Duration(milliseconds: 280),
                      );
                    },
                    child: Material(
                      color: s.surface,
                      elevation: 16,
                      shadowColor: Colors.black.withOpacity(0.18),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(_drawerRadius),
                        bottomRight: Radius.circular(_drawerRadius),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AppDrawer(
                      s: s,
                      onClose: _closeDrawer,
                      onSettings: _openSettings,
                      currentTab: _tab,
                      onSelectTab: _selectTab,
                      onOpenConversation: _onOpenConversation,
                      onNewChat: () =>
                          _onConversationAction(ConversationAction.newChat),
                        activeConversationId:
                            _aiTabKey.currentState?.conversationId,
                      ),
                    ),
                  ),
                );
              },
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
  @override
  State<AiTabHost> createState() => _AiTabHostState();
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
      onCanvasCreated: widget.onCanvasCreated,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APP HEADER
// Progressive blur estilo Apple: BackdropFilter com ImageFilter.blur
// num gradiente semi-transparente — blur forte no topo, dissolve
// para completamente transparente na base.
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
    final topPadding = MediaQuery.of(context).padding.top;

    final content = Padding(
      padding: EdgeInsets.only(
        top: topPadding + kSpaceXS,
        bottom: kSpaceS + kSpaceXXS,
        left: kSpaceXS,
        right: kSpaceS + kSpaceXXS,
      ),
      child: Row(
        children: [
          AppTap(
            onTap: onMenu,
            s: s,
            child: AppIcon('menu.svg', color: s.onSurface, size: 20),
          ),
          SizedBox(width: kSpaceS),
          if (title.isNotEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: kTypeBodyLarge,
                fontWeight: FontWeight.w600,
                color: s.onSurface,
              ),
            ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );

    // Modo opaco — tab de editor, sem blur
    if (!transparent) {
      return Container(color: headerBackground, child: content);
    }

    // Modo transparente (tab AI) — progressive blur estilo Apple
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                headerBackground.withOpacity(s.isDark ? 0.82 : 0.88),
                headerBackground.withOpacity(0.0),
              ],
              stops: const [0.55, 1.0],
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}