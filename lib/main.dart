import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const CodeMeApp());
}

// ── M3 Color Scheme ──────────────────────────────────────────────────────
// Seed: #2F7BF6 (azul accent original do projeto)
// Dark surface base: #1C1C1C — neutro quente, não azulado, não preto absoluto.
// Escala de containers sobe em luminosidade a partir daí para dar profundidade
// sem depender de bordas sólidas.

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  // Primary (azul, alto chroma)
  Color get primary => isDark ? const Color(0xFFA9C7FF) : const Color(0xFF2F7BF6);
  Color get onPrimary => isDark ? const Color(0xFF00325C) : const Color(0xFFFFFFFF);
  Color get primaryContainer => isDark ? const Color(0xFF00497E) : const Color(0xFFD8E2FF);
  Color get onPrimaryContainer => isDark ? const Color(0xFFD8E2FF) : const Color(0xFF001B3E);

  // Secondary
  Color get secondary => isDark ? const Color(0xFFBAC6E0) : const Color(0xFF565F71);
  Color get onSecondary => isDark ? const Color(0xFF283041) : const Color(0xFFFFFFFF);
  Color get secondaryContainer => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFDAE2F9);
  Color get onSecondaryContainer => isDark ? const Color(0xFFDAE2F9) : const Color(0xFF131C2B);

  // Tertiary (roxo-azulado, accent secundário)
  Color get tertiary => isDark ? const Color(0xFFD3BCE4) : const Color(0xFF6E5677);
  Color get onTertiary => isDark ? const Color(0xFF3D2947) : const Color(0xFFFFFFFF);
  Color get tertiaryContainer => isDark ? const Color(0xFF553F5F) : const Color(0xFFF4D9FF);
  Color get onTertiaryContainer => isDark ? const Color(0xFFF4D9FF) : const Color(0xFF271430);

  // Error
  Color get error => isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  Color get onError => isDark ? const Color(0xFF690005) : const Color(0xFFFFFFFF);
  Color get errorContainer => isDark ? const Color(0xFF93000A) : const Color(0xFFFFDAD6);
  Color get onErrorContainer => isDark ? const Color(0xFFFFDAD6) : const Color(0xFF410002);

  // Surface — base #1C1C1C no dark, neutra e quente
  Color get surface => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF9F9FF);
  Color get onSurface => isDark ? const Color(0xFFECECEC) : const Color(0xFF191C20);
  Color get surfaceVariant => isDark ? const Color(0xFF444444) : const Color(0xFFDFE2EB);
  Color get onSurfaceVariant => isDark ? const Color(0xFFC7C7C7) : const Color(0xFF43474E);

  // Surface containers — escala de luminosidade crescente a partir do #1C1C1C,
  // é isto que separa camadas visualmente em vez de bordas sólidas
  Color get surfaceContainerLowest => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  Color get surfaceContainerLow => isDark ? const Color(0xFF242424) : const Color(0xFFF3F3FA);
  Color get surfaceContainer => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEDEDF4);
  Color get surfaceContainerHigh => isDark ? const Color(0xFF343434) : const Color(0xFFE7E8EE);
  Color get surfaceContainerHighest => isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE2E2E9);

  Color get surfaceDim => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFD9D9E0);
  Color get surfaceBright => isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF9F9FF);

  // Outline — usado só para casos de contorno funcional (foco, inputs), não como divisor decorativo
  Color get outline => isDark ? const Color(0xFF8F8F8F) : const Color(0xFF73777F);
  Color get outlineVariant => isDark ? const Color(0xFF444444) : const Color(0xFFC3C6CF);

  // Inverse
  Color get inverseSurface => isDark ? const Color(0xFFE2E2E9) : const Color(0xFF2E3036);
  Color get onInverseSurface => isDark ? const Color(0xFF2E3036) : const Color(0xFFF0F0F7);
  Color get inversePrimary => isDark ? const Color(0xFF2F7BF6) : const Color(0xFFA9C7FF);

  Color get scrim => const Color(0xFF000000);
  Color get shadow => const Color(0xFF000000);

  Color get barrier => scrim.withOpacity(0.5);
  Color get hover => onSurface.withOpacity(isDark ? 0.08 : 0.06);
  Color get pressed => onSurface.withOpacity(isDark ? 0.12 : 0.10);

  // Sombra de elementos flutuantes (pill nav, pill input)
  List<BoxShadow> get floatingShadow => [
        BoxShadow(
          color: shadow.withOpacity(isDark ? 0.4 : 0.12),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

// ── Theme Notifier ────────────────────────────────────────────────────────

class AppThemeNotifier extends ChangeNotifier {
  bool isDark = false;

  void toggleDark() {
    isDark = !isDark;
    notifyListeners();
  }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

// ── Conversation Model (mock) ───────────────────────────────────────────────

class ConversationItem {
  final String id;
  final String title;
  final String preview;

  const ConversationItem({
    required this.id,
    required this.title,
    required this.preview,
  });
}

final List<ConversationItem> mockConversations = [];

// ── App Root ──────────────────────────────────────────────────────────────

class CodeMeApp extends StatefulWidget {
  const CodeMeApp({super.key});
  @override
  State<CodeMeApp> createState() => _CodeMeAppState();
}

class _CodeMeAppState extends State<CodeMeApp> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColorScheme(appTheme.isDark);

    return MaterialApp(
      title: 'CodeMe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const AppColorScheme(false).primary,
          onPrimary: const AppColorScheme(false).onPrimary,
          primaryContainer: const AppColorScheme(false).primaryContainer,
          onPrimaryContainer: const AppColorScheme(false).onPrimaryContainer,
          secondary: const AppColorScheme(false).secondary,
          onSecondary: const AppColorScheme(false).onSecondary,
          secondaryContainer: const AppColorScheme(false).secondaryContainer,
          onSecondaryContainer: const AppColorScheme(false).onSecondaryContainer,
          tertiary: const AppColorScheme(false).tertiary,
          onTertiary: const AppColorScheme(false).onTertiary,
          tertiaryContainer: const AppColorScheme(false).tertiaryContainer,
          onTertiaryContainer: const AppColorScheme(false).onTertiaryContainer,
          error: const AppColorScheme(false).error,
          onError: const AppColorScheme(false).onError,
          errorContainer: const AppColorScheme(false).errorContainer,
          onErrorContainer: const AppColorScheme(false).onErrorContainer,
          surface: const AppColorScheme(false).surface,
          onSurface: const AppColorScheme(false).onSurface,
          surfaceContainerHighest: const AppColorScheme(false).surfaceContainerHighest,
          onSurfaceVariant: const AppColorScheme(false).onSurfaceVariant,
          outline: const AppColorScheme(false).outline,
          outlineVariant: const AppColorScheme(false).outlineVariant,
          shadow: const AppColorScheme(false).shadow,
          scrim: const AppColorScheme(false).scrim,
          inverseSurface: const AppColorScheme(false).inverseSurface,
          onInverseSurface: const AppColorScheme(false).onInverseSurface,
          inversePrimary: const AppColorScheme(false).inversePrimary,
          surfaceTint: const AppColorScheme(false).primary,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: const AppColorScheme(true).primary,
          onPrimary: const AppColorScheme(true).onPrimary,
          primaryContainer: const AppColorScheme(true).primaryContainer,
          onPrimaryContainer: const AppColorScheme(true).onPrimaryContainer,
          secondary: const AppColorScheme(true).secondary,
          onSecondary: const AppColorScheme(true).onSecondary,
          secondaryContainer: const AppColorScheme(true).secondaryContainer,
          onSecondaryContainer: const AppColorScheme(true).onSecondaryContainer,
          tertiary: const AppColorScheme(true).tertiary,
          onTertiary: const AppColorScheme(true).onTertiary,
          tertiaryContainer: const AppColorScheme(true).tertiaryContainer,
          onTertiaryContainer: const AppColorScheme(true).onTertiaryContainer,
          error: const AppColorScheme(true).error,
          onError: const AppColorScheme(true).onError,
          errorContainer: const AppColorScheme(true).errorContainer,
          onErrorContainer: const AppColorScheme(true).onErrorContainer,
          surface: const AppColorScheme(true).surface,
          onSurface: const AppColorScheme(true).onSurface,
          surfaceContainerHighest: const AppColorScheme(true).surfaceContainerHighest,
          onSurfaceVariant: const AppColorScheme(true).onSurfaceVariant,
          outline: const AppColorScheme(true).outline,
          outlineVariant: const AppColorScheme(true).outlineVariant,
          shadow: const AppColorScheme(true).shadow,
          scrim: const AppColorScheme(true).scrim,
          inverseSurface: const AppColorScheme(true).inverseSurface,
          onInverseSurface: const AppColorScheme(true).onInverseSurface,
          inversePrimary: const AppColorScheme(true).inversePrimary,
          surfaceTint: const AppColorScheme(true).primary,
        ),
      ),
      themeMode: appTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: appTheme.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: scheme.surface,
          systemNavigationBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
        ));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: scheme.surface,
          child: child,
        );
      },
      home: const RootShell(),
    );
  }
}

