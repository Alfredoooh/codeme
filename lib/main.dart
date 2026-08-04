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

// ── Root Shell (Drawer + Pages) ─────────────────────────────────────────────

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _selectedIndex = 0;
  bool _drawerOpen = false;

  static const List<_NavItem> _items = [
    _NavItem(icon: FluentIcons.home, label: 'Início'),
    _NavItem(icon: FluentIcons.settings, label: 'Definições'),
    _NavItem(icon: FluentIcons.info, label: 'Sobre'),
  ];

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _selectIndex(int index) {
    setState(() {
      _selectedIndex = index;
      _drawerOpen = false;
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        return const SettingsPage();
      case 2:
        return const AboutPage();
      default:
        return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        leading: IconButton(
          icon: const Icon(FluentIcons.global_nav_button, size: 20),
          onPressed: _openDrawer,
        ),
        title: Text(_items[_selectedIndex].label),
      ),
      content: Stack(
        children: [
          _buildPage(_selectedIndex),

          // Barrier
          if (_drawerOpen)
            GestureDetector(
              onTap: _closeDrawer,
              child: AnimatedOpacity(
                opacity: _drawerOpen ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ),

          // Drawer panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: _drawerOpen ? 0 : -260,
            width: 260,
            child: material.Material(
              type: material.MaterialType.transparency,
              child: Container(
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
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Text(
                          'CodeMe',
                          style: theme.typography.subtitle,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      for (int i = 0; i < _items.length; i++)
                        _DrawerTile(
                          item: _items[i],
                          selected: _selectedIndex == i,
                          onTap: () => _selectIndex(i),
                        ),
                      const Spacer(),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'v1.0.0',
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ),
                    ],
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _DrawerTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          final hovering = states.isHovered;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? theme.accentColor.withOpacity(0.15)
                  : hovering
                      ? theme.resources.subtleFillColorSecondary
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected
                      ? theme.accentColor
                      : theme.resources.textFillColorPrimary,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: theme.typography.body?.copyWith(
                    color: selected
                        ? theme.accentColor
                        : theme.resources.textFillColorPrimary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
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

// ── Pages ─────────────────────────────────────────────────────────────────────

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.home, size: 48, color: theme.accentColor),
          const SizedBox(height: 16),
          Text('Início', style: theme.typography.title),
          const SizedBox(height: 8),
          Text(
            'Conteúdo da página inicial.',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ListView(
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
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.info, size: 48, color: theme.accentColor),
          const SizedBox(height: 16),
          Text('CodeMe', style: theme.typography.title),
          const SizedBox(height: 8),
          Text(
            'Versão 1.0.0',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }
}