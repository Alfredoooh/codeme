import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
// CORES
// ══════════════════════════════════════════════════════════════

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  Color get primary             => isDark ? const Color(0xFF94BBFF) : const Color(0xFF2F7BF6);
  Color get onPrimary           => isDark ? const Color(0xFF003166) : const Color(0xFFFFFFFF);
  Color get primaryContainer    => isDark ? const Color(0xFF004591) : const Color(0xFFE8F0FF);
  Color get onPrimaryContainer  => isDark ? const Color(0xFFD3E4FF) : const Color(0xFF00204D);

  Color get surface      => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
  Color get onSurface    => isDark ? const Color(0xFFEDEDED) : const Color(0xFF111111);
  Color get onSurfaceVariant => isDark ? const Color(0xFFBBBBBB) : const Color(0xFF555555);

  // Cards no dark têm contraste real com o fundo
  Color get cardBackground => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get pageBackground => isDark ? const Color(0xFF141414) : const Color(0xFFF2F2F7);

  Color get surfaceContainerHigh    => isDark ? const Color(0xFF333333) : const Color(0xFFFFFFFF);

  Color get outline        => isDark ? const Color(0xFF48484A) : const Color(0xFFCCCCCC);
  Color get outlineVariant => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);

  Color get error   => isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  Color get barrier => const Color(0x80000000);
  Color get hover   => isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000);
  Color get pressed => isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 4))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 2)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 28, offset: const Offset(0, 8))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.11), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ];
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  bool isDark = false;
  void toggleDark() {
    isDark = !isDark;
    notifyListeners();
  }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

class AppTheme extends InheritedNotifier<AppThemeNotifier> {
  AppTheme({super.key, required super.child}) : super(notifier: appTheme);

  static AppColorScheme of(BuildContext context) {
    final n = context.dependOnInheritedWidgetOfExactType<AppTheme>()?.notifier;
    return AppColorScheme(n?.isDark ?? false);
  }
}

// ══════════════════════════════════════════════════════════════
// SPRING NAV
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
    slideCtrl.animateWith(SpringSimulation(_slideDesc, slideCtrl.value, 0.0, 0));
    recoilCtrl.animateWith(SpringSimulation(_recoilDesc, recoilCtrl.value, 1.0, 0));
  }

  void close() {
    slideCtrl.animateWith(SpringSimulation(_slideDesc, slideCtrl.value, 1.0, 0));
    recoilCtrl.animateWith(SpringSimulation(_recoilDesc, recoilCtrl.value, 0.0, 0));
  }

  void dispose() {
    slideCtrl.dispose();
    recoilCtrl.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
// CURVA CUPERTINO
// ══════════════════════════════════════════════════════════════
const Curve kCupertino = Cubic(0.25, 0.1, 0.25, 1.0);
// Para entradas (mais snappy, estilo iOS push)
const Curve kCupertinoIn = Cubic(0.42, 0.0, 1.0, 1.0);
// Para saídas
const Curve kCupertinoOut = Cubic(0.0, 0.0, 0.58, 1.0);

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
          systemNavigationBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
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
          builder: (_, child) => ColoredBox(color: s.surface, child: child),
          home: const RootShell(),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ÍCONES
// ══════════════════════════════════════════════════════════════

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  const AppIcon(this.asset, {super.key, this.size = 20, required this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/svg/$asset',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

class EditorTypeIcon extends StatelessWidget {
  final String asset;
  final double size;
  const EditorTypeIcon(this.asset, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/icons/png/$asset',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
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

  // Rastreia se já existe alguma conversa iniciada
  bool _hasMessages = false;

  @override
  void initState() {
    super.initState();
    _springNav = SpringNav(vsync: this);
    _springNav.slideCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _springNav.dispose();
    super.dispose();
  }

  void _openDrawer() {
    setState(() => _drawerOpen = true);
    _springNav.open();
  }

  void _closeDrawer() {
    setState(() => _drawerOpen = false);
    _springNav.close();
  }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const SettingsPage(),
    ));
  }

  void _selectTab(int i) {
    if (i != _tabIndex) setState(() => _tabIndex = i);
  }

  void _setEditorType(EditorType t) => setState(() => _editorType = t);

  void _onMessageSent() {
    if (!_hasMessages) setState(() => _hasMessages = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
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
              _Header(
                s: s,
                hasMessages: _hasMessages,
                onMenu: _openDrawer,
                trailing: _tabIndex == 1
                    ? _EditTypeButton(s: s, current: _editorType, onSelect: _setEditorType)
                    : null,
              ),
              Expanded(
                child: _TabSwitcher(index: _tabIndex, children: [
                  _ChatTab(onFirstMessage: _onMessageSent),
                  _EditTab(editorType: _editorType),
                ]),
              ),
            ]),
          ),
        ),

        // Floating Nav — mais curto, centralizado
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Center(
              child: _FloatingNav(s: s, index: _tabIndex, onChanged: _selectTab),
            ),
          ),
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
              top: 0,
              bottom: 0,
              width: 280,
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
// TAB SWITCHER — animação Cupertino fade
// ══════════════════════════════════════════════════════════════

