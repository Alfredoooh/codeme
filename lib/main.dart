import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// ─────────────────────────────────────────────────────────────
// web_editor_frame_conditional.dart  (ficheiro separado)
// export 'web_editor_frame_stub.dart'
//     if (dart.library.html) 'web_editor_frame.dart';
// ─────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  runApp(const CodeMeApp());
}

// ══════════════════════════════════════════════════════════════
// CORES — Tema claro: branco real, sem tons azulados de Material.
// Separação por sombra, não por cor de fundo de container.
// Tema escuro: base #1C1C1C, escala de cinzentos quentes.
// ══════════════════════════════════════════════════════════════

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  // Primária
  Color get primary      => isDark ? const Color(0xFF94BBFF) : const Color(0xFF2F7BF6);
  Color get onPrimary    => isDark ? const Color(0xFF003166) : const Color(0xFFFFFFFF);
  Color get primaryContainer    => isDark ? const Color(0xFF004591) : const Color(0xFFE8F0FF);
  Color get onPrimaryContainer  => isDark ? const Color(0xFFD3E4FF) : const Color(0xFF00204D);

  // Superfície — light é branco puro, sem tinting Material
  Color get surface      => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
  Color get onSurface    => isDark ? const Color(0xFFEDEDED) : const Color(0xFF111111);
  Color get onSurfaceVariant => isDark ? const Color(0xFFBBBBBB) : const Color(0xFF555555);

  // Containers — light usa branco com sombra, não tons azulados
  Color get surfaceContainer        => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);
  Color get surfaceContainerLow     => isDark ? const Color(0xFF242424) : const Color(0xFFFFFFFF);
  Color get surfaceContainerHigh    => isDark ? const Color(0xFF333333) : const Color(0xFFFFFFFF);
  Color get surfaceContainerHighest => isDark ? const Color(0xFF3D3D3D) : const Color(0xFFFFFFFF);

  // Fundo da página (por trás dos cards)
  Color get background   => isDark ? const Color(0xFF141414) : const Color(0xFFF4F4F4);

  // Outline
  Color get outline        => isDark ? const Color(0xFF666666) : const Color(0xFFCCCCCC);
  Color get outlineVariant => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);

  // Erro
  Color get error        => isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  Color get onError      => isDark ? const Color(0xFF690005) : const Color(0xFFFFFFFF);

  // Extras
  Color get scrim        => const Color(0xFF000000);
  Color get shadow       => const Color(0xFF000000);
  Color get barrier      => const Color(0x80000000);
  Color get hover        => isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000);
  Color get pressed      => isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000);

  // Sombra flutuante — light usa sombra real para separar sem cor
  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))]
      : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 2)),
         BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4,  offset: const Offset(0, 1))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 8))]
      : [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 6)),
         BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6,  offset: const Offset(0, 2))];
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER — InheritedNotifier garante rebuild instantâneo
// em toda a árvore no mesmo frame. Sem delay, sem segundo toque.
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  bool isDark = false;
  void toggleDark() { isDark = !isDark; notifyListeners(); }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

class AppTheme extends InheritedNotifier<AppThemeNotifier> {
  // SEM const — appTheme é global não-const, const aqui é erro de compilação.
  AppTheme({super.key, required super.child}) : super(notifier: appTheme);

  static AppColorScheme of(BuildContext context) {
    final n = context.dependOnInheritedWidgetOfExactType<AppTheme>()?.notifier;
    return AppColorScheme(n?.isDark ?? false);
  }
}

// ══════════════════════════════════════════════════════════════
// SPRING CONTROLLER — replica a física do nav-slide-animation.js
// stiffness=260, damping=28 para a tela que entra (slide front).
// stiffness=220, damping=26 para o recoil do conteúdo de trás.
// ══════════════════════════════════════════════════════════════

class SpringNav {
  final AnimationController slideCtrl;
  final AnimationController recoilCtrl;

  SpringNav({required TickerProvider vsync})
      : slideCtrl = AnimationController.unbounded(vsync: vsync),
        recoilCtrl = AnimationController.unbounded(vsync: vsync);

  static const _slideDesc  = SpringDescription(mass: 1, stiffness: 260, damping: 28);
  static const _recoilDesc = SpringDescription(mass: 1, stiffness: 220, damping: 26);

  void open() {
    slideCtrl.animateWith(SpringSimulation(_slideDesc,  slideCtrl.value,  0.0, 0));
    recoilCtrl.animateWith(SpringSimulation(_recoilDesc, recoilCtrl.value, 1.0, 0));
  }

  void close() {
    slideCtrl.animateWith(SpringSimulation(_slideDesc,  slideCtrl.value,  1.0, 0));
    recoilCtrl.animateWith(SpringSimulation(_recoilDesc, recoilCtrl.value, 0.0, 0));
  }

  void dispose() {
    slideCtrl.dispose();
    recoilCtrl.dispose();
  }
}

