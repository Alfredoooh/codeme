import 'package:flutter/material.dart' show WidgetsFlutterBinding;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

// ── Design Tokens ────────────────────────────────────────────────────────────

class AppColors {
  final bool isDark;
  const AppColors(this.isDark);

  Color get background => isDark ? const Color(0xFF0E0E10) : const Color(0xFFF7F7F8);
  Color get surface => isDark ? const Color(0xFF1A1A1D) : const Color(0xFFFFFFFF);
  Color get surfaceElevated => isDark ? const Color(0xFF232326) : const Color(0xFFFFFFFF);
  Color get border => isDark ? const Color(0xFF2C2C30) : const Color(0xFFE6E6E9);
  Color get textPrimary => isDark ? const Color(0xFFF2F2F3) : const Color(0xFF17171A);
  Color get textSecondary => isDark ? const Color(0xFF9A9AA1) : const Color(0xFF6B6B72);
  Color get textTertiary => isDark ? const Color(0xFF5C5C63) : const Color(0xFFAFAFB5);
  Color get accent => const Color(0xFF2F7BF6);
  Color get accentOn => const Color(0xFFFFFFFF);
  Color get barrier => Colors.black.withOpacity(0.4);
  Color get hover => isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
}

// ── Theme Notifier ────────────────────────────────────────────────────────────

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