class _TabSwitcher extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const _TabSwitcher({required this.index, required this.children});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: kCupertinoOut,
        switchOutCurve: kCupertinoIn,
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(index), child: children[index]),
      );
}

// ══════════════════════════════════════════════════════════════
// HEADER — sem título, logo aparece só após primeira mensagem
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
          bottom: 10,
          left: 6,
          right: 10,
        ),
        child: Row(children: [
          _Tap(
            onTap: onMenu,
            s: s,
            child: AppIcon('menu.svg', color: s.onSurface, size: 20),
          ),
          const SizedBox(width: 8),
          // Logo aparece no appbar somente após primeira mensagem
          AnimatedOpacity(
            opacity: hasMessages ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: kCupertinoOut,
            child: Image.asset(
              'assets/logo.png',
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// TAP AREA
// ══════════════════════════════════════════════════════════════

class _Tap extends StatefulWidget {
  final VoidCallback onTap;
  final AppColorScheme s;
  final Widget child;
  final double size;

  const _Tap({
    super.key,
    required this.onTap,
    required this.s,
    required this.child,
    this.size = 36,
  });

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
          duration: const Duration(milliseconds: 100),
          curve: kCupertinoOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.size,
            height: widget.size,
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(children: [
                  Text('Conversas',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: s.onSurface)),
                  const Spacer(),
                  _Tap(
                    onTap: onClose,
                    s: s,
                    size: 32,
                    child: AppIcon('close.svg', color: s.onSurfaceVariant, size: 14),
                  ),
                ]),
              ),
              Expanded(
                child: mockConversations.isEmpty
                    ? Center(
                        child: Text('Sem conversas ainda',
                            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: mockConversations.length,
                        itemBuilder: (_, i) => _ConvTile(s: s, item: mockConversations[i]),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: _AccountPill(s: s, onTap: onSettings),
              ),
            ],
          ),
        ),
      );
}

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  const _ConvTile({required this.s, required this.item});
  @override
  State<_ConvTile> createState() => _ConvTileState();
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
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.item.title,
                style: TextStyle(fontSize: 14, color: widget.s.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(widget.item.preview,
                style: TextStyle(fontSize: 12, color: widget.s.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

class _AccountPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _AccountPill({required this.s, required this.onTap});
  @override
  State<_AccountPill> createState() => _AccountPillState();
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
            color: _p ? widget.s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: widget.s.primary, shape: BoxShape.circle),
              child: Text('U',
                  style: TextStyle(
                      color: widget.s.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Utilizador',
                    style: TextStyle(fontSize: 14, color: widget.s.onSurface),
                    overflow: TextOverflow.ellipsis)),
            AppIcon('settings.svg', color: widget.s.onSurfaceVariant, size: 16),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// FLOATING NAV — apenas ícones, mais compacto
// ══════════════════════════════════════════════════════════════

class _FloatingNav extends StatelessWidget {
  final AppColorScheme s;
  final int index;
  final ValueChanged<int> onChanged;

  const _FloatingNav({required this.s, required this.index, required this.onChanged});

  static const _tabs = [
    (svg: 'ai_tab.svg', svgFilled: 'ai_tab_filled.svg'),
    (svg: 'edit_tab.svg', svgFilled: 'edit_tab_filled.svg'),
  ];

  // Largura fixa — não ocupa a tela toda
  static const double _navWidth = 120.0;
  static const double _navHeight = 50.0;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          width: _navWidth,
          height: _navHeight,
          decoration: BoxDecoration(
            color: s.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(999),
            boxShadow: s.floatingShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(children: [
              // Indicador animado
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: kCupertinoOut,
                left: (_navWidth / _tabs.length) * index + 5,
                top: 5,
                bottom: 5,
                width: (_navWidth / _tabs.length) - 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: s.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: List.generate(_tabs.length, (i) {
                  final t = _tabs[i];
                  final sel = index == i;
                  final color = sel ? s.onPrimaryContainer : s.onSurfaceVariant;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedScale(
                          scale: sel ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 260),
                          curve: kCupertinoOut,
                          child: AppIcon(sel ? t.svgFilled : t.svg, color: color, size: 20),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ]),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// BOTTOM SHEET BASE — pequenas curvas (12px)
// ══════════════════════════════════════════════════════════════

Future<T?> showCraftBottomSheet<T>({
  required BuildContext context,
  required AppColorScheme s,
  required Widget child,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: s.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface)),
            ),
            const SizedBox(height: 4),
          ],
          child,
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// MODAL DE COR
// ══════════════════════════════════════════════════════════════

Future<String?> showColorPickerSheet(BuildContext context, AppColorScheme s, {String? label}) {
  final colors = [
    '#000000', '#FFFFFF', '#FF3B30', '#FF9500',
    '#FFCC00', '#34C759', '#00C7BE', '#2F7BF6',
    '#5856D6', '#AF52DE', '#FF2D55', '#8E8E93',
  ];
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    title: label ?? 'Selecionar cor',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: colors.map((hex) {
          final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
          return GestureDetector(
            onTap: () => Navigator.pop(context, hex),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: s.outline, width: 1.5),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// MODAL DE IMAGENS DO SISTEMA (simulado)
// Na prática, integraria image_picker ou photo_manager
// ══════════════════════════════════════════════════════════════

Future<void> showImagePickerSheet(BuildContext context, AppColorScheme s) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    title: 'Inserir imagem',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opções de origem
          _ImageSourceOption(
            s: s,
            icon: CupertinoIcons.photo_on_rectangle,
            label: 'Galeria de fotos',
            onTap: () {
              Navigator.pop(context);
              // image_picker: ImagePicker().pickImage(source: ImageSource.gallery)
            },
          ),
          _ImageSourceOption(
            s: s,
            icon: CupertinoIcons.camera,
            label: 'Câmara',
            onTap: () {
              Navigator.pop(context);
              // image_picker: ImagePicker().pickImage(source: ImageSource.camera)
            },
          ),
          _ImageSourceOption(
            s: s,
            icon: CupertinoIcons.doc,
            label: 'Ficheiros',
            onTap: () {
              Navigator.pop(context);
              // file_picker: FilePicker.platform.pickFiles(type: FileType.image)
            },
          ),
          _ImageSourceOption(
            s: s,
            icon: CupertinoIcons.link,
            label: 'URL de imagem',
            onTap: () {
              Navigator.pop(context);
              _showUrlImageDialog(context, s);
            },
          ),
        ],
      ),
    ),
  );
}

void _showUrlImageDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('URL da imagem'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: ctrl,
          placeholder: 'https://...',
          autofocus: true,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          onPressed: () {
            Navigator.pop(ctx);
            // usar ctrl.text para inserir a imagem
          },
          child: const Text('Inserir'),
        ),
      ],
    ),
  );
}