const Curve kSmooth = Cubic(0.16, 1.0, 0.3, 1.0);

// ══════════════════════════════════════════════════════════════
// MOCK DATA
// ══════════════════════════════════════════════════════════════

class ConversationItem {
  final String id, title, preview;
  const ConversationItem({required this.id, required this.title, required this.preview});
}

final List<ConversationItem> mockConversations = [];

// ══════════════════════════════════════════════════════════════
// APP ROOT
// ══════════════════════════════════════════════════════════════

class CodeMeApp extends StatelessWidget {
  const CodeMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTheme(
      child: Builder(builder: (ctx) {
        final s = AppTheme.of(ctx);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: s.surface,
          systemNavigationBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'CodeMe',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7BF6))),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7BF6), brightness: Brightness.dark)),
          themeMode: s.isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (_, child) => ColoredBox(color: s.surface, child: child),
          home: const RootShell(),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SVG ICON — usa assets locais para icons do app shell
// ══════════════════════════════════════════════════════════════

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  const AppIcon(this.asset, {super.key, this.size = 20, required this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/svg/$asset',
    width: size, height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

// Ícone PNG para os tipos de editor
class EditorTypeIcon extends StatelessWidget {
  final String asset;
  final double size;
  const EditorTypeIcon(this.asset, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/png/$asset',
    width: size, height: size,
    filterQuality: FilterQuality.medium,
  );
}

// Ícone Fluent via CDN para o toolbar
class FluentIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const FluentIcon(this.name, {super.key, this.size = 18, required this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.network(
    'https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/${name}/SVG/${name}_20_regular.svg',
    width: size, height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    placeholderBuilder: (_) => SizedBox(width: size, height: size),
  );
}

// ══════════════════════════════════════════════════════════════
// ROOT SHELL
// ══════════════════════════════════════════════════════════════

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with TickerProviderStateMixin {
  late final SpringNav _springNav;
  bool _drawerOpen = false;
  int _tabIndex = 0;
  EditorType _editorType = EditorType.docs;

  @override
  void initState() {
    super.initState();
    _springNav = SpringNav(vsync: this);
    _springNav.slideCtrl.value = 1.0; // começa fechado
  }

  @override
  void dispose() {
    _springNav.dispose();
    super.dispose();
  }

  void _openDrawer()  { setState(() => _drawerOpen = true);  _springNav.open(); }
  void _closeDrawer() { setState(() => _drawerOpen = false); _springNav.close(); }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SettingsPage(),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: kSmooth);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: child,
        );
      },
    ));
  }

  void _selectTab(int i) { if (i != _tabIndex) setState(() => _tabIndex = i); }
  void _setEditorType(EditorType t) => setState(() => _editorType = t);

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        // ── Conteúdo com recoil (escala + translação para a esquerda quando drawer abre)
        AnimatedBuilder(
          animation: _springNav.recoilCtrl,
          builder: (_, child) {
            final v = _springNav.recoilCtrl.value.clamp(0.0, 1.0);
            return Transform(
              transform: Matrix4.identity()
                ..translate(-8.0 * v * MediaQuery.of(context).size.width / 100)
                ..scale(1.0 - 0.02 * v),
              alignment: Alignment.centerLeft,
              child: child,
            );
          },
          child: ColoredBox(
            color: s.surface,
            child: Column(children: [
              _Header(s: s, title: _tabIndex == 0 ? 'CodeMe' : 'Editor',
                  onMenu: _openDrawer,
                  trailing: _tabIndex == 1
                      ? _EditTypeButton(s: s, current: _editorType, onSelect: _setEditorType)
                      : null),
              Expanded(child: _TabSwitcher(index: _tabIndex, children: [
                const _ChatTab(),
                _EditTab(editorType: _editorType),
              ])),
            ]),
          ),
        ),

        // ── Nav flutuante (pill)
        Positioned(
          left: 16, right: 16, bottom: 14,
          child: SafeArea(top: false,
              child: _FloatingNav(s: s, index: _tabIndex, onChanged: _selectTab)),
        ),

        // ── Barrier
        if (_drawerOpen)
          Positioned.fill(child: GestureDetector(
            onTap: _closeDrawer,
            child: Container(color: s.barrier),
          )),

        // ── Drawer com spring slide (replica createSlideTransition do JS)
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
          child: _Drawer(s: s, onClose: _closeDrawer, onSettings: _openSettings),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB SWITCHER — crossfade simples e rápido
// ══════════════════════════════════════════════════════════════

class _TabSwitcher extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const _TabSwitcher({required this.index, required this.children});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    switchInCurve: kSmooth,
    switchOutCurve: kSmooth,
    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
    child: KeyedSubtree(key: ValueKey(index), child: children[index]),
  );
}

