import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const CodeMeApp());
}

// ── Theme Notifier ────────────────────────────────────────────────────────────

class AppThemeNotifier extends ChangeNotifier {
  bool isDark = false;
  AccentColor accent = Colors.blue;

  void toggleDark() {
    isDark = !isDark;
    notifyListeners();
  }

  void setAccent(AccentColor color) {
    accent = color;
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

// Lista mock vazia por agora — ligar a dados reais depois.
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
    final brightness = appTheme.isDark ? material.Brightness.dark : material.Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          appTheme.isDark ? material.Brightness.light : material.Brightness.dark,
      statusBarBrightness: brightness,
      systemNavigationBarColor:
          appTheme.isDark ? const Color(0xFF202020) : Colors.white,
      systemNavigationBarIconBrightness:
          appTheme.isDark ? material.Brightness.light : material.Brightness.dark,
    ));

    return ListenableBuilder(
      listenable: appTheme,
      builder: (context, _) => FluentApp(
        title: 'CodeMe',
        debugShowCheckedModeBanner: false,
        themeMode: appTheme.isDark ? ThemeMode.dark : ThemeMode.light,
        theme: FluentThemeData(
          accentColor: appTheme.accent,
          brightness: material.Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        darkTheme: FluentThemeData(
          accentColor: appTheme.accent,
          brightness: material.Brightness.dark,
          visualDensity: VisualDensity.standard,
        ),
        home: const RootShell(),
      ),
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

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context).push(
      FluentPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  String get _tabTitle => _tabIndex == 0 ? 'CodeMe' : 'Editor';

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      header: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.global_nav_button, size: 18),
              onPressed: _openDrawer,
            ),
            const SizedBox(width: 4),
            Text(
              _tabTitle,
              style: theme.typography.bodyStrong,
            ),
            const Spacer(),
            if (_tabIndex == 1) const _EditActionsButton(),
          ],
        ),
      ),
      content: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: const [
                    _ChatTab(),
                    _EditTab(),
                  ],
                ),
              ),
              _BottomTabBar(
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
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                  ),
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
            child: material.Material(
              type: material.MaterialType.transparency,
              child: _ConversationsDrawer(
                onClose: _closeDrawer,
                onOpenSettings: _openSettings,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drawer: Conversations list + account pill ───────────────────────────────

class _ConversationsDrawer extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const _ConversationsDrawer({
    required this.onClose,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        border: Border(
          right: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Conversas',
                    style: theme.typography.subtitle,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 14),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: mockConversations.isEmpty
                  ? _EmptyConversations(theme: theme)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: mockConversations.length,
                      itemBuilder: (context, i) {
                        final conv = mockConversations[i];
                        return _ConversationTile(item: conv);
                      },
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(10),
              child: HoverButton(
                onPressed: onOpenSettings,
                builder: (context, states) {
                  final hovering = states.isHovered;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: hovering
                          ? theme.resources.subtleFillColorSecondary
                          : theme.resources.subtleFillColorTransparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: theme.accentColor,
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
                            style: theme.typography.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          FluentIcons.settings,
                          size: 16,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  final FluentThemeData theme;
  const _EmptyConversations({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.chat,
              size: 32,
              color: theme.resources.textFillColorTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Sem conversas ainda',
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationItem item;
  const _ConversationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: HoverButton(
        onPressed: () {},
        builder: (context, states) {
          final hovering = states.isHovered;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hovering
                  ? theme.resources.subtleFillColorSecondary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.typography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.preview,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Bottom Tab Bar (custom, Fluent-styled) ──────────────────────────────────

class _BottomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BottomTabBar({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _BottomTabItem(
                icon: FluentIcons.robot,
                label: 'AI',
                selected: currentIndex == 0,
                onTap: () => onChanged(0),
              ),
              _BottomTabItem(
                icon: FluentIcons.edit,
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
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = selected
        ? theme.accentColor
        : theme.resources.textFillColorSecondary;

    return Expanded(
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          return Container(
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.typography.caption?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
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
    final theme = FluentTheme.of(context);

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.robot,
                        size: 40,
                        color: theme.resources.textFillColorTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Como posso ajudar?',
                        style: theme.typography.body?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _messages[i],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Input colado ao bottom tab bar (sem espaçamento extra abaixo)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: theme.micaBackgroundColor,
            border: Border(
              top: BorderSide(
                color: theme.resources.dividerStrokeColorDefault,
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _controller,
                  placeholder: 'Escreva uma mensagem...',
                  onSubmitted: (_) => _send(),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(FluentIcons.send, size: 18),
                onPressed: _send,
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

class _EditTab extends StatefulWidget {
  const _EditTab();

  @override
  State<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<_EditTab> {
  EditorType _current = EditorType.docs;

  String get _label {
    switch (_current) {
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

  IconData get _icon {
    switch (_current) {
      case EditorType.docs:
        return FluentIcons.text_document;
      case EditorType.sheets:
        return FluentIcons.excel_document;
      case EditorType.slides:
        return FluentIcons.power_point_document;
      case EditorType.whiteboard:
        return FluentIcons.edit_style;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, size: 48, color: theme.accentColor),
          const SizedBox(height: 16),
          Text(_label, style: theme.typography.title),
          const SizedBox(height: 8),
          Text(
            'Editor de $_label ainda por implementar.',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void setEditorType(EditorType type) {
    setState(() => _current = type);
  }
}

// ── Edit tab: top-right popup button (Flyout) ───────────────────────────────

class _EditActionsButton extends StatefulWidget {
  const _EditActionsButton();

  @override
  State<_EditActionsButton> createState() => _EditActionsButtonState();
}

class _EditActionsButtonState extends State<_EditActionsButton> {
  final FlyoutController _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _select(BuildContext context, EditorType type) {
    Flyout.of(context).close();
    final state = context.findAncestorStateOfType<_EditTabState>();
    state?.setEditorType(type);
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _flyoutController,
      child: IconButton(
        icon: const Icon(FluentIcons.add, size: 18),
        onPressed: () {
          _flyoutController.showFlyout(
            builder: (context) {
              return FlyoutContent(
                child: SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FlyoutOption(
                        icon: FluentIcons.text_document,
                        label: 'Documento',
                        onTap: () => _select(context, EditorType.docs),
                      ),
                      _FlyoutOption(
                        icon: FluentIcons.excel_document,
                        label: 'Folha de cálculo',
                        onTap: () => _select(context, EditorType.sheets),
                      ),
                      _FlyoutOption(
                        icon: FluentIcons.power_point_document,
                        label: 'Apresentação',
                        onTap: () => _select(context, EditorType.slides),
                      ),
                      _FlyoutOption(
                        icon: FluentIcons.edit_style,
                        label: 'Quadro branco',
                        onTap: () => _select(context, EditorType.whiteboard),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FlyoutOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FlyoutOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        final hovering = states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: hovering
                ? theme.resources.subtleFillColorSecondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.resources.textFillColorPrimary),
              const SizedBox(width: 12),
              Text(label, style: theme.typography.body),
            ],
          ),
        );
      },
    );
  }
}

// ── Settings Page ────────────────────────────────────────────────────────────

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage(
      header: PageHeader(
        leading: IconButton(
          icon: const Icon(FluentIcons.back, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Definições', style: theme.typography.bodyStrong),
      ),
      content: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Aparência', style: theme.typography.subtitle),
          const SizedBox(height: 12),
          Card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Modo escuro'),
                ToggleSwitch(
                  checked: appTheme.isDark,
                  onChanged: (_) => appTheme.toggleDark(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Cor de destaque', style: theme.typography.subtitle),
          const SizedBox(height: 12),
          Card(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Colors.blue,
                Colors.teal,
                Colors.purple,
                Colors.orange,
                Colors.red,
                Colors.green,
              ].map((c) {
                final selected = appTheme.accent == c;
                return GestureDetector(
                  onTap: () => appTheme.setAccent(c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: theme.resources.textFillColorPrimary,
                              width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}