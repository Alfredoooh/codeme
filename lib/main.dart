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
// ROOT SHELL — drawer estilo overlay slide (iOS): drawer desliza
// por cima do conteúdo, conteúdo fica parado, overlay escurece
// atrás do drawer.
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
    duration: kDurationDrawer,
    value: 0.0,
  );

  bool get _drawerOpen => _drawerCtrl.value > 0.5;

  AppTab _tab = AppTab.ai;
  EditorType _editorType = EditorType.docs;
  bool _hasMessages = false;

  final GlobalKey<AiTabState> _aiTabKey = GlobalKey<AiTabState>();

  void _openDrawer() => _drawerCtrl.animateTo(1.0, curve: kAppleDrawer);
  void _closeDrawer() => _drawerCtrl.animateTo(0.0, curve: kAppleDrawer);
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

  static const double _drawerWidth = 280;
  static const double _drawerRadius = 24.0;

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
      backgroundColor: s.surface,
      body: Stack(
        children: [
          bodyContent,
          AnimatedBuilder(
            animation: _drawerCtrl,
            builder: (_, __) {
              if (_drawerCtrl.value == 0.0) return const SizedBox.shrink();
              return GestureDetector(
                onTap: _closeDrawer,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withOpacity(0.45 * _drawerCtrl.value),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _drawerCtrl,
            builder: (_, child) {
              final t = _drawerCtrl.value;
              return Transform.translate(
                offset: Offset(_drawerWidth * (t - 1.0), 0.0),
                child: child,
              );
            },
            child: Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: _drawerWidth,
              child: Material(
                elevation: 16,
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
                    activeConversationId:
                        _aiTabKey.currentState?.conversationId,
                  ),
                ),
              ),
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