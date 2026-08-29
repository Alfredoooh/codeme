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
import 'settingsscreen.dart';
import 'sheets.dart';
import 'auth_service.dart';
import 'authscreens.dart';
import 'apps/app_types.dart';
import 'apps/registry/app_registry.dart';
import 'apps/docs.dart';
import 'apps/sheets_app.dart';
import 'apps/slides_app.dart';
import 'apps/sound.dart';

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
  await appPreferences.load();

  // Registro dos apps com proteção contra falhas
  try {
    DocsScreen.bootstrap();
    SheetsScreen.bootstrap();
    SlidesScreen.bootstrap();
    SoundScreen.bootstrap();
  } catch (e) {
    debugPrint('Erro ao registar apps: $e');
  }

  // Carregamento dos manifests com proteção contra falhas
  try {
    await AppRegistry.loadManifests();
  } catch (e) {
    debugPrint('Erro ao carregar manifests: $e');
  }

  runApp(const CraftLabApp());
}

class CraftLabApp extends StatefulWidget {
  const CraftLabApp({super.key});

  @override
  State<CraftLabApp> createState() => _CraftLabAppState();
}

class _CraftLabAppState extends State<CraftLabApp> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(_syncSystemUi);
    appPreferences.addListener(_onPrefsChanged);
    _syncSystemUi();
  }

  @override
  void dispose() {
    appTheme.removeListener(_syncSystemUi);
    appPreferences.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  void _syncSystemUi() {
    final isDark = appTheme.isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme(
      child: Builder(builder: (ctx) {
        final s = AppTheme.of(ctx);
        _syncSystemUi();

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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(appPreferences.textScaleFactor),
            ),
            child: ColoredBox(color: s.sheetBackdrop, child: child!),
          ),
          home: const AuthGate(),
        );
      }),
    );
  }
}

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

  bool _hasMessages = false;

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

  Widget _buildTab() {
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
  }

  static const Duration _drawerAnim = Duration(milliseconds: 320);
  static const Curve _drawerCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final _screenWidth = MediaQuery.of(context).size.width;
    final _drawerWidth = _screenWidth * 0.75;

    final bodyContent = Stack(children: [
      Positioned.fill(
        top: 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: kCupertinoOut,
          switchOutCurve: kCupertinoIn,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(key: const ValueKey('ai'), child: _buildTab()),
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
              title: '',
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
    ]);

    return RootShellNavigation(
      switchToEditTab: (type) {
        final screen = switch (type) {
          EditorType.docs   => const DocsScreen(),
          EditorType.sheets => const SheetsScreen(),
          EditorType.slides => const SlidesScreen(),
        };
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      },
      child: Scaffold(
        backgroundColor: s.surface,
        body: Stack(
          children: [
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

            AnimatedBuilder(
              animation: _drawerCtrl,
              builder: (_, __) {
                final t = _drawerCtrl.value;
                return Positioned.fill(
                  child: IgnorePointer(
                    ignoring: t < 0.01,
                    child: Container(
                      color: Colors.black.withOpacity(0.3 * t),
                    ),
                  ),
                );
              },
            ),

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
        bottom: 10, left: 16, right: 16,
      ),
      child: Row(children: [
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
            child: AppIcon('menu', color: s.onSurface, size: 20),
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