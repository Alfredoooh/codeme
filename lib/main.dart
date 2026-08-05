import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'widgets.dart';
import 'drawermenu.dart';
import 'bottomtabbar.dart';
import 'aitab.dart';
import 'edittab.dart';
import 'templatestab.dart';
import 'projectstab.dart';
import 'settingsscreen.dart';
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

  AppTab     _tab        = AppTab.ai;
  EditorType _editorType = EditorType.docs;
  bool       _hasMessages = false;

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
    if (t != _tab) setState(() => _tab = t);
  }

  void _setEditorType(EditorType t) => setState(() => _editorType = t);
  void _onMessageSent() {
    if (!_hasMessages) setState(() => _hasMessages = true);
  }

  Widget _buildTab() {
    switch (_tab) {
      case AppTab.ai:
        return AiTab(onFirstMessage: _onMessageSent);
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

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [

        // ── Conteúdo principal
        ColoredBox(
          color: s.surface,
          child: Column(children: [
            _AppHeader(
              s: s,
              hasMessages: _hasMessages,
              onMenu: _openDrawer,
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

        // ── Bottom bar flutuante
        Positioned(
          bottom: 14, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BottomTabBar(
                s: s,
                current: _tab,
                onChanged: _selectTab,
              ),
            ),
          ),
        ),

        // ── Barrier drawer
        if (_drawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDrawer,
              child: Container(color: s.barrier),
            ),
          ),

        // ── Drawer spring lateral
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
// APP HEADER
// ══════════════════════════════════════════════════════════════

class _AppHeader extends StatelessWidget {
  final AppColorScheme s;
  final bool hasMessages;
  final VoidCallback onMenu;
  final Widget? trailing;

  const _AppHeader({
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