// ── App Root ──────────────────────────────────────────────────────────────────

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
    final colors = AppColors(appTheme.isDark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: appTheme.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: colors.background,
      systemNavigationBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
    ));

    return WidgetsApp(
      title: 'CodeMe',
      color: colors.accent,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: colors.background,
        child: DefaultTextStyle(
          style: TextStyle(color: colors.textPrimary, fontSize: 15),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const RootShell(),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => builder(context),
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
}

// ── Reusable SVG Icon Helper ─────────────────────────────────────────────────

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

// ── Root Shell (Drawer + Bottom Tabs) ───────────────────────────────────────

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _drawerOpen = false;
  int _tabIndex = 0; // 0 = AI, 1 = Edit
  EditorType _editorType = EditorType.docs; // sempre ativo em Documento por defeito

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
    final colors = AppColors(appTheme.isDark);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Column(
            children: [
              _Header(
                colors: colors,
                title: _tabTitle,
                onMenuTap: _openDrawer,
                trailing: _tabIndex == 1
                    ? _EditActionsButton(
                        colors: colors,
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
              _BottomTabBar(
                colors: colors,
                currentIndex: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ],
          ),

          // Barrier
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDrawer,
                child: AnimatedOpacity(
                  opacity: _drawerOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: colors.barrier),
                ),
              ),
            ),

          // Drawer panel — over everything, full height
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: _drawerOpen ? 0 : -280,
            width: 280,
            child: _ConversationsDrawer(
              colors: colors,
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
  final AppColors colors;
  final String title;
  final VoidCallback onMenuTap;
  final Widget? trailing;

  const _Header({
    required this.colors,
    required this.title,
    required this.onMenuTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, bottom: 10, left: 6, right: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          _IconTapArea(
            onTap: onMenuTap,
            colors: colors,
            child: AppIcon('menu.svg', color: colors.textPrimary, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
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
  final AppColors colors;
  final Widget child;
  final double size;

  const _IconTapArea({
    required this.onTap,
    required this.colors,
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
          color: _pressed ? widget.colors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.size / 2),
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Drawer: Conversations list + account pill ───────────────────────────────

class _ConversationsDrawer extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const _ConversationsDrawer({
    required this.colors,
    required this.onClose,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border, width: 1)),
      ),
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
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _IconTapArea(
                    onTap: onClose,
                    colors: colors,
                    size: 32,
                    child: AppIcon('close.svg', color: colors.textSecondary, size: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: mockConversations.isEmpty
                  ? _EmptyConversations(colors: colors)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: mockConversations.length,
                      itemBuilder: (context, i) {
                        return _ConversationTile(colors: colors, item: mockConversations[i]);
                      },
                    ),
            ),
            Container(height: 1, color: colors.border, margin: const EdgeInsets.symmetric(horizontal: 12)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _AccountPill(colors: colors, onTap: onOpenSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  final AppColors colors;
  const _EmptyConversations({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('chat_empty.svg', color: colors.textTertiary, size: 32),
            const SizedBox(height: 12),
            Text(
              'Sem conversas ainda',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final AppColors colors;
  final ConversationItem item;
  const _ConversationTile({required this.colors, required this.item});

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
            color: _hover ? widget.colors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                style: TextStyle(fontSize: 14, color: widget.colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.preview,
                style: TextStyle(fontSize: 12, color: widget.colors.textSecondary),
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
  final AppColors colors;
  final VoidCallback onTap;
  const _AccountPill({required this.colors, required this.onTap});

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
          color: _pressed ? widget.colors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.colors.accent,
                shape: BoxShape.circle,
              ),
              child: const Text(
                'U',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Utilizador',
                style: TextStyle(fontSize: 14, color: widget.colors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppIcon('settings.svg', color: widget.colors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Tab Bar ───────────────────────────────────────────────────────

class _BottomTabBar extends StatelessWidget {
  final AppColors colors;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BottomTabBar({
    required this.colors,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              _BottomTabItem(
                colors: colors,
                asset: 'ai_tab.svg',
                label: 'AI',
                selected: currentIndex == 0,
                onTap: () => onChanged(0),
              ),
              _BottomTabItem(
                colors: colors,
                asset: 'edit_tab.svg',
                label: 'Editar',
                selected: currentIndex == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  final AppColors colors;
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomTabItem({
    required this.colors,
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? colors.accent : colors.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(asset, color: color, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: AI Chat ───────────────────────────────────────────────────────────

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
    final colors = AppColors(appTheme.isDark);

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon('robot.svg', color: colors.textTertiary, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Como posso ajudar?',
                        style: TextStyle(fontSize: 14, color: colors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _messages[i],
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Input colado ao bottom tab bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                    cursorColor: colors.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Escreva uma mensagem...',
                      hintStyle: TextStyle(fontSize: 14, color: colors.textTertiary),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconTapArea(
                onTap: _send,
                colors: colors,
                size: 40,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                  child: AppIcon('send.svg', color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ],
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
    // Só o Documento tem editor real (WebView com o HTML A4).
    // As outras opções mostram um placeholder até serem implementadas.
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
    final colors = AppColors(appTheme.isDark);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(_asset, color: colors.accent, size: 44),
          const SizedBox(height: 16),
          Text(
            _label,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Editor de $_label ainda por implementar.',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Edit tab: top-right popup button ───────────────────────────────

class _EditActionsButton extends StatefulWidget {
  final AppColors colors;
  final EditorType current;
  final ValueChanged<EditorType> onSelect;

  const _EditActionsButton({
    required this.colors,
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
              colors: widget.colors,
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
      colors: widget.colors,
      child: AppIcon('add.svg', color: widget.colors.textPrimary, size: 20),
    );
  }
}

class _EditPopupCard extends StatelessWidget {
  final AppColors colors;
  final EditorType current;
  final ValueChanged<EditorType> onSelect;

  const _EditPopupCard({
    required this.colors,
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
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PopupOption(
              colors: colors,
              asset: 'doc.svg',
              label: 'Documento',
              selected: current == EditorType.docs,
              onTap: () => onSelect(EditorType.docs),
            ),
            _PopupOption(
              colors: colors,
              asset: 'sheet.svg',
              label: 'Folha de cálculo',
              selected: current == EditorType.sheets,
              onTap: () => onSelect(EditorType.sheets),
            ),
            _PopupOption(
              colors: colors,
              asset: 'slide.svg',
              label: 'Apresentação',
              selected: current == EditorType.slides,
              onTap: () => onSelect(EditorType.slides),
            ),
            _PopupOption(
              colors: colors,
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
  final AppColors colors;
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PopupOption({
    required this.colors,
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
    final iconColor = widget.selected ? widget.colors.accent : widget.colors.textPrimary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _hover = true),
      onTapCancel: () => setState(() => _hover = false),
      onTapUp: (_) => setState(() => _hover = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _hover
              ? widget.colors.hover
              : widget.selected
                  ? widget.colors.accent.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            AppIcon(widget.asset, color: iconColor, size: 17),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                color: widget.selected ? widget.colors.accent : widget.colors.textPrimary,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings Page ────────────────────────────────────────────────────────────

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
    final colors = AppColors(appTheme.isDark);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: colors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(bottom: BorderSide(color: colors.border, width: 1)),
                ),
                child: Row(
                  children: [
                    _IconTapArea(
                      onTap: () => Navigator.of(context).pop(),
                      colors: colors,
                      child: AppIcon('back.svg', color: colors.textPrimary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Definições',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Modo escuro', style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                          _CustomSwitch(
                            value: appTheme.isDark,
                            colors: colors,
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
  final AppColors colors;
  final ValueChanged<bool> onChanged;

  const _CustomSwitch({
    required this.value,
    required this.colors,
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
          color: value ? colors.accent : colors.border,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}