class _ImageSourceOption extends StatelessWidget {
  final AppColorScheme s;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: s.primary),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 15, color: s.onSurface)),
            const Spacer(),
            Icon(CupertinoIcons.chevron_right, size: 14, color: s.onSurfaceVariant),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// MODAL DE HIPERLIGAÇÃO
// ══════════════════════════════════════════════════════════════

Future<void> showLinkSheet(
    BuildContext context, AppColorScheme s, void Function(String url, String text) onInsert) {
  final urlC = TextEditingController();
  final txtC = TextEditingController();
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    title: 'Inserir hiperligação',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: [
        _SheetTextField(s: s, ctrl: urlC, hint: 'https://'),
        const SizedBox(height: 10),
        _SheetTextField(s: s, ctrl: txtC, hint: 'Texto (opcional)'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.outline.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Cancelar', style: TextStyle(color: s.onSurface)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                final url = urlC.text.trim();
                if (url.isNotEmpty) onInsert(url, txtC.text.trim());
              },
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Inserir',
                    style: TextStyle(
                        color: s.onPrimary, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ]),
    ),
  );
}

class _SheetTextField extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final String hint;

  const _SheetTextField({required this.s, required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: s.outline.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: ctrl,
          style: TextStyle(fontSize: 14, color: s.onSurface),
          cursorColor: s.primary,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// CHAT TAB
// ══════════════════════════════════════════════════════════════

class _ChatTab extends StatefulWidget {
  final VoidCallback onFirstMessage;
  const _ChatTab({required this.onFirstMessage});
  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<String> _msgs = [];

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final isFirst = _msgs.isEmpty;
    setState(() {
      _msgs.add(t);
      _ctrl.clear();
    });
    if (isFirst) widget.onFirstMessage();
    // Scroll para o fim
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: kCupertinoOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    // Espaço para o input + nav flutuante
    final inputBottom = 14.0 + 50.0 + 14.0; // nav height + margens

    return Column(children: [
      // Área de mensagens
      Expanded(
        child: _msgs.isEmpty
            ? _EmptyState(s: s)
            : ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _msgs.length,
                itemBuilder: (_, i) => _Bubble(s: s, text: _msgs[i]),
              ),
      ),
      // Input fixo na base
      _ChatInput(s: s, ctrl: _ctrl, onSend: _send),
      // Espaço para a nav flutuante
      SizedBox(height: inputBottom),
    ]);
  }
}

