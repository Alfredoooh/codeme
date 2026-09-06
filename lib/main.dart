// ══════════════════════════════════════════════════════════════
// FILE: lib/main.dart
//
// MUDANÇA NESTA VERSÃO:
// _AppHeader (modo transparent) deixou de ter um Container único
// com opacidade fixa por trás do blur — isso criava a "linha" no
// fim do appbar. Agora o blur é aplicado ao Stack completo (fundo +
// conteúdo) e depois um ShaderMask com gradiente vertical
// (BlendMode.dstIn) reduz progressivamente a intensidade do
// BackdropFilter e da cor de fundo da appbar para baixo, fundindo
// suavemente com o corpo por trás sem nenhuma aresta percetível.
// ══════════════════════════════════════════════════════════════
/*import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/colors.dart';
import 'core/widgets/widgets.dart';
import 'core/navigation/app_page_route.dart';
import 'features/drawer/drawermenu.dart';
import 'features/aitab/aitab.dart';
import 'features/settings/settingsscreen.dart';
import 'features/apps/sheets/sheets.dart';
import 'services/auth_service.dart';
import 'features/auth/authscreens.dart';
import 'features/library/library_screen.dart';
import 'features/apps/app_types.dart';
import 'features/apps/registry/app_registry.dart';
import 'features/apps/docs/docs.dart';
import 'features/apps/sheets/sheets_app.dart';
import 'features/apps/slides/slides_app.dart';

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
          scrollBehavior: const AppScrollBehavior(),
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

  void _openDrawer() {
    FocusScope.of(context).unfocus();
    _drawerCtrl.animateTo(1.0, curve: _drawerCurve);
  }

  Future<void> _closeDrawer() =>
      _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);

  void _toggleDrawer() => _drawerOpen ? _closeDrawer() : _openDrawer();

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context)
        .push(AppPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openLibrary() {
    _closeDrawer();
    Navigator.of(context)
        .push(AppPageRoute(builder: (_) => const LibraryScreen()));
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
    final _drawerWidth = _screenWidth;

    final bodyContent = Stack(children: [
      Positioned.fill(
        top: 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
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
          EditorType.docs   => DocsScreen(),
          EditorType.sheets => SheetsScreen(),
          EditorType.slides => SlidesScreen(),
        };
        Navigator.of(context).push(AppPageRoute(builder: (_) => screen));
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeDrawer,
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
                      child: Container(
                        color: Colors.black.withOpacity(0.3 * t),
                      ),
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
                        onCloseAnimated: _closeDrawer,
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

class _LibraryButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _LibraryButton({required this.s, required this.onTap});
  @override
  State<_LibraryButton> createState() => _LibraryButtonState();
}

class _LibraryButtonState extends State<_LibraryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: widget.s.cardShadow,
        ),
        child: AppIcon('library', size: 18, color: widget.s.onSurface),
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

// ══════════════════════════════════════════════════════════════
// _AppHeader — modo transparent agora com fusão progressiva:
// ShaderMask (dstIn) aplica um gradiente vertical de alfa (1.0 no
// topo → 0.0 no fim) sobre TODO o conjunto blur+conteúdo+cor de
// fundo, incluindo o pixel final. Como não há nenhuma borda com
// opacidade "em degrau" — é uma única superfície com alfa contínuo
// — não existe aresta percetível entre o appbar e o corpo por trás.
// O blur em si (sigma) mantém-se constante ao longo do header,
// como pedido; só a MISTURA final é que se dissolve.
// ══════════════════════════════════════════════════════════════
class _AppHeader extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onMenu;
  final Widget? trailing;
  final Widget? leadingExtra;
  final bool transparent;
  final Color headerBackground;

  const _AppHeader({
    required this.s,
    required this.title,
    required this.onMenu,
    required this.headerBackground,
    this.trailing,
    this.leadingExtra,
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
        if (leadingExtra != null) ...[
          const SizedBox(width: 8),
          leadingExtra!,
        ],
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

    // Altura total da faixa do appbar (conteúdo + inset do topo),
    // usada para dimensionar o ShaderMask com precisão.
    final headerHeight = MediaQuery.of(context).padding.top + 6 + 40 + 10;

    return ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          // Gradiente de alfa: opaco nos primeiros ~65% da altura do
          // appbar, depois desvanece suavemente até ~0.08 (nunca 0
          // total, para não parecer que "corta" abruptamente) no
          // fim — é essa cauda longa e suave que elimina a linha.
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.62, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, headerHeight * 1.35));
        },
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: headerBackground.withOpacity(0.82),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}*/

import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CraftLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Conteúdo rolável
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 90, 20, 50),
            children: const [
              Text(
                'Texto deslizável',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                  height: 1.1,
                  color: Color(0xFF111111),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Este texto pode ser deslizado verticalmente pela tela. A AppBar permanece fixa enquanto o conteúdo passa por baixo dela.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 26),
              Text(
                'O efeito visual da AppBar utiliza um blur extremamente discreto, semelhante ao utilizado no seu código Flutter.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 30),
              _Card(text: 'O fundo da AppBar permanece predominantemente branco, com apenas uma pequena transparência para permitir que o conteúdo abaixo apareça de forma muito suave.'),
              SizedBox(height: 30),
              Text(
                'Continue deslizando para baixo para testar o comportamento da página. O conteúdo passa por trás da AppBar sem criar nenhuma linha ou borda.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 26),
              Text(
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer tincidunt velit vitae suscipit consequat.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 26),
              Text(
                'Suspendisse potenti. Donec tincidunt neque at tincidunt vulputate. Vestibulum ante ipsum primis in faucibus orci.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 30),
              _Card(text: 'Mais conteúdo para permitir testar o scroll vertical.'),
              SizedBox(height: 30),
              Text(
                'Curabitur non neque sed lorem elementum tincidunt. Integer aliquet justo sed lectus tincidunt.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 26),
              Text(
                'Sed vitae consequat nisl. Integer aliquet justo sed lectus tincidunt, vitae facilisis magna volutpat.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 26),
              Text(
                'O conteúdo continua normalmente até ao final da página.',
                style: TextStyle(fontSize: 18, height: 1.75, color: Color(0xFF4A4A4A)),
              ),
              SizedBox(height: 30),
              _Card(text: 'Fim do conteúdo.'),
            ],
          ),

          // AppBar com blur progressivo e sem linha divisória
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 70,
            child: IgnorePointer(
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                    child: Container(
                      color: Colors.white.withOpacity(0.7),
                    ),
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

class _Card extends StatelessWidget {
  final String text;
  const _Card({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, height: 1.65, color: Color(0xFF111111)),
      ),
    );
  }
}