// ══════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onMenu;
  final Widget? trailing;
  const _Header({required this.s, required this.title, required this.onMenu, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    color: s.surface,
    padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6, bottom: 10, left: 6, right: 10),
    child: Row(children: [
      _Tap(onTap: onMenu, s: s,
          child: AppIcon('menu.svg', color: s.onSurface, size: 20)),
      const SizedBox(width: 8),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: Text(title, key: ValueKey(title),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: s.onSurface)),
      ),
      const Spacer(),
      if (trailing != null) trailing!,
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// ICON TAP AREA
// ══════════════════════════════════════════════════════════════

class _Tap extends StatefulWidget {
  final VoidCallback onTap;
  final AppColorScheme s;
  final Widget child;
  final double size;
  const _Tap({super.key, required this.onTap, required this.s, required this.child, this.size = 36});

  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  bool _p = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _p = true),
    onTapCancel: () => setState(() => _p = false),
    onTapUp: (_) => setState(() => _p = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _p ? 0.88 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: kSmooth,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.size, height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? widget.s.pressed : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.size / 2),
        ),
        child: widget.child,
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// DRAWER
// ══════════════════════════════════════════════════════════════

class _Drawer extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  const _Drawer({required this.s, required this.onClose, required this.onSettings});

  @override
  Widget build(BuildContext context) => Container(
    color: s.surface,
    child: SafeArea(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(children: [
            Text('Conversas', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
            const Spacer(),
            _Tap(onTap: onClose, s: s, size: 32,
                child: AppIcon('close.svg', color: s.onSurfaceVariant, size: 14)),
          ]),
        ),
        Expanded(child: mockConversations.isEmpty
            ? Center(child: Text('Sem conversas ainda',
                style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: mockConversations.length,
                itemBuilder: (_, i) => _ConvTile(s: s, item: mockConversations[i]),
              )),
        Padding(
          padding: const EdgeInsets.all(10),
          child: _AccountPill(s: s, onTap: onSettings),
        ),
      ],
    )),
  );
}

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  const _ConvTile({required this.s, required this.item});
  @override State<_ConvTile> createState() => _ConvTileState();
}
class _ConvTileState extends State<_ConvTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _h = true),
    onTapCancel: () => setState(() => _h = false),
    onTapUp: (_) => setState(() => _h = false),
    onTap: () {},
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _h ? widget.s.hover : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.item.title,
            style: TextStyle(fontSize: 14, color: widget.s.onSurface),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(widget.item.preview,
            style: TextStyle(fontSize: 12, color: widget.s.onSurfaceVariant),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _AccountPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _AccountPill({required this.s, required this.onTap});
  @override State<_AccountPill> createState() => _AccountPillState();
}
class _AccountPillState extends State<_AccountPill> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _p = true),
    onTapCancel: () => setState(() => _p = false),
    onTapUp: (_) => setState(() => _p = false),
    onTap: widget.onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _p ? widget.s.hover : widget.s.hover.withOpacity(0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: widget.s.primary, shape: BoxShape.circle),
          child: Text('U', style: TextStyle(
              color: widget.s.onPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('Utilizador',
            style: TextStyle(fontSize: 14, color: widget.s.onSurface),
            overflow: TextOverflow.ellipsis)),
        AppIcon('settings.svg', color: widget.s.onSurfaceVariant, size: 16),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// FLOATING NAV (pill)
// ══════════════════════════════════════════════════════════════

class _FloatingNav extends StatelessWidget {
  final AppColorScheme s;
  final int index;
  final ValueChanged<int> onChanged;
  const _FloatingNav({required this.s, required this.index, required this.onChanged});

  static const _tabs = [
    (svg: 'ai_tab.svg', svgFilled: 'ai_tab_filled.svg', label: 'AI'),
    (svg: 'edit_tab.svg', svgFilled: 'edit_tab_filled.svg', label: 'Editar'),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      height: 62,
      decoration: BoxDecoration(
        color: s.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(999),
        boxShadow: s.floatingShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth / _tabs.length;
          return Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              left: w * index + 6, top: 8, bottom: 8, width: w - 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: s.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(children: List.generate(_tabs.length, (i) {
              final t = _tabs[i];
              final sel = index == i;
              final color = sel ? s.onPrimaryContainer : s.onSurfaceVariant;
              return Expanded(child: InkWell(
                onTap: () => onChanged(i),
                customBorder: const StadiumBorder(),
                child: SizedBox.expand(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: sel ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: AppIcon(sel ? t.svgFilled : t.svg, color: color, size: 20),
                    ),
                    const SizedBox(height: 2),
                    Text(t.label, style: TextStyle(
                        fontSize: 11, color: color,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  ],
                )),
              ));
            })),
          ]);
        }),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// CHAT TAB
// ══════════════════════════════════════════════════════════════