// ── Reusable SVG Icon Helper ─────────────────────────────────────────────

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;

  const AppIcon(
    this.asset, {
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$asset',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

// ── Root Shell (Drawer + Bottom Tabs) ───────────────────────────────────

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _drawerOpen = false;
  int _tabIndex = 0; // 0 = AI, 1 = Edit
  EditorType _editorType = EditorType.docs;

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  void _setEditorType(EditorType type) {
    setState(() => _editorType = type);
  }

  String get _tabTitle => _tabIndex == 0 ? 'CodeMe' : 'Editor';

  @override
  Widget build(BuildContext context) {
    final scheme = AppColorScheme(appTheme.isDark);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Column(
            children: [
              _Header(
                scheme: scheme,
                title: _tabTitle,
                onMenuTap: _openDrawer,
                trailing: _tabIndex == 1
                    ? _EditActionsButton(
                        scheme: scheme,
                        current: _editorType,
                        onSelect: _setEditorType,
                      )
                    : null,
              ),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    const _ChatTab(),
                    _EditTab(editorType: _editorType),
                  ],
                ),
              ),
            ],
          ),

          // Nav flutuante — pill com bordas 100% curvas, sem borda sólida
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: _FloatingTabBar(
                scheme: scheme,
                currentIndex: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
          ),

          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDrawer,
                child: AnimatedOpacity(
                  opacity: _drawerOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: scheme.barrier),
                ),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: _drawerOpen ? 0 : -280,
            width: 280,
            child: _ConversationsDrawer(
              scheme: scheme,
              onClose: _closeDrawer,
              onOpenSettings: _openSettings,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AppColorScheme scheme;
  final String title;
  final VoidCallback onMenuTap;
  final Widget? trailing;

  const _Header({
    required this.scheme,
    required this.title,
    required this.onMenuTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, bottom: 10, left: 6, right: 10),
      color: scheme.surface,
      child: Row(
        children: [
          _IconTapArea(
            onTap: onMenuTap,
            scheme: scheme,
            child: AppIcon('menu.svg', color: scheme.onSurface, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Small tappable icon area with rounded hover/press feedback ─────────────

class _IconTapArea extends StatefulWidget {
  final VoidCallback onTap;
  final AppColorScheme scheme;
  final Widget child;
  final double size;

  const _IconTapArea({
    super.key,
    required this.onTap,
    required this.scheme,
    required this.child,
    this.size = 36,
  });

  @override
  State<_IconTapArea> createState() => _IconTapAreaState();
}

class _IconTapAreaState extends State<_IconTapArea> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed ? widget.scheme.pressed : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.size / 2),
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Drawer: Conversations list + account pill ───────────────────────────────

class _ConversationsDrawer extends StatelessWidget {
  final AppColorScheme scheme;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const _ConversationsDrawer({
    required this.scheme,
    required this.onClose,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Conversas',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _IconTapArea(
                    onTap: onClose,
                    scheme: scheme,
                    size: 32,
                    child: AppIcon('close.svg', color: scheme.onSurfaceVariant, size: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: mockConversations.isEmpty
                  ? _EmptyConversations(scheme: scheme)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: mockConversations.length,
                      itemBuilder: (context, i) {
                        return _ConversationTile(scheme: scheme, item: mockConversations[i]);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _AccountPill(scheme: scheme, onTap: onOpenSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  final AppColorScheme scheme;
  const _EmptyConversations({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('chat_empty.svg', color: scheme.onSurfaceVariant, size: 32),
            const SizedBox(height: 12),
            Text(
              'Sem conversas ainda',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final AppColorScheme scheme;
  final ConversationItem item;
  const _ConversationTile({required this.scheme, required this.item});

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hover = true),
        onTapCancel: () => setState(() => _hover = false),
        onTapUp: (_) => setState(() => _hover = false),
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? widget.scheme.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                style: TextStyle(fontSize: 14, color: widget.scheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.preview,
                style: TextStyle(fontSize: 12, color: widget.scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPill extends StatefulWidget {
  final AppColorScheme scheme;
  final VoidCallback onTap;
  const _AccountPill({required this.scheme, required this.onTap});

  @override
  State<_AccountPill> createState() => _AccountPillState();
}

class _AccountPillState extends State<_AccountPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _pressed ? widget.scheme.hover : widget.scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                'U',
                style: TextStyle(
                  color: widget.scheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Utilizador',
                style: TextStyle(fontSize: 14, color: widget.scheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppIcon('settings.svg', color: widget.scheme.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Floating Tab Bar — pill flutuante, bordas 100% curvas, sem borda sólida ──

class _FloatingTabBar extends StatelessWidget {
  final AppColorScheme scheme;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _FloatingTabBar({
    required this.scheme,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        boxShadow: scheme.floatingShadow,
      ),
      child: Row(
        children: [
          _FloatingTabItem(
            scheme: scheme,
            asset: 'ai_tab.svg',
            label: 'AI',
            selected: currentIndex == 0,
            onTap: () => onChanged(0),
          ),
          _FloatingTabItem(
            scheme: scheme,
            asset: 'edit_tab.svg',
            label: 'Editar',
            selected: currentIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _FloatingTabItem extends StatelessWidget {
  final AppColorScheme scheme;
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FloatingTabItem({
    required this.scheme,
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(asset, color: selected ? scheme.onPrimaryContainer : color, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? scheme.onPrimaryContainer : color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: AI Chat ───────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  const _ChatTab();

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColorScheme(appTheme.isDark);

    // Espaço reservado no fundo para: input flutuante (≈64) + gap (10) + nav flutuante (62) + margem (14) + safe area
    final bottomReserved = 64 + 10 + 62 + 14 + MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // Lista de mensagens — scrolla por baixo do input e do nav flutuantes
        _messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon('robot.svg', color: scheme.onSurfaceVariant, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Como posso ajudar?',
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomReserved),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _messages[i],
                        style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),

        // Input flutuante — pill própria, por cima do nav flutuante
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 + 62 + 10, // margem do nav + altura do nav + gap
          child: SafeArea(
            top: false,
            bottom: false,
            child: _FloatingChatInput(
              scheme: scheme,
              controller: _controller,
              onSend: _send,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingChatInput extends StatelessWidget {
  final AppColorScheme scheme;
  final TextEditingController controller;
  final VoidCallback onSend;

  const _FloatingChatInput({
    required this.scheme,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58, maxHeight: 140),
      padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        boxShadow: scheme.floatingShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(fontSize: 14, color: scheme.onSurface),
                cursorColor: scheme.primary,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Escreva uma mensagem...',
                  hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _IconTapArea(
            onTap: onSend,
            scheme: scheme,
            size: 44,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              child: AppIcon('send.svg', color: scheme.onPrimary, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Edit ───────────────────────────────────────────────────────────

enum EditorType { docs, sheets, slides, whiteboard }

class _EditTab extends StatelessWidget {
  final EditorType editorType;
  const _EditTab({required this.editorType});

  @override
  Widget build(BuildContext context) {
    if (editorType == EditorType.docs) {
      return const _DocumentEditorView();
    }
    return _EditorPlaceholder(editorType: editorType);
  }
}

class _DocumentEditorView extends StatefulWidget {
  const _DocumentEditorView();

  @override
  State<_DocumentEditorView> createState() => _DocumentEditorViewState();
}

class _DocumentEditorViewState extends State<_DocumentEditorView> {
  InAppWebViewController? _webController;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: 'assets/editor/index.html',
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        javaScriptEnabled: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (controller) {
        _webController = controller;
      },
    );
  }
}

class _EditorPlaceholder extends StatelessWidget {
  final EditorType editorType;
  const _EditorPlaceholder({required this.editorType});

  String get _label {
    switch (editorType) {
      case EditorType.docs:
        return 'Documento';
      case EditorType.sheets:
        return 'Folha de cálculo';
      case EditorType.slides:
        return 'Apresentação';
      case EditorType.whiteboard:
        return 'Quadro branco';
    }
  }

  String get _asset {
    switch (editorType) {
      case EditorType.docs:
        return 'doc.svg';
      case EditorType.sheets:
        return 'sheet.svg';
      case EditorType.slides:
        return 'slide.svg';
      case EditorType.whiteboard:
        return 'whiteboard.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColorScheme(appTheme.isDark);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(_asset, color: scheme.primary, size: 44),
          const SizedBox(height: 16),
          Text(
            _label,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Editor de $_label ainda por implementar.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Edit tab: top-right popup button ───────────────────────────────

class _EditActionsButton extends StatefulWidget {
  final AppColorScheme scheme;
  final EditorType current;
  final ValueChanged<EditorType> onSelect;

  const _EditActionsButton({
    required this.scheme,
    required this.current,
    required this.onSelect,
  });

  @override
  State<_EditActionsButton> createState() => _EditActionsButtonState();
}

class _EditActionsButtonState extends State<_EditActionsButton> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }
    _openMenu();
  }

  void _openMenu() {
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 6,
            right: MediaQuery.of(context).size.width - offset.dx - size.width,
            child: _EditPopupCard(
              scheme: widget.scheme,
              current: widget.current,
              onSelect: (type) {
                widget.onSelect(type);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _IconTapArea(
      key: _buttonKey,
      onTap: _toggleMenu,
      scheme: widget.scheme,
      child: AppIcon('add.svg', color: widget.scheme.onSurface, size: 20),
    );
  }
}

class _EditPopupCard extends StatelessWidget {
  final AppColorScheme scheme;
  final EditorType current;
  final ValueChanged<EditorType> onSelect;

  const _EditPopupCard({
    required this.scheme,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          boxShadow: scheme.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PopupOption(
              scheme: scheme,
              asset: 'doc.svg',
              label: 'Documento',
              selected: current == EditorType.docs,
              onTap: () => onSelect(EditorType.docs),
            ),
            _PopupOption(
              scheme: scheme,
              asset: 'sheet.svg',
              label: 'Folha de cálculo',
              selected: current == EditorType.sheets,
              onTap: () => onSelect(EditorType.sheets),
            ),
            _PopupOption(
              scheme: scheme,
              asset: 'slide.svg',
              label: 'Apresentação',
              selected: current == EditorType.slides,
              onTap: () => onSelect(EditorType.slides),
            ),
            _PopupOption(
              scheme: scheme,
              asset: 'whiteboard.svg',
              label: 'Quadro branco',
              selected: current == EditorType.whiteboard,
              onTap: () => onSelect(EditorType.whiteboard),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupOption extends StatefulWidget {
  final AppColorScheme scheme;
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PopupOption({
    required this.scheme,
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PopupOption> createState() => _PopupOptionState();
}

class _PopupOptionState extends State<_PopupOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.selected ? widget.scheme.primary : widget.scheme.onSurface;
    return GestureDetector(
      onTapDown: (_) => setState(() => _hover = true),
      onTapCancel: () => setState(() => _hover = false),
      onTapUp: (_) => setState(() => _hover = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _hover
              ? widget.scheme.hover
              : widget.selected
                  ? widget.scheme.primaryContainer.withOpacity(0.5)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            AppIcon(widget.asset, color: iconColor, size: 17),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                color: widget.selected ? widget.scheme.primary : widget.scheme.onSurface,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings Page ────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    appTheme.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = AppColorScheme(appTheme.isDark);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: scheme.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                color: scheme.surface,
                child: Row(
                  children: [
                    _IconTapArea(
                      onTap: () => Navigator.of(context).pop(),
                      scheme: scheme,
                      child: AppIcon('back.svg', color: scheme.onSurface, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Definições',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Aparência',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Modo escuro', style: TextStyle(fontSize: 14, color: scheme.onSurface)),
                          _CustomSwitch(
                            value: appTheme.isDark,
                            scheme: scheme,
                            onChanged: (_) => appTheme.toggleDark(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomSwitch extends StatelessWidget {
  final bool value;
  final AppColorScheme scheme;
  final ValueChanged<bool> onChanged;

  const _CustomSwitch({
    required this.value,
    required this.scheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? scheme.primary : scheme.outlineVariant,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? scheme.onPrimary : scheme.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}