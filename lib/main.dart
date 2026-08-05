import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'widgets.dart';
import 'drawer.dart';
import 'nav_bar.dart';
import 'tabs.dart';
import 'sheets.dart';

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
          statusBarColor: Colors.transparent,
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
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF2F7BF6)),
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
          home: const RootShell(),
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

  int _tabIndex    = 0;
  EditorType _editorType = EditorType.docs;
  bool _hasMessages = false;

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
        .push(CupertinoPageRoute(builder: (_) => const SettingsPage()));
  }

  void _selectTab(int i) { if (i != _tabIndex) setState(() => _tabIndex = i); }
  void _setEditorType(EditorType t) => setState(() => _editorType = t);
  void _onMessageSent() { if (!_hasMessages) setState(() => _hasMessages = true); }

  void _openProjectsModal() {
    final s = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProjectsModal(s: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [

        // ── Conteúdo principal — SEM recoil/push ao abrir drawer
        ColoredBox(
          color: s.surface,
          child: Column(children: [
            _Header(
              s: s,
              hasMessages: _hasMessages,
              onMenu: _openDrawer,
              trailing: _tabIndex == 1
                  ? EditTypeButton(
                      s: s, current: _editorType, onSelect: _setEditorType)
                  : null,
            ),
            Expanded(
              child: TabSwitcher(index: _tabIndex, children: [
                ChatTab(onFirstMessage: _onMessageSent),
                EditTab(editorType: _editorType),
                const TemplatesTab(),
              ]),
            ),
          ]),
        ),

        // ── Bottom bar flutuante
        Positioned(
          bottom: 14,
          left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingNav(s: s, index: _tabIndex, onChanged: _selectTab),
                  ProjectsButton(s: s, onTap: _openProjectsModal),
                ],
              ),
            ),
          ),
        ),

        // ── Barrier
        if (_drawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDrawer,
              child: Container(color: s.barrier),
            ),
          ),

        // ── Drawer (spring slide lateral, conteúdo não se mexe)
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
              s: s, onClose: _closeDrawer, onSettings: _openSettings),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final AppColorScheme s;
  final bool hasMessages;
  final VoidCallback onMenu;
  final Widget? trailing;

  const _Header({
    required this.s,
    required this.hasMessages,
    required this.onMenu,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: s.surface,
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
          AnimatedOpacity(
            opacity: hasMessages ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: kCupertinoOut,
            child: Image.asset('assets/logo.png', height: 24, fit: BoxFit.contain),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// SETTINGS PAGE
// ══════════════════════════════════════════════════════════════

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              color: s.pageBackground,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(children: [
                AppTap(
                  onTap: () => Navigator.pop(context),
                  s: s,
                  child: AppIcon('back.svg', color: s.onSurface, size: 20),
                ),
                const SizedBox(width: 8),
                Text('Definições',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: s.onSurface)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Aparência',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: s.onSurfaceVariant,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: s.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: s.cardShadow),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Modo escuro',
                            style: TextStyle(fontSize: 15, color: s.onSurface)),
                        AppSwitch(
                          value: appTheme.isDark,
                          s: s,
                          onChanged: (_) => appTheme.toggleDark(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}