class _ChatTab extends StatefulWidget {
  const _ChatTab();
  @override State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _ctrl = TextEditingController();
  final List<String> _msgs = [];

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() { _msgs.add(t); _ctrl.clear(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final bottom = 64.0 + 10 + 62 + 14 + MediaQuery.of(context).padding.bottom;

    return Stack(children: [
      _msgs.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_rounded, size: 40, color: s.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Como posso ajudar?',
                  style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)),
            ]))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
              itemCount: _msgs.length,
              itemBuilder: (_, i) => _Bubble(s: s, text: _msgs[i]),
            ),
      Positioned(
        left: 16, right: 16,
        bottom: 14 + 62 + 10,
        child: SafeArea(top: false, bottom: false,
            child: _ChatInput(s: s, ctrl: _ctrl, onSend: _send)),
      ),
    ]);
  }
}

class _Bubble extends StatefulWidget {
  final AppColorScheme s;
  final String text;
  const _Bubble({required this.s, required this.text});
  @override State<_Bubble> createState() => _BubbleState();
}
class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale, _op;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _scale = Tween(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _c, curve: kSmooth));
    _op    = Tween(begin: 0.0,  end: 1.0).animate(CurvedAnimation(parent: _c,
        curve: const Interval(0, 0.45, curve: Curves.easeOut)));
    _c.forward();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Opacity(
      opacity: _op.value.clamp(0.0, 1.0),
      child: Transform.scale(scale: _scale.value, alignment: Alignment.centerRight, child: child),
    ),
    child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: widget.s.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: widget.s.cardShadow,
        ),
        child: Text(widget.text,
            style: TextStyle(color: widget.s.onPrimaryContainer, fontSize: 14)),
      ),
    ),
  );
}

class _ChatInput extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _ChatInput({required this.s, required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 58, maxHeight: 140),
    padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
    decoration: BoxDecoration(
      color: s.isDark ? const Color(0xFF2A2A2A) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      boxShadow: s.floatingShadow,
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: TextField(
          controller: ctrl,
          minLines: 1, maxLines: 5,
          style: TextStyle(fontSize: 14, color: s.onSurface),
          cursorColor: s.primary,
          decoration: InputDecoration(
            isDense: true, border: InputBorder.none,
            hintText: 'Escreva uma mensagem...',
            hintStyle: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
          ),
          onSubmitted: (_) => onSend(),
        ),
      )),
      const SizedBox(width: 6),
      _Tap(onTap: onSend, s: s, size: 44,
          child: Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: s.primary, shape: BoxShape.circle),
            child: AppIcon('send.svg', color: s.onPrimary, size: 16),
          )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// EDITOR TYPES
// ══════════════════════════════════════════════════════════════

enum EditorType { docs, sheets, slides, whiteboard }

extension EditorTypeX on EditorType {
  String get label => const {
    EditorType.docs: 'Documento',
    EditorType.sheets: 'Folha de cálculo',
    EditorType.slides: 'Apresentação',
    EditorType.whiteboard: 'Quadro branco',
  }[this]!;

  String get pngAsset => const {
    EditorType.docs: 'doc.png',
    EditorType.sheets: 'sheet.png',
    EditorType.slides: 'slide.png',
    EditorType.whiteboard: 'whiteboard.png',
  }[this]!;

  String get htmlAsset => const {
    EditorType.docs: 'assets/editor/docs.html',
    EditorType.sheets: 'assets/editor/sheets.html',
    EditorType.slides: 'assets/editor/slides.html',
    EditorType.whiteboard: 'assets/editor/whiteboard.html',
  }[this]!;
}

// ══════════════════════════════════════════════════════════════
// EDIT TAB — pré-carrega todos os WebViews via IndexedStack
// O toolbar flutua sobre o conteúdo sem nenhum container por baixo
// ══════════════════════════════════════════════════════════════

