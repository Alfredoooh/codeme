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
          statusBarColor: s.surface,
          statusBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: s.surface,
          systemNavigationBarIconBrightness:
              s.isDark ? Brightness.light : Brightness.dark,
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

  final GlobalKey<State<AiTab>> _aiTabKey = GlobalKey<State<AiTab>>();

  @override
  void initState() {
    super.initState();
    _springNav = SpringNav(vsync: this);
    _springNav.slideCtrl.value = 1.0;
  }

  @override
  void dispose() { _springNav.dispose(); super.dispose(); }

  void _openDrawer()  { setState(() => _drawerOpen = true);  _springNav.open(); }
  void _closeDrawer() { setState(() => _drawerOpen = false); _springNav.close(); }

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
    // O AiConversationMenuButton fica no _AppHeader (fora da AiTab),
    // então propagamos a ação para o estado interno da AiTab via
    // rebuild com callback direto — a AiTab trata newChat/incognito/
    // rename/delete internamente através do seu próprio _onConversationAction,
    // que é injectado como callback do próprio widget abaixo.
    setState(() {
      _pendingConversationAction = action;
      if (action == ConversationAction.newChat || action == ConversationAction.incognito) {
        _hasMessages = action == ConversationAction.newChat ? false : _hasMessages;
      }
    });
  }

  // Chamado pelo AppDrawer quando o utilizador toca numa conversa:
  // troca para a tab AI (se necessário) e pede à AiTabHost para
  // carregar essa conversa específica.
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

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        // A tela AI usa o mesmo fundo (s.pageBackground) que a tela de
        // definições — item 6. As restantes tabs mantêm s.surface, que
        // é o fundo padrão do resto da app.
        ColoredBox(
          color: isAiTab ? s.pageBackground : s.surface,
          child: isAiTab
              // Header transparente sobreposto (mesmo padrão de gradiente
              // do settingsscreen.dart) apenas na tab de chat — o conteúdo
              // ocupa o ecrã todo por baixo. O gradiente parte agora de
              // s.pageBackground (em vez de s.surface) para combinar
              // exatamente com o fundo da própria AiTab por baixo.
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
                    child: _AppHeader(
                      s: s,
                      title: _tabTitle,
                      onMenu: _openDrawer,
                      transparent: true,
                      headerBackground: s.pageBackground,
                      trailing: AiConversationMenuButton(
                        s: s,
                        hasMessages: _hasMessages,
                        onSelect: _onConversationAction,
                        canvasCount: 0,
                        onOpenCanvas: () {},
                        webSearchEnabled: false,
                        onToggleWebSearch: (_) {},
                        widgetsEnabled: false,
                        onToggleWidgets: (_) {},
                      ),
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
              child: Container(color: s.barrier),
            ),
          ),

        AnimatedBuilder(
          animation: _springNav.slideCtrl,
          builder: (_, child) {
            final v = _springNav.slideCtrl.value.clamp(0.0, 1.0);
            return Positioned(
              top: 0, bottom: 0, width: 280,
              left: -280 + 280 * (1.0 - v),
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
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI TAB HOST — encapsula AiTab e escuta ações externas vindas do
// menu de conversa que fica no _AppHeader (fora da AiTab em si)
// ══════════════════════════════════════════════════════════════

class AiTabHost extends StatefulWidget {
  final VoidCallback onFirstMessage;
  final ConversationAction? externalAction;
  final VoidCallback onExternalActionConsumed;
  final String? initialConversationId;
  final VoidCallback? onConversationLoadConsumed;
  final ValueChanged<bool>? onHasMessagesChanged;
  const AiTabHost({
    super.key,
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
      onFirstMessage: widget.onFirstMessage,
      externalAction: widget.externalAction,
      onExternalActionConsumed: widget.onExternalActionConsumed,
      initialConversationId: widget.initialConversationId,
      onHasMessagesChanged: widget.onHasMessagesChanged,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APP HEADER — no modo transparente, o gradiente parte agora de
// `headerBackground` (passado pelo chamador) em vez de sempre
// s.surface, para que a AI tab combine com o mesmo fundo usado em
// settingsscreen.dart (s.pageBackground) — item 6.
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

    // Mesmo padrão do header sobreposto em settingsscreen.dart: gradiente
    // contínuo de opaco para transparente, sem blur — nunca sólido —
    // mas agora a partir de headerBackground em vez de s.surface fixo,
    // garantindo que combina com o fundo real por baixo em cada tab.
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