// Estado vazio — logo centralizado + mensagem
class _EmptyState extends StatelessWidget {
  final AppColorScheme s;
  const _EmptyState({required this.s});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 72, height: 72, fit: BoxFit.contain),
            const SizedBox(height: 16),
            Text(
              'Torna-te mais produtivo!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: s.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
}

class _Bubble extends StatefulWidget {
  final AppColorScheme s;
  final String text;
  const _Bubble({required this.s, required this.text});
  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale, _op;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = Tween(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: kCupertinoOut));
    _op = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Opacity(
          opacity: _op.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scale.value,
            alignment: Alignment.centerRight,
            child: child,
          ),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: widget.s.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.s.cardShadow,
            ),
            child: Text(widget.text,
                style: TextStyle(color: widget.s.onPrimaryContainer, fontSize: 14)),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// CHAT INPUT — bordas fixas de 22px, send fixo em baixo
// ══════════════════════════════════════════════════════════════

class _ChatInput extends StatefulWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _ChatInput({required this.s, required this.ctrl, required this.onSend});

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  // Raio fixo — não muda quando o input cresce
  static const double _radius = 22.0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
          // BorderRadius FIXO — não varia com o tamanho do container
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: s.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Área de texto — cresce verticalmente, sem influenciar o raio
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: widget.ctrl,
                minLines: 1,
                maxLines: 6,
                style: TextStyle(fontSize: 15, color: s.onSurface),
                cursorColor: s.primary,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Escreva uma mensagem...',
                  hintStyle: TextStyle(fontSize: 15, color: s.onSurfaceVariant),
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
            // Linha do send — sempre fixa em baixo
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: widget.onSend,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.primary,
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon('send.svg', color: s.onPrimary, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
// EDIT TAB — sem toolbar nativo (HTML tem o seu próprio)
// Modals de cor, imagem e link acessíveis via JS bridge
// ══════════════════════════════════════════════════════════════

class _EditTab extends StatefulWidget {
  final EditorType editorType;
  const _EditTab({required this.editorType});
  @override
  State<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<_EditTab> {
  final Map<EditorType, InAppWebViewController?> _controllers = {
    for (final t in EditorType.values) t: null,
  };

  void _runJs(String script) {
    _controllers[widget.editorType]?.evaluateJavascript(source: script);
  }

  // Abre modal de cor e envia resultado ao editor via JS
  void _openColorPicker(BuildContext context, AppColorScheme s, String jsCallback) async {
    final hex = await showColorPickerSheet(context, s);
    if (hex != null) _runJs("$jsCallback('$hex')");
  }

  // Abre modal de imagem
  void _openImagePicker(BuildContext context, AppColorScheme s) {
    showImagePickerSheet(context, s);
  }

  // Abre modal de link
  void _openLinkSheet(BuildContext context, AppColorScheme s) {
    showLinkSheet(context, s, (url, text) {
      _runJs("editorApi.insertLink('$url','$text')");
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final idx = EditorType.values.indexOf(widget.editorType);

    return IndexedStack(
      index: idx,
      children: EditorType.values.map((t) {
        if (kIsWeb) return const SizedBox.shrink();
        return InAppWebView(
          initialFile: t.htmlAsset,
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            javaScriptEnabled: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
          ),
          onWebViewCreated: (c) {
            _controllers[t] = c;
            // Handler para o HTML chamar modals Flutter
            c.addJavaScriptHandler(
              handlerName: 'openColorPicker',
              callback: (args) {
                final cb = args.isNotEmpty ? args[0] as String : 'editorApi.setColor';
                _openColorPicker(context, s, cb);
              },
            );
            c.addJavaScriptHandler(
              handlerName: 'openImagePicker',
              callback: (_) => _openImagePicker(context, s),
            );
            c.addJavaScriptHandler(
              handlerName: 'openLinkSheet',
              callback: (_) => _openLinkSheet(context, s),
            );
          },
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EDIT TYPE BUTTON (header trailing)
// ══════════════════════════════════════════════════════════════

class _EditTypeButton extends StatefulWidget {
  final AppColorScheme s;
  final EditorType current;
  final ValueChanged<EditorType> onSelect;
  const _EditTypeButton({required this.s, required this.current, required this.onSelect});
  @override
  State<_EditTypeButton> createState() => _EditTypeButtonState();
}

class _EditTypeButtonState extends State<_EditTypeButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _ov;
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _ac.dispose();
    _ov?.remove();
    super.dispose();
  }

  void _toggle() => _ov == null ? _open() : _close();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz = box.size;
    _ac.forward(from: 0);

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: off.dy + sz.height + 6,
          right: MediaQuery.of(ctx).size.width - off.dx - sz.width,
          child: AnimatedBuilder(
            animation: _ac,
            builder: (_, child) => Opacity(
              opacity: CurvedAnimation(
                      parent: _ac,
                      curve: const Interval(0, 0.5, curve: Curves.easeOut))
                  .value,
              child: Transform.scale(
                scale: Tween(begin: 0.92, end: 1.0)
                    .animate(CurvedAnimation(parent: _ac, curve: kCupertinoOut))
                    .value,
                alignment: Alignment.topRight,
                child: child,
              ),
            ),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: EditorType.values
                    .map((t) => _TypeOption(
                          s: s,
                          type: t,
                          selected: widget.current == t,
                          onTap: () {
                            widget.onSelect(t);
                            _close();
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_ov!);
    setState(() {});
  }

  void _close() {
    _ac.reverse().then((_) {
      _ov?.remove();
      _ov = null;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => _Tap(
        onTap: _toggle,
        s: widget.s,
        size: 36,
        child: AppIcon('more_filled.svg', color: widget.s.onSurface, size: 20),
      );
}

class _TypeOption extends StatefulWidget {
  final AppColorScheme s;
  final EditorType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption(
      {required this.s,
      required this.type,
      required this.selected,
      required this.onTap});
  @override
  State<_TypeOption> createState() => _TypeOptionState();
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
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _h
                ? widget.s.hover
                : widget.selected
                    ? widget.s.primaryContainer.withOpacity(0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            EditorTypeIcon(widget.type.pngAsset, size: 18),
            const SizedBox(width: 10),
            Text(widget.type.label,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.selected ? widget.s.primary : widget.s.onSurface,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// SETTINGS PAGE — card com contraste real no modo escuro
// ══════════════════════════════════════════════════════════════

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        // Fundo da página mais escuro que o card
        color: s.pageBackground,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appbar
              Container(
                color: s.pageBackground,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Row(children: [
                  _Tap(
  onTap: () => Navigator.pop(context),
  s: s,
  child: AppIcon('back.svg', color: s.onSurface, size: 20), // ← aqui
),
                    s: s,
                    child: Icon(CupertinoIcons.back, color: s.onSurface, size: 22),
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
                    // Card com cor bem diferente do fundo no dark
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        // dark: #2C2C2E sobre fundo #141414 — contraste claro
                        color: s.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: s.cardShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Modo escuro',
                              style:
                                  TextStyle(fontSize: 15, color: s.onSurface)),
                          _Switch(
                            value: appTheme.isDark,
                            s: s,
                            onChanged: (_) => appTheme.toggleDark(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Separador
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Container(height: 0.5, color: s.outlineVariant),
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
          duration: const Duration(milliseconds: 200),
          curve: kCupertinoOut,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? s.primary : s.outline,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? s.onPrimary : s.cardBackground,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}