class _EditTab extends StatefulWidget {
  final EditorType editorType;
  const _EditTab({required this.editorType});
  @override State<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<_EditTab> {
  // Controllers para cada editor — pré-instanciados para carregamento antecipado
  final Map<EditorType, InAppWebViewController?> _controllers = {
    for (final t in EditorType.values) t: null,
  };

  void _runJs(String script) {
    _controllers[widget.editorType]?.evaluateJavascript(source: script);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final idx = EditorType.values.indexOf(widget.editorType);
    final navBottom = 62.0 + 14 + MediaQuery.of(context).padding.bottom;

    return Stack(children: [
      // IndexedStack mantém todos os 4 WebViews vivos e pré-carregados
      IndexedStack(
        index: idx,
        children: EditorType.values.map((t) => kIsWeb
            ? const SizedBox.shrink() // stub web — WebEditorFrame separado
            : InAppWebView(
                initialFile: t.htmlAsset,
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  javaScriptEnabled: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                ),
                onWebViewCreated: (c) => _controllers[t] = c,
              )
        ).toList(),
      ),

      // Toolbar flutuante — sem nenhum container por baixo, flutua mesmo
      Positioned(
        left: 16, right: 16,
        bottom: navBottom + 10,
        child: SafeArea(top: false, bottom: false,
            child: _EditorToolbar(s: s, type: widget.editorType, runJs: _runJs)),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// EDITOR TOOLBAR — flutua, sem container por baixo
// A seta seleciona a categoria e o toolbar muda os botões
// Ícones via Fluent Icons CDN
// ══════════════════════════════════════════════════════════════

class _EditorToolbar extends StatefulWidget {
  final AppColorScheme s;
  final EditorType type;
  final void Function(String) runJs;
  const _EditorToolbar({required this.s, required this.type, required this.runJs});
  @override State<_EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<_EditorToolbar> {
  int _catIndex = 0;

  List<_TbCategory> get _categories {
    switch (widget.type) {
      case EditorType.docs:
        return [
          _TbCategory(label: 'Base', buttons: [
            _TbBtn('text_bold',        'Negrito',     () => widget.runJs("editorApi.exec('bold')")),
            _TbBtn('text_italic',      'Itálico',     () => widget.runJs("editorApi.exec('italic')")),
            _TbBtn('text_underline',   'Sublinhado',  () => widget.runJs("editorApi.exec('underline')")),
            _TbBtn('text_strikethrough','Rasurado',   () => widget.runJs("editorApi.exec('strikethrough')")),
            _TbBtn('text_align_left',  'Esq',         () => widget.runJs("editorApi.exec('alignLeft')")),
            _TbBtn('text_align_center','Centro',      () => widget.runJs("editorApi.exec('alignCenter')")),
            _TbBtn('text_align_right', 'Dir',         () => widget.runJs("editorApi.exec('alignRight')")),
            _TbBtn('text_align_justify_low','Justif', () => widget.runJs("editorApi.exec('alignJustify')")),
            _TbBtn('text_bullet_list_ltr','Lista •',  () => widget.runJs("editorApi.exec('bulletList')")),
            _TbBtn('text_number_list_ltr','Lista 1.',  () => widget.runJs("editorApi.exec('numberedList')")),
            _TbBtn('arrow_undo',       'Desfazer',    () => widget.runJs("editorApi.exec('undo')")),
            _TbBtn('arrow_redo',       'Refazer',     () => widget.runJs("editorApi.exec('redo')")),
          ]),
          _TbCategory(label: 'Inserir', buttons: [
            _TbBtn('table_simple',     'Tabela 2×2',  () => widget.runJs("editorApi.insertTable(2,2)")),
            _TbBtn('table_simple',     'Tabela 3×3',  () => widget.runJs("editorApi.insertTable(3,3)")),
            _TbBtn('image_add',        'Imagem',      () {}),
            _TbBtn('link_add',         'Hiperligação',() => _linkDialog(context)),
          ]),
          _TbCategory(label: 'Layout', buttons: [
            _TbBtn('arrow_fit',        'Retrato',     () => widget.runJs("editorApi.setPageOrientation('portrait')")),
            _TbBtn('arrow_autofit_width','Paisagem',  () => widget.runJs("editorApi.setPageOrientation('landscape')")),
            _TbBtn('font_decrease',    'Fonte −',     () => widget.runJs("editorApi.setFontSize(12)")),
            _TbBtn('font_increase',    'Fonte +',     () => widget.runJs("editorApi.setFontSize(16)")),
          ]),
        ];

      case EditorType.sheets:
        return [
          _TbCategory(label: 'Base', buttons: [
            _TbBtn('text_bold',        'Negrito',     () => widget.runJs("editorApi.applyFormat('bold')")),
            _TbBtn('text_italic',      'Itálico',     () => widget.runJs("editorApi.applyFormat('italic')")),
            _TbBtn('text_underline',   'Sublinhado',  () => widget.runJs("editorApi.applyFormat('underline')")),
            _TbBtn('text_align_left',  'Esq',         () => widget.runJs("editorApi.setCellAlign('left')")),
            _TbBtn('text_align_center','Centro',      () => widget.runJs("editorApi.setCellAlign('center')")),
            _TbBtn('text_align_right', 'Dir',         () => widget.runJs("editorApi.setCellAlign('right')")),
          ]),
          _TbCategory(label: 'Células', buttons: [
            _TbBtn('table_insert_row', 'Nova linha',  () => widget.runJs("editorApi.insertRowBelow()")),
            _TbBtn('color_fill',       'Cor célula',  () => _colorDialog(context, 'fill')),
            _TbBtn('font_color',       'Cor texto',   () => _colorDialog(context, 'text')),
          ]),
          _TbCategory(label: 'Fórmulas', buttons: [
            _TbBtn('math_formula',     'SOMA',        () => _formulaDialog(context, 'SOMA')),
            _TbBtn('math_formula',     'MÉDIA',       () => _formulaDialog(context, 'MÉDIA')),
            _TbBtn('math_formula',     'SE',          () => _formulaDialog(context, 'SE')),
            _TbBtn('math_formula',     'SOMASE',      () => _formulaDialog(context, 'SOMASE')),
            _TbBtn('math_formula',     'PROCV',       () => _formulaDialog(context, 'PROCV')),
            _TbBtn('math_formula',     'CONCATENAR',  () => _formulaDialog(context, 'CONCATENAR')),
            _TbBtn('math_formula',     'MAX',         () => _formulaDialog(context, 'MAX')),
            _TbBtn('math_formula',     'MIN',         () => _formulaDialog(context, 'MIN')),
          ]),
          _TbCategory(label: 'Layout', buttons: [
            _TbBtn('table_freeze_column','Congelar',  () {}),
            _TbBtn('filter',           'Filtrar',     () {}),
          ]),
        ];

      case EditorType.slides:
        return [
          _TbCategory(label: 'Base', buttons: [
            _TbBtn('text_bold',        'Negrito',     () => widget.runJs("editorApi.applyTextFormat('bold')")),
            _TbBtn('text_italic',      'Itálico',     () => widget.runJs("editorApi.applyTextFormat('italic')")),
            _TbBtn('text_underline',   'Sublinhado',  () => widget.runJs("editorApi.applyTextFormat('underline')")),
          ]),
          _TbCategory(label: 'Inserir', buttons: [
            _TbBtn('slide_add',        'Novo slide',  () => widget.runJs("editorApi.addSlide()")),
            _TbBtn('text_add',         'Caixa texto', () => widget.runJs("editorApi.insertTextBox()")),
            _TbBtn('image_add',        'Imagem',      () {}),
            _TbBtn('rectangle',        'Retângulo',   () => widget.runJs("editorApi.insertShape('rect','#2F7BF6')")),
            _TbBtn('circle_hint',      'Círculo',     () => widget.runJs("editorApi.insertShape('circle','#2F7BF6')")),
          ]),
          _TbCategory(label: 'Slide', buttons: [
            _TbBtn('delete',           'Apagar slide',() => widget.runJs("editorApi.deleteCurrentSlide()")),
            _TbBtn('delete',           'Apagar elem.',() => widget.runJs("editorApi.deleteSelectedElement()")),
          ]),
        ];

      case EditorType.whiteboard:
        return [
          _TbCategory(label: 'Desenhar', buttons: [
            _TbBtn('pen',              'Caneta',      () => widget.runJs("editorApi.setTool('pen')")),
            _TbBtn('highlight',        'Marcador',    () => widget.runJs("editorApi.setTool('highlighter')")),
            _TbBtn('eraser',           'Borracha',    () => widget.runJs("editorApi.setTool('eraser')")),
          ]),
          _TbCategory(label: 'Traço', buttons: [
            _TbBtn('line_thickness',   '1px',         () => widget.runJs("editorApi.setStrokeWidth(1)")),
            _TbBtn('line_thickness',   '3px',         () => widget.runJs("editorApi.setStrokeWidth(3)")),
            _TbBtn('line_thickness',   '6px',         () => widget.runJs("editorApi.setStrokeWidth(6)")),
            _TbBtn('line_thickness',   '12px',        () => widget.runJs("editorApi.setStrokeWidth(12)")),
          ]),
          _TbCategory(label: 'Cor', buttons: [
            _TbBtn('color_line',       'Preto',       () => widget.runJs("editorApi.setColor('#000000')")),
            _TbBtn('color_line',       'Vermelho',    () => widget.runJs("editorApi.setColor('#FF0000')")),
            _TbBtn('color_line',       'Azul',        () => widget.runJs("editorApi.setColor('#2F7BF6')")),
            _TbBtn('color_line',       'Verde',       () => widget.runJs("editorApi.setColor('#00AA00')")),
            _TbBtn('color_line',       'Amarelo',     () => widget.runJs("editorApi.setColor('#FFD600')")),
            _TbBtn('color_line',       'Branco',      () => widget.runJs("editorApi.setColor('#FFFFFF')")),
          ]),
          _TbCategory(label: 'Quadro', buttons: [
            _TbBtn('arrow_undo',       'Desfazer',    () => widget.runJs("editorApi.undo()")),
            _TbBtn('arrow_reset',      'Centrar',     () => widget.runJs("editorApi.resetView()")),
            _TbBtn('delete',           'Limpar',      () => widget.runJs("editorApi.clearBoard()")),
          ]),
        ];
    }
  }

  void _linkDialog(BuildContext context) {
    final urlC = TextEditingController();
    final txtC = TextEditingController();
    final s = widget.s;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: s.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Inserir hiperligação', style: TextStyle(color: s.onSurface)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: urlC, style: TextStyle(color: s.onSurface),
            decoration: InputDecoration(hintText: 'https://',
                hintStyle: TextStyle(color: s.onSurfaceVariant))),
        TextField(controller: txtC, style: TextStyle(color: s.onSurface),
            decoration: InputDecoration(hintText: 'Texto (opcional)',
                hintStyle: TextStyle(color: s.onSurfaceVariant))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: s.onSurfaceVariant))),
        TextButton(onPressed: () {
          final url = urlC.text.trim();
          if (url.isNotEmpty) widget.runJs("editorApi.insertLink('$url','${txtC.text.trim()}')");
          Navigator.pop(ctx);
        }, child: Text('Inserir', style: TextStyle(color: s.primary))),
      ],
    ));
  }

