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
// ROOT SHELL — drawer manual via Stack + AnimationController.
// AppDrawer fica sempre montado, só desliza para fora de vista —
// nunca é destruído/recriado ao reabrir. Body é empurrado
// (Transform.translate) em vez de coberto — push nativo.
//
// FIX (tema instantâneo): _RootShellState agora usa ThemeReactive —
// regista appTheme.addListener no initState e chama setState sempre
// que o tema muda, independentemente de qualquer outra navegação ou
// interação. Antes disto, só um setState de outro motivo (mudar de
// tab, etc.) fazia o build() voltar a ler AppTheme.of(context) com o
// valor novo — por isso o tema só "pegava" ao navegar.
// ══════════════════════════════════════════════════════════════

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with SingleTickerProviderStateMixin, ThemeReactive<RootShell> {
  late final AnimationController _drawerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  AppTab     _tab        = AppTab.ai;
  EditorType _editorType = EditorType.docs;
  bool       _hasMessages = false;

  final GlobalKey<AiTabState> _aiTabKey = GlobalKey<AiTabState>();

  void _openDrawer()  => _drawerCtrl.animateTo(1.0, curve: kCupertinoOut);
  void _closeDrawer() => _drawerCtrl.animateTo(0.0, curve: kCupertinoOut);

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
        return EditTab(editorType: _editorType);
    }
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
  }

  static const double _drawerWidth = 300;

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
          ]);

    return Scaffold(
      backgroundColor: isAiTab ? s.pageBackground : s.surface,
      body: AnimatedBuilder(
        animation: _drawerCtrl,
        builder: (_, __) {
          final t = _drawerCtrl.value;
          return Stack(children: [
            Transform.translate(
              offset: Offset(_drawerWidth * t, 0),
              child: IgnorePointer(
                ignoring: t > 0.01,
                child: bodyContent,
              ),
            ),
            if (t > 0.01)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDrawer,
                  child: Container(color: s.barrier.withOpacity(0.35 * t)),
                ),
              ),
            Transform.translate(
              offset: Offset(_drawerWidth * (t - 1), 0),
              child: SizedBox(
                width: _drawerWidth,
                height: double.infinity,
                child: IgnorePointer(
                  ignoring: t < 0.99,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                    child: AppDrawer(
                      s: s,
                      onClose: _closeDrawer,
                      onSettings: _openSettings,
                      onGoHome: _goHome,
                      currentTab: _tab,
                      onSelectTab: _selectTab,
                      onOpenConversation: _onOpenConversation,
                      onNewChat: () => _onConversationAction(ConversationAction.newChat),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
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

// FIX (problema 3 — ícone de documento/canvas não aparecia): esta
// classe existia mas nunca era inserida na árvore de widgets, então
// AiTabHostNavigation.of(context) em aitab.dart devolvia sempre null,
// e a chamada a goToEditTab() era engolida silenciosamente pelo `?.`.
// Agora AiTabHost envolve o AiTab com AiTabHostNavigation de verdade,
// ligando goToEditTab à mesma navegação usada por onCanvasCreated.
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
    // Delega no mesmo caminho que onCanvasCreated já usava para abrir
    // o EditTab a partir de RootShell — precisa de um LocalCanvasItem
    // "vazio" só como sinal de navegação quando chamado diretamente
    // (ex: toque num _CanvasLink já existente, sem criar nada de novo).
    // Nesse caso o conteúdo real já foi carregado via
    // editTabController.requestLoadLocal(item) em _onOpenCanvas
    // (aitab.dart) ANTES desta chamada — aqui só trocamos de tab.
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

/// Ponte entre AiTabHost (que não tem acesso direto ao setState de
/// _RootShellState) e RootShell — usada por _onOpenCanvas (aitab.dart,
/// via AiTabHostNavigation) para trocar _tab para AppTab.edit depois
/// de editTabController.requestLoadLocal(item) já ter sido chamado.
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