  void _colorDialog(BuildContext context, String tipo) {
    final colors = ['#000000','#FFFFFF','#FF0000','#00AA00','#2F7BF6','#FF9900','#9900FF','#FFD600'];
    final s = widget.s;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: s.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(tipo == 'fill' ? 'Cor de preenchimento' : 'Cor do texto',
          style: TextStyle(color: s.onSurface)),
      content: Wrap(spacing: 10, runSpacing: 10, children: colors.map((hex) =>
          GestureDetector(
            onTap: () {
              tipo == 'fill'
                  ? widget.runJs("editorApi.setCellFill('$hex')")
                  : widget.runJs("editorApi.setCellColor('$hex')");
              Navigator.pop(ctx);
            },
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
                border: Border.all(color: s.outline),
              ),
            ),
          )).toList()),
    ));
  }

  void _formulaDialog(BuildContext context, String formula) {
    final c = TextEditingController(text: '=$formula(');
    final s = widget.s;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: s.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Fórmula $formula', style: TextStyle(color: s.onSurface)),
      content: TextField(controller: c, autofocus: true,
          style: TextStyle(color: s.onSurface, fontFamily: 'monospace')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: s.onSurfaceVariant))),
        TextButton(onPressed: () {
          widget.runJs("editorApi.applyFormula('${c.text}')");
          Navigator.pop(ctx);
        }, child: Text('Aplicar', style: TextStyle(color: s.primary))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final cats = _categories;
    // Garante que o índice não ultrapassa o número de categorias ao trocar de editor
    final safeIndex = _catIndex.clamp(0, cats.length - 1);
    final currentBtns = cats[safeIndex].buttons;

    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: s.isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: s.floatingShadow,
      ),
      child: Row(children: [
        const SizedBox(width: 4),

        // Seletor de categoria — abre popup com as categorias disponíveis
        _CatSelector(
          s: s,
          categories: cats,
          selectedIndex: safeIndex,
          onSelect: (i) => setState(() => _catIndex = i),
        ),

        // Divisor vertical
        Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4),
            color: s.outlineVariant),

        // Botões da categoria selecionada — scrolláveis horizontalmente
        Expanded(child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: currentBtns.length,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemBuilder: (_, i) => _TbIconBtn(s: s, btn: currentBtns[i]),
        )),

        const SizedBox(width: 4),
      ]),
    );
  }
}

class _TbCategory {
  final String label;
  final List<_TbBtn> buttons;
  const _TbCategory({required this.label, required this.buttons});
}

class _TbBtn {
  final String fluentName;
  final String tooltip;
  final VoidCallback onTap;
  const _TbBtn(this.fluentName, this.tooltip, this.onTap);
}

// Seletor de categoria — botão que abre popup com as categorias disponíveis
class _CatSelector extends StatefulWidget {
  final AppColorScheme s;
  final List<_TbCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _CatSelector({required this.s, required this.categories,
      required this.selectedIndex, required this.onSelect});
  @override State<_CatSelector> createState() => _CatSelectorState();
}

class _CatSelectorState extends State<_CatSelector> with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _overlay?.remove();
    super.dispose();
  }

  void _toggle() => _overlay == null ? _open() : _close();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    _animCtrl.forward(from: 0);

    _overlay = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      return Stack(children: [
        Positioned.fill(child: GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        )),
        Positioned(
          left: 16,
          bottom: MediaQuery.of(ctx).size.height - offset.dy + 8,
          child: AnimatedBuilder(
            animation: _animCtrl,
            builder: (_, child) => Opacity(
              opacity: CurvedAnimation(parent: _animCtrl,
                  curve: const Interval(0, 0.4, curve: Curves.easeOut)).value,
              child: Transform.scale(
                scale: Tween(begin: 0.88, end: 1.0)
                    .animate(CurvedAnimation(parent: _animCtrl, curve: kSmooth)).value,
                alignment: Alignment.bottomLeft,
                child: child,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: s.isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: s.floatingShadow,
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(widget.categories.length, (i) {
                  final cat = widget.categories[i];
                  final sel = widget.selectedIndex == i;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () { widget.onSelect(i); _close(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? s.primaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(cat.label, style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? s.onPrimaryContainer : s.onSurface,
                      )),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _close() {
    _animCtrl.reverse().then((_) {
      _overlay?.remove();
      _overlay = null;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final label = widget.categories[widget.selectedIndex].label;
    return _Tap(
      onTap: _toggle, s: s, size: 44,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: s.onSurface)),
        const SizedBox(width: 2),
        AnimatedRotation(
          turns: _overlay != null ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: kSmooth,
          child: Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: s.onSurfaceVariant),
        ),
        const SizedBox(width: 2),
      ]),
    );
  }
}

// Botão individual do toolbar com ícone Fluent via CDN
class _TbIconBtn extends StatefulWidget {
  final AppColorScheme s;
  final _TbBtn btn;
  const _TbIconBtn({required this.s, required this.btn});
  @override State<_TbIconBtn> createState() => _TbIconBtnState();
}

class _TbIconBtnState extends State<_TbIconBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.btn.tooltip,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.btn.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 40, height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? widget.s.pressed : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FluentIcon(widget.btn.fluentName, color: widget.s.onSurface, size: 18),
          if (widget.btn.tooltip.length <= 6) ...[
            const SizedBox(height: 1),
            Text(widget.btn.tooltip,
                style: TextStyle(fontSize: 8, color: widget.s.onSurfaceVariant),
                maxLines: 1),
          ],
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// EDIT TYPE BUTTON (header trailing)
// ══════════════════════════════════════════════════════════════

class _EditTypeButton extends StatefulWidget {
  final AppColorScheme s;
  final EditorType current;
  final ValueChanged<EditorType> onSelect;
  const _EditTypeButton({required this.s, required this.current, required this.onSelect});
  @override State<_EditTypeButton> createState() => _EditTypeButtonState();
}

class _EditTypeButtonState extends State<_EditTypeButton> with SingleTickerProviderStateMixin {
  OverlayEntry? _ov;
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
  }

  @override
  void dispose() { _ac.dispose(); _ov?.remove(); super.dispose(); }

  void _toggle() => _ov == null ? _open() : _close();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz  = box.size;
    _ac.forward(from: 0);

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      return Stack(children: [
        Positioned.fill(child: GestureDetector(
          onTap: _close, behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        )),
        Positioned(
          top: off.dy + sz.height + 6,
          right: MediaQuery.of(ctx).size.width - off.dx - sz.width,
          child: AnimatedBuilder(
            animation: _ac,
            builder: (_, child) => Opacity(
              opacity: CurvedAnimation(parent: _ac,
                  curve: const Interval(0, 0.4, curve: Curves.easeOut)).value,
              child: Transform.scale(
                scale: Tween(begin: 0.88, end: 1.0)
                    .animate(CurvedAnimation(parent: _ac, curve: kSmooth)).value,
                alignment: Alignment.topRight,
                child: child,
              ),
            ),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.floatingShadow,
              ),
              child: Column(mainAxisSize: MainAxisSize.min,
                  children: EditorType.values.map((t) => _TypeOption(
                    s: s, type: t,
                    selected: widget.current == t,
                    onTap: () { widget.onSelect(t); _close(); },
                  )).toList()),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_ov!);
    setState(() {});
  }

  void _close() {
    _ac.reverse().then((_) { _ov?.remove(); _ov = null; if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) => _Tap(
    onTap: _toggle, s: widget.s, size: 36,
    child: AppIcon('more_filled.svg', color: widget.s.onSurface, size: 20),
  );
}

class _TypeOption extends StatefulWidget {
  final AppColorScheme s;
  final EditorType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption({required this.s, required this.type, required this.selected, required this.onTap});
  @override State<_TypeOption> createState() => _TypeOptionState();
}

class _TypeOptionState extends State<_TypeOption> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _h = true),
    onTapCancel: () => setState(() => _h = false),
    onTapUp: (_) => setState(() => _h = false),
    onTap: widget.onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _h ? widget.s.hover
            : widget.selected ? widget.s.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(children: [
        EditorTypeIcon(widget.type.pngAsset, size: 18),
        const SizedBox(width: 10),
        Text(widget.type.label, style: TextStyle(
          fontSize: 14,
          color: widget.selected ? widget.s.primary : widget.s.onSurface,
          fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
        )),
      ]),
    ),
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
        color: s.surface,
        child: SafeArea(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: s.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(children: [
                _Tap(onTap: () => Navigator.pop(context), s: s,
                    child: Icon(Icons.arrow_back_rounded, color: s.onSurface, size: 20)),
                const SizedBox(width: 8),
                Text('Definições', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: s.onSurface)),
              ]),
            ),
            Expanded(child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Aparência', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: s.onSurfaceVariant)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: s.isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: s.cardShadow,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Modo escuro',
                          style: TextStyle(fontSize: 14, color: s.onSurface)),
                      _Switch(value: appTheme.isDark, s: s,
                          onChanged: (_) => appTheme.toggleDark()),
                    ],
                  ),
                ),
              ],
            )),
          ],
        )),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final bool value;
  final AppColorScheme s;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.value, required this.s, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: kSmooth,
      width: 46, height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? s.primary : s.outline,
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: value ? s.onPrimary : s.surface,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}