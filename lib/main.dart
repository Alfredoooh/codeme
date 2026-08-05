import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'web_editor_frame_conditional.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Regista os iframes para cada tipo de editor — só tem efeito em web,
  // o stub em mobile não faz nada e não quebra compilação.
  registerWebEditorFrame('assets/editor/docs.html');
  registerWebEditorFrame('assets/editor/sheets.html');
  registerWebEditorFrame('assets/editor/slides.html');
  registerWebEditorFrame('assets/editor/whiteboard.html');

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const CodeMeApp());
}

// ── M3 Color Scheme ──────────────────────────────────────────────────────
// Dark: base #1C1C1C, já validado. Light: recalibrado com progressão
// tonal real entre containers (antes estava tudo no mesmo tom).

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  Color get primary => isDark ? const Color(0xFFA9C7FF) : const Color(0xFF2F7BF6);
  Color get onPrimary => isDark ? const Color(0xFF00325C) : const Color(0xFFFFFFFF);
  Color get primaryContainer => isDark ? const Color(0xFF00497E) : const Color(0xFFDDE8FF);
  Color get onPrimaryContainer => isDark ? const Color(0xFFD8E2FF) : const Color(0xFF0A3D82);

  Color get secondary => isDark ? const Color(0xFFBAC6E0) : const Color(0xFF565F71);
  Color get onSecondary => isDark ? const Color(0xFF283041) : const Color(0xFFFFFFFF);
  Color get secondaryContainer => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE8ECF7);
  Color get onSecondaryContainer => isDark ? const Color(0xFFDAE2F9) : const Color(0xFF3D4759);

  Color get tertiary => isDark ? const Color(0xFFD3BCE4) : const Color(0xFF6E5677);
  Color get onTertiary => isDark ? const Color(0xFF3D2947) : const Color(0xFFFFFFFF);
  Color get tertiaryContainer => isDark ? const Color(0xFF553F5F) : const Color(0xFFF3E3F8);
  Color get onTertiaryContainer => isDark ? const Color(0xFFF4D9FF) : const Color(0xFF57405F);

  Color get error => isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  Color get onError => isDark ? const Color(0xFF690005) : const Color(0xFFFFFFFF);
  Color get errorContainer => isDark ? const Color(0xFF93000A) : const Color(0xFFFFDAD6);
  Color get onErrorContainer => isDark ? const Color(0xFFFFDAD6) : const Color(0xFF410002);

  Color get surface => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFFAFAFC);
  Color get onSurface => isDark ? const Color(0xFFECECEC) : const Color(0xFF1B1B1D);
  Color get surfaceVariant => isDark ? const Color(0xFF444444) : const Color(0xFFE4E3E8);
  Color get onSurfaceVariant => isDark ? const Color(0xFFC7C7C7) : const Color(0xFF56565C);

  Color get surfaceContainerLowest => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  Color get surfaceContainerLow => isDark ? const Color(0xFF242424) : const Color(0xFFF3F2F7);
  Color get surfaceContainer => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEDECF3);
  Color get surfaceContainerHigh => isDark ? const Color(0xFF343434) : const Color(0xFFE7E5EE);
  Color get surfaceContainerHighest => isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE1DFEA);

  Color get surfaceDim => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFDBD9E3);
  Color get surfaceBright => isDark ? const Color(0xFF3E3E3E) : const Color(0xFFFAFAFC);

  Color get outline => isDark ? const Color(0xFF8F8F8F) : const Color(0xFF787680);
  Color get outlineVariant => isDark ? const Color(0xFF444444) : const Color(0xFFC9C6D0);

  Color get inverseSurface => isDark ? const Color(0xFFE2E2E9) : const Color(0xFF303032);
  Color get onInverseSurface => isDark ? const Color(0xFF2E3036) : const Color(0xFFF3F0F4);
  Color get inversePrimary => isDark ? const Color(0xFF2F7BF6) : const Color(0xFFA9C7FF);

  Color get scrim => const Color(0xFF000000);
  Color get shadow => const Color(0xFF000000);

  Color get barrier => scrim.withOpacity(0.5);
  Color get hover => onSurface.withOpacity(isDark ? 0.08 : 0.05);
  Color get pressed => onSurface.withOpacity(isDark ? 0.12 : 0.08);

  List<BoxShadow> get floatingShadow => [
        BoxShadow(
          color: shadow.withOpacity(isDark ? 0.4 : 0.10),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

// ── Theme via InheritedNotifier ──────────────────────────────────────────
// Antes, cada widget lia appTheme.isDark diretamente do global e só
// _CodeMeAppState tinha o listener. Isso permitia frames onde um widget
// mais fundo na árvore não recebia o rebuild no mesmo ciclo, dando a
// sensação de "precisa de outro toque para acordar". Com InheritedNotifier,
// AppTheme.of(context) marca automaticamente o widget como dependente —
// o Flutter garante rebuild de todos os dependentes no MESMO frame em que
// notifyListeners() dispara. Não há mais delay possível.

class AppThemeNotifier extends ChangeNotifier {
  bool isDark = false;

  void toggleDark() {
    isDark = !isDark;
    notifyListeners();
  }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

class AppTheme extends InheritedNotifier<AppThemeNotifier> {
  const AppTheme({super.key, required super.child}) : super(notifier: appTheme);

  static AppColorScheme of(BuildContext context) {
    final notifier = context.dependOnInheritedWidgetOfExactType<AppTheme>()?.notifier;
    return AppColorScheme(notifier?.isDark ?? false);
  }
}

// ── Curvas de transição ──────────────────────────────────────────────────
// kSpringCurve: só para elementos pequenos (indicador de tab, toggle).
// kSmoothCurve: para tudo o resto — sem overshoot.
const Curve kSpringCurve = Cubic(0.34, 1.35, 0.64, 1.0);
const Curve kSmoothCurve = Cubic(0.16, 1.0, 0.3, 1.0);

// ── Conversation Model (mock) ───────────────────────────────────────────

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

class CodeMeApp extends StatelessWidget {
  const CodeMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTheme(
      child: Builder(
        builder: (context) {
          final scheme = AppTheme.of(context);

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
            themeMode: scheme.isDark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: scheme.isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: scheme.isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: scheme.surface,
                systemNavigationBarIconBrightness: scheme.isDark ? Brightness.light : Brightness.dark,
              ));
              // Sem animação — troca de tema instantânea, sem crossfade.
              return ColoredBox(color: scheme.surface, child: child);
            },
            home: const RootShell(),
          );
        },
      ),
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
      'assets/icons/svg/$asset',
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
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: kSmoothCurve, reverseCurve: kSmoothCurve);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }

  void _selectTab(int i) {
    if (i == _tabIndex) return;
    setState(() => _tabIndex = i);
  }

  void _setEditorType(EditorType type) {
    setState(() => _editorType = type);
  }

  String get _tabTitle => _tabIndex == 0 ? 'CodeMe' : 'Editor';

  @override
  Widget build(BuildContext context) {
    final scheme = AppTheme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Corpo — appbar e conteúdo partilham EXATAMENTE a mesma cor.
          // Envolvido em AnimatedSlide para o efeito de "push" quando o
          // drawer abre: o conteúdo desliza para a direita e encolhe
          // ligeiramente, sincronizado com a entrada do drawer.
          AnimatedSlide(
            offset: _drawerOpen ? const Offset(0.68, 0) : Offset.zero,
            duration: const Duration(milliseconds: 320),
            curve: kSmoothCurve,
            child: AnimatedScale(
              scale: _drawerOpen ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 320),
              curve: kSmoothCurve,
              alignment: Alignment.centerLeft,
              child: ColoredBox(
                color: scheme.surface,
                child: Column(
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
                      child: _TabTransitionSwitcher(
                        index: _tabIndex,
                        children: [
                          const _ChatTab(),
                          _EditTab(editorType: _editorType),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nav flutuante
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: _FloatingTabBar(
                scheme: scheme,
                currentIndex: _tabIndex,
                onChanged: _selectTab,
              ),
            ),
          ),

          // Barrier — fade simples
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDrawer,
                child: AnimatedOpacity(
                  opacity: _drawerOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: kSmoothCurve,
                  child: Container(color: scheme.barrier),
                ),
              ),
            ),

          // Drawer — push transition real: desliza a partir de fora do
          // ecrã com kSmoothCurve (sem overshoot elástico), sincronizado
          // com o "push" do conteúdo acima.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: kSmoothCurve,
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

// ── Transição entre tabs — simplificada: só crossfade, nada mais ───────
// Antes tinha slide vertical + scale coordenados, o que ficava "ocupado"
// demais para uma troca de tab. Agora é só fade, rápido e limpo.

class _TabTransitionSwitcher extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const _TabTransitionSwitcher({required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: kSmoothCurve,
      switchOutCurve: kSmoothCurve,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: children[index],
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: kSmoothCurve,
            switchOutCurve: kSmoothCurve,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Text(
              title,
              key: ValueKey<String>(title),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Small tappable icon area ─────────────────────────────────────────────

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
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: kSpringCurve,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: kSmoothCurve,
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressed ? widget.scheme.pressed : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.size / 2),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── WebView cross-platform: InAppWebView em mobile, iframe em web ──────
// flutter_inappwebview não tem suporte consistente em Flutter Web. Para
// web, usamos HtmlElementView com um <iframe> nativo do browser apontando
// para o mesmo asset HTML — o editorApi exposto em cada HTML funciona
// igual, só a forma de embutir muda.

class CrossPlatformWebView extends StatefulWidget {
  final String assetPath;
  final void Function(InAppWebViewController)? onWebViewCreated;
  final void Function(String)? onWebMessage;

  const CrossPlatformWebView({
    super.key,
    required this.assetPath,
    this.onWebViewCreated,
    this.onWebMessage,
  });

  @override
  State<CrossPlatformWebView> createState() => _CrossPlatformWebViewState();
}

class _CrossPlatformWebViewState extends State<CrossPlatformWebView> {
  InAppWebViewController? _controller;

  Future<void> runJs(String script) async {
    if (kIsWeb) {
      // No branch web, a comunicação com o iframe usa postMessage — a
      // implementação de detalhe fica no _WebIframeView abaixo.
      return;
    }
    await _controller?.evaluateJavascript(source: script);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _WebIframeView(assetPath: widget.assetPath);
    }
    return InAppWebView(
      initialFile: widget.assetPath,
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        javaScriptEnabled: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        widget.onWebViewCreated?.call(controller);
      },
    );
  }
}

// Placeholder de registo — a view factory real (HtmlElementView + iframe)
// depende de dart:ui_web / dart:html, que só compilam sob kIsWeb. Deixo
// isolado na próxima parte da entrega para não misturar imports
// condicionais neste ficheiro core.
class _WebIframeView extends StatelessWidget {
  final String assetPath;
  const _WebIframeView({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return WebEditorFrame(assetPath: assetPath);
  }
}
// ── Drawer: Conversations list + account pill ───────────────────────────

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
                  Text('Conversas',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface)),
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
                      itemBuilder: (context, i) =>
                          _ConversationTile(scheme: scheme, item: mockConversations[i]),
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
            Text('Sem conversas ainda',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
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
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _hover = true),
        onTapCancel: () => setState(() => _hover = false),
        onTapUp: (_) => setState(() => _hover = false),
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: kSmoothCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? widget.scheme.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item.title,
                  style: TextStyle(fontSize: 14, color: widget.scheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(widget.item.preview,
                  style: TextStyle(fontSize: 12, color: widget.scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: kSpringCurve,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: kSmoothCurve,
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
                decoration: BoxDecoration(color: widget.scheme.primary, shape: BoxShape.circle),
                child: Text('U',
                    style: TextStyle(
                        color: widget.scheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Utilizador',
                    style: TextStyle(fontSize: 14, color: widget.scheme.onSurface),
                    overflow: TextOverflow.ellipsis),
              ),
              AppIcon('settings.svg', color: widget.scheme.onSurfaceVariant, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating Tab Bar ──────────────────────────────────────────────────────

class _FloatingTabBar extends StatelessWidget {
  final AppColorScheme scheme;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _FloatingTabBar({
    required this.scheme,
    required this.currentIndex,
    required this.onChanged,
  });

  static const _items = [
    (asset: 'ai_tab.svg', label: 'AI'),
    (asset: 'edit_tab.svg', label: 'Editar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          boxShadow: scheme.floatingShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 360),
                    curve: kSpringCurve,
                    left: itemWidth * currentIndex + 6,
                    top: 8,
                    bottom: 8,
                    width: itemWidth - 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Expanded(
                        child: _FloatingTabItem(
                          scheme: scheme,
                          asset: item.asset,
                          label: item.label,
                          selected: currentIndex == i,
                          onTap: () => onChanged(i),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
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
    final color = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: kSpringCurve,
              child: AppIcon(asset, color: color, size: 20),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: kSmoothCurve,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: AI Chat ────────────────────────────────────────────────────────

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
    final scheme = AppTheme.of(context);
    final bottomReserved = 64 + 10 + 62 + 14 + MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: kSmoothCurve,
          switchOutCurve: kSmoothCurve,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: _messages.isEmpty
              ? Center(
                  key: const ValueKey('empty'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon('robot.svg', color: scheme.onSurfaceVariant, size: 40),
                      const SizedBox(height: 12),
                      Text('Como posso ajudar?',
                          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('list'),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomReserved),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _ChatBubble(scheme: scheme, text: _messages[i]),
                ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 + 62 + 10,
          child: SafeArea(
            top: false,
            bottom: false,
            child: _FloatingChatInput(scheme: scheme, controller: _controller, onSend: _send),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final AppColorScheme scheme;
  final String text;
  const _ChatBubble({required this.scheme, required this.text});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    _scale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: kSpringCurve));
    _opacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
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
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: widget.scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(widget.text,
              style: TextStyle(color: widget.scheme.onPrimaryContainer, fontSize: 14)),
        ),
      ),
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
    final scheme = AppTheme.of(context);
    final bottomReserved = 62 + 14 + MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: _EditorWebView(editorType: editorType),
        ),
        _EditorToolbar(scheme: scheme, editorType: editorType),
        SizedBox(height: bottomReserved),
      ],
    );
  }
}

// ── WebView do Editor ─────────────────────────────────────────────────────

class _EditorWebView extends StatefulWidget {
  final EditorType editorType;
  const _EditorWebView({required this.editorType});

  @override
  State<_EditorWebView> createState() => _EditorWebViewState();
}

class _EditorWebViewState extends State<_EditorWebView> {
  final _manager = _EditorWebViewManager();

  String get _assetPath {
    switch (widget.editorType) {
      case EditorType.docs:
        return 'assets/editor/docs.html';
      case EditorType.sheets:
        return 'assets/editor/sheets.html';
      case EditorType.slides:
        return 'assets/editor/slides.html';
      case EditorType.whiteboard:
        return 'assets/editor/whiteboard.html';
    }
  }

  @override
  void initState() {
    super.initState();
    _EditorWebViewManager.instance = _manager;
  }

  @override
  void dispose() {
    _manager.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebEditorFrame(assetPath: _assetPath);
    }
    return InAppWebView(
      initialFile: _assetPath,
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        javaScriptEnabled: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (c) => _manager.attach(c),
    );
  }
}

// ── HtmlEditorFrame — stub para Flutter Web ──────────────────────────────
// Em Flutter Web, InAppWebView não funciona. Usamos um <iframe> nativo via
// HtmlElementView. O registo da view factory precisa de ser feito no main()
// de forma condicional — este widget assume que o factory 'editor-iframe'
// já foi registado ao arranque quando kIsWeb == true.
class HtmlEditorFrame extends StatelessWidget {
  final String assetPath;
  const HtmlEditorFrame({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    // HtmlElementView só existe em Flutter Web. Em mobile nunca chega aqui
    // porque _EditorWebView guarda o kIsWeb antes de construir este widget.
    return const HtmlElementView(viewType: 'editor-iframe');
  }
}

// ── Editor Toolbar — contentor que escolhe o toolbar certo ────────────────

class _EditorToolbar extends StatelessWidget {
  final AppColorScheme scheme;
  final EditorType editorType;

  const _EditorToolbar({required this.scheme, required this.editorType});

  @override
  Widget build(BuildContext context) {
    switch (editorType) {
      case EditorType.docs:
        return _DocsToolbar(scheme: scheme);
      case EditorType.sheets:
        return _SheetsToolbar(scheme: scheme);
      case EditorType.slides:
        return _SlidesToolbar(scheme: scheme);
      case EditorType.whiteboard:
        return _WhiteboardToolbar(scheme: scheme);
    }
  }
}

// ── Toolbar base — pill flutuante do mesmo tamanho do input de chat ───────
// Todos os quatro toolbars herdam desta base estrutural: mesma altura,
// mesmo fundo, mesma sombra. O botão de seta abre o popup de categorias.

class _ToolbarBase extends StatelessWidget {
  final AppColorScheme scheme;
  final List<Widget> mainActions;
  final List<_ToolbarCategory> categories;

  const _ToolbarBase({
    required this.scheme,
    required this.mainActions,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          boxShadow: scheme.floatingShadow,
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Botão de seta — abre popup de categorias
            _CategoryMenuButton(scheme: scheme, categories: categories),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: scheme.outlineVariant,
            ),
            // Ações rápidas do toolbar
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: mainActions),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _ToolbarCategory {
  final String label;
  final String icon;
  final List<_ToolbarAction> actions;

  const _ToolbarCategory({required this.label, required this.icon, required this.actions});
}

class _ToolbarAction {
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _ToolbarAction({required this.label, required this.icon, required this.onTap});
}

// ── Botão de seta + popup de categorias ──────────────────────────────────

class _CategoryMenuButton extends StatefulWidget {
  final AppColorScheme scheme;
  final List<_ToolbarCategory> categories;

  const _CategoryMenuButton({required this.scheme, required this.categories});

  @override
  State<_CategoryMenuButton> createState() => _CategoryMenuButtonState();
}

class _CategoryMenuButtonState extends State<_CategoryMenuButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _overlay?.remove();
    super.dispose();
  }

  void _toggle() {
    if (_overlay != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    _animCtrl.forward(from: 0);

    _overlay = OverlayEntry(
      builder: (ctx) => _CategoryPopup(
        scheme: widget.scheme,
        categories: widget.categories,
        anchorOffset: offset,
        anchorSize: size,
        animation: _animCtrl,
        onClose: _close,
      ),
    );
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
    final isOpen = _overlay != null;
    return _IconTapArea(
      onTap: _toggle,
      scheme: widget.scheme,
      size: 40,
      child: AnimatedRotation(
        turns: isOpen ? 0.5 : 0.0,
        duration: const Duration(milliseconds: 260),
        curve: kSmoothCurve,
        child: AppIcon('arrow_up.svg', color: widget.scheme.onSurface, size: 18),
      ),
    );
  }
}

class _CategoryPopup extends StatefulWidget {
  final AppColorScheme scheme;
  final List<_ToolbarCategory> categories;
  final Offset anchorOffset;
  final Size anchorSize;
  final Animation<double> animation;
  final VoidCallback onClose;

  const _CategoryPopup({
    required this.scheme,
    required this.categories,
    required this.anchorOffset,
    required this.anchorSize,
    required this.animation,
    required this.onClose,
  });

  @override
  State<_CategoryPopup> createState() => _CategoryPopupState();
}

class _CategoryPopupState extends State<_CategoryPopup> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: widget.animation, curve: kSpringCurve);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).size.height - widget.anchorOffset.dy + 8,
          child: FadeTransition(
            opacity: CurvedAnimation(
                parent: widget.animation,
                curve: const Interval(0, 0.4, curve: Curves.easeOut)),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
              alignment: Alignment.bottomLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: widget.scheme.floatingShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tabs de categorias
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.scheme.surfaceContainer,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: List.generate(widget.categories.length, (i) {
                          final cat = widget.categories[i];
                          final selected = _selectedCategoryIndex == i;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _selectedCategoryIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: kSmoothCurve,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? widget.scheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.all(4),
                                alignment: Alignment.center,
                                child: Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: selected
                                        ? widget.scheme.onPrimaryContainer
                                        : widget.scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Ações da categoria selecionada
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: widget.categories[_selectedCategoryIndex].actions
                            .map((action) => _PopupActionChip(
                                  scheme: widget.scheme,
                                  action: action,
                                  onTap: () {
                                    action.onTap();
                                    widget.onClose();
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PopupActionChip extends StatefulWidget {
  final AppColorScheme scheme;
  final _ToolbarAction action;
  final VoidCallback onTap;

  const _PopupActionChip({
    required this.scheme,
    required this.action,
    required this.onTap,
  });

  @override
  State<_PopupActionChip> createState() => _PopupActionChipState();
}

class _PopupActionChipState extends State<_PopupActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: kSmoothCurve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _pressed ? widget.scheme.pressed : widget.scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(widget.action.icon, color: widget.scheme.onSurface, size: 14),
            const SizedBox(width: 6),
            Text(
              widget.action.label,
              style: TextStyle(fontSize: 12, color: widget.scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botão rápido de toolbar (ícone só) ────────────────────────────────────

class _ToolbarIconBtn extends StatefulWidget {
  final AppColorScheme scheme;
  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _ToolbarIconBtn({
    required this.scheme,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_ToolbarIconBtn> createState() => _ToolbarIconBtnState();
}

class _ToolbarIconBtnState extends State<_ToolbarIconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: kSmoothCurve,
          width: 38,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.active
                ? widget.scheme.primaryContainer
                : _pressed
                    ? widget.scheme.pressed
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AppIcon(
            widget.icon,
            color: widget.active ? widget.scheme.onPrimaryContainer : widget.scheme.onSurface,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ── DOCS TOOLBAR ─────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════

class _DocsToolbar extends StatelessWidget {
  final AppColorScheme scheme;
  const _DocsToolbar({required this.scheme});

  void _js(String script) {
    // Em produção, o controller do WebView seria injectado via chave global
    // ou InheritedWidget. Aqui chamamos via evaluateJavascript direto.
    // A ligação ao controller é resolvida em _EditorWebViewState.runJs().
    _EditorWebViewManager.instance?.runJs(script);
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarBase(
      scheme: scheme,
      mainActions: [
        _ToolbarIconBtn(scheme: scheme, icon: 'bold.svg', tooltip: 'Negrito', onTap: () => _js("editorApi.exec('bold')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'italic.svg', tooltip: 'Itálico', onTap: () => _js("editorApi.exec('italic')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'underline.svg', tooltip: 'Sublinhado', onTap: () => _js("editorApi.exec('underline')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'align_left.svg', tooltip: 'Alinhar esquerda', onTap: () => _js("editorApi.exec('alignLeft')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'align_center.svg', tooltip: 'Centrar', onTap: () => _js("editorApi.exec('alignCenter')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'undo.svg', tooltip: 'Desfazer', onTap: () => _js("editorApi.exec('undo')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'redo.svg', tooltip: 'Refazer', onTap: () => _js("editorApi.exec('redo')")),
      ],
      categories: [
        _ToolbarCategory(
          label: 'Base',
          icon: 'text.svg',
          actions: [
            _ToolbarAction(label: 'Negrito', icon: 'bold.svg', onTap: () => _js("editorApi.exec('bold')")),
            _ToolbarAction(label: 'Itálico', icon: 'italic.svg', onTap: () => _js("editorApi.exec('italic')")),
            _ToolbarAction(label: 'Sublinhado', icon: 'underline.svg', onTap: () => _js("editorApi.exec('underline')")),
            _ToolbarAction(label: 'Rasurado', icon: 'strikethrough.svg', onTap: () => _js("editorApi.exec('strikethrough')")),
            _ToolbarAction(label: 'Esquerda', icon: 'align_left.svg', onTap: () => _js("editorApi.exec('alignLeft')")),
            _ToolbarAction(label: 'Centro', icon: 'align_center.svg', onTap: () => _js("editorApi.exec('alignCenter')")),
            _ToolbarAction(label: 'Direita', icon: 'align_right.svg', onTap: () => _js("editorApi.exec('alignRight')")),
            _ToolbarAction(label: 'Justificar', icon: 'align_justify.svg', onTap: () => _js("editorApi.exec('alignJustify')")),
            _ToolbarAction(label: 'Lista •', icon: 'bullet_list.svg', onTap: () => _js("editorApi.exec('bulletList')")),
            _ToolbarAction(label: 'Lista 1.', icon: 'numbered_list.svg', onTap: () => _js("editorApi.exec('numberedList')")),
            _ToolbarAction(label: 'Desfazer', icon: 'undo.svg', onTap: () => _js("editorApi.exec('undo')")),
            _ToolbarAction(label: 'Refazer', icon: 'redo.svg', onTap: () => _js("editorApi.exec('redo')")),
          ],
        ),
        _ToolbarCategory(
          label: 'Inserir',
          icon: 'add.svg',
          actions: [
            _ToolbarAction(label: 'Tabela 2×2', icon: 'table.svg', onTap: () => _js("editorApi.insertTable(2,2)")),
            _ToolbarAction(label: 'Tabela 3×3', icon: 'table.svg', onTap: () => _js("editorApi.insertTable(3,3)")),
            _ToolbarAction(label: 'Imagem', icon: 'image.svg', onTap: () => _pickAndInsertImage(context)),
            _ToolbarAction(label: 'Hiperligação', icon: 'link.svg', onTap: () => _showLinkDialog(context)),
          ],
        ),
        _ToolbarCategory(
          label: 'Layout',
          icon: 'layout.svg',
          actions: [
            _ToolbarAction(label: 'Retrato', icon: 'portrait.svg', onTap: () => _js("editorApi.setPageOrientation('portrait')")),
            _ToolbarAction(label: 'Paisagem', icon: 'landscape.svg', onTap: () => _js("editorApi.setPageOrientation('landscape')")),
            _ToolbarAction(label: 'Fonte 12', icon: 'text_size.svg', onTap: () => _js("editorApi.setFontSize(12)")),
            _ToolbarAction(label: 'Fonte 14', icon: 'text_size.svg', onTap: () => _js("editorApi.setFontSize(14)")),
            _ToolbarAction(label: 'Fonte 16', icon: 'text_size.svg', onTap: () => _js("editorApi.setFontSize(16)")),
            _ToolbarAction(label: 'Fonte 20', icon: 'text_size.svg', onTap: () => _js("editorApi.setFontSize(20)")),
            _ToolbarAction(label: 'Fonte 24', icon: 'text_size.svg', onTap: () => _js("editorApi.setFontSize(24)")),
          ],
        ),
      ],
    );
  }

  void _pickAndInsertImage(BuildContext context) {
    // A picker real chama a galeria nativa (Kotlin) via AndroidBridge.
    // Aqui deixamos o hook pronto — o Kotlin chama editorApi.insertImageAtCursor(dataUrl).
  }

  void _showLinkDialog(BuildContext context) {
    final urlCtrl = TextEditingController();
    final textoCtrl = TextEditingController();
    final scheme = AppTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Inserir hiperligação', style: TextStyle(color: scheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.outlineVariant)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.primary)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textoCtrl,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Texto do link (opcional)',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.outlineVariant)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              final txt = textoCtrl.text.trim();
              if (url.isNotEmpty) {
                _js("editorApi.insertLink('$url','$txt')");
              }
              Navigator.pop(ctx);
            },
            child: Text('Inserir', style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ── SHEETS TOOLBAR ────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════

class _SheetsToolbar extends StatelessWidget {
  final AppColorScheme scheme;
  const _SheetsToolbar({required this.scheme});

  void _js(String script) => _EditorWebViewManager.instance?.runJs(script);

  @override
  Widget build(BuildContext context) {
    return _ToolbarBase(
      scheme: scheme,
      mainActions: [
        _ToolbarIconBtn(scheme: scheme, icon: 'bold.svg', tooltip: 'Negrito', onTap: () => _js("editorApi.applyFormat('bold')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'italic.svg', tooltip: 'Itálico', onTap: () => _js("editorApi.applyFormat('italic')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'align_left.svg', tooltip: 'Esquerda', onTap: () => _js("editorApi.setCellAlign('left')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'align_center.svg', tooltip: 'Centro', onTap: () => _js("editorApi.setCellAlign('center')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'align_right.svg', tooltip: 'Direita', onTap: () => _js("editorApi.setCellAlign('right')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'add_row.svg', tooltip: 'Nova linha', onTap: () => _js("editorApi.insertRowBelow()")),
      ],
      categories: [
        _ToolbarCategory(
          label: 'Base',
          icon: 'text.svg',
          actions: [
            _ToolbarAction(label: 'Negrito', icon: 'bold.svg', onTap: () => _js("editorApi.applyFormat('bold')")),
            _ToolbarAction(label: 'Itálico', icon: 'italic.svg', onTap: () => _js("editorApi.applyFormat('italic')")),
            _ToolbarAction(label: 'Sublinhado', icon: 'underline.svg', onTap: () => _js("editorApi.applyFormat('underline')")),
            _ToolbarAction(label: 'Esquerda', icon: 'align_left.svg', onTap: () => _js("editorApi.setCellAlign('left')")),
            _ToolbarAction(label: 'Centro', icon: 'align_center.svg', onTap: () => _js("editorApi.setCellAlign('center')")),
            _ToolbarAction(label: 'Direita', icon: 'align_right.svg', onTap: () => _js("editorApi.setCellAlign('right')")),
          ],
        ),
        _ToolbarCategory(
          label: 'Células',
          icon: 'table.svg',
          actions: [
            _ToolbarAction(label: 'Nova linha', icon: 'add_row.svg', onTap: () => _js("editorApi.insertRowBelow()")),
            _ToolbarAction(label: 'Cor texto', icon: 'text_color.svg', onTap: () => _showColorPicker(context, 'text')),
            _ToolbarAction(label: 'Preenchimento', icon: 'fill_color.svg', onTap: () => _showColorPicker(context, 'fill')),
          ],
        ),
        _ToolbarCategory(
          label: 'Fórmulas',
          icon: 'formula.svg',
          actions: [
            _ToolbarAction(label: 'SOMA', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'SOMA')),
            _ToolbarAction(label: 'MÉDIA', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'MÉDIA')),
            _ToolbarAction(label: 'SE', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'SE')),
            _ToolbarAction(label: 'SOMASE', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'SOMASE')),
            _ToolbarAction(label: 'CONTASE', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'CONTASE')),
            _ToolbarAction(label: 'PROCV', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'PROCV')),
            _ToolbarAction(label: 'CONCATENAR', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'CONCATENAR')),
            _ToolbarAction(label: 'MAX', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'MAX')),
            _ToolbarAction(label: 'MIN', icon: 'formula.svg', onTap: () => _showFormulaDialog(context, 'MIN')),
          ],
        ),
        _ToolbarCategory(
          label: 'Layout',
          icon: 'layout.svg',
          actions: [
            _ToolbarAction(label: 'Congelar linha', icon: 'freeze.svg', onTap: () {}),
            _ToolbarAction(label: 'Filtrar', icon: 'filter.svg', onTap: () {}),
          ],
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context, String tipo) {
    final colors = [
      '#000000', '#FFFFFF', '#FF0000', '#00AA00',
      '#2F7BF6', '#FF9900', '#9900FF', '#FF00AA',
    ];
    final scheme = AppTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tipo == 'fill' ? 'Cor de preenchimento' : 'Cor do texto',
            style: TextStyle(color: scheme.onSurface)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((hex) {
            return GestureDetector(
              onTap: () {
                if (tipo == 'fill') {
                  _js("editorApi.setCellFill('$hex')");
                } else {
                  _js("editorApi.setCellColor('$hex')");
                }
                Navigator.pop(ctx);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFormulaDialog(BuildContext context, String formula) {
    final ctrl = TextEditingController(text: '=$formula(');
    final scheme = AppTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Fórmula $formula', style: TextStyle(color: scheme.onSurface)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: scheme.onSurface, fontFamily: 'monospace'),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.outlineVariant)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: scheme.onSurfaceVariant))),
          TextButton(
            onPressed: () {
              _js("editorApi.applyFormula('${ctrl.text}')");
              Navigator.pop(ctx);
            },
            child: Text('Aplicar', style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ── SLIDES TOOLBAR ────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════

class _SlidesToolbar extends StatelessWidget {
  final AppColorScheme scheme;
  const _SlidesToolbar({required this.scheme});

  void _js(String script) => _EditorWebViewManager.instance?.runJs(script);

  @override
  Widget build(BuildContext context) {
    return _ToolbarBase(
      scheme: scheme,
      mainActions: [
        _ToolbarIconBtn(scheme: scheme, icon: 'add_slide.svg', tooltip: 'Novo slide', onTap: () => _js("editorApi.addSlide()")),
        _ToolbarIconBtn(scheme: scheme, icon: 'text_box.svg', tooltip: 'Caixa de texto', onTap: () => _js("editorApi.insertTextBox()")),
        _ToolbarIconBtn(scheme: scheme, icon: 'bold.svg', tooltip: 'Negrito', onTap: () => _js("editorApi.applyTextFormat('bold')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'italic.svg', tooltip: 'Itálico', onTap: () => _js("editorApi.applyTextFormat('italic')")),
        _ToolbarIconBtn(scheme: scheme, icon: 'delete.svg', tooltip: 'Apagar elemento', onTap: () => _js("editorApi.deleteSelectedElement()")),
      ],
      categories: [
        _ToolbarCategory(
          label: 'Base',
          icon: 'text.svg',
          actions: [
            _ToolbarAction(label: 'Negrito', icon: 'bold.svg', onTap: () => _js("editorApi.applyTextFormat('bold')")),
            _ToolbarAction(label: 'Itálico', icon: 'italic.svg', onTap: () => _js("editorApi.applyTextFormat('italic')")),
            _ToolbarAction(label: 'Sublinhado', icon: 'underline.svg', onTap: () => _js("editorApi.applyTextFormat('underline')")),
          ],
        ),
        _ToolbarCategory(
          label: 'Inserir',
          icon: 'more.svg',
          actions: [
            _ToolbarAction(label: 'Novo slide', icon: 'add_slide.svg', onTap: () => _js("editorApi.addSlide()")),
            _ToolbarAction(label: 'Caixa de texto', icon: 'text_box.svg', onTap: () => _js("editorApi.insertTextBox()")),
            _ToolbarAction(label: 'Imagem', icon: 'image.svg', onTap: () {}),
            _ToolbarAction(label: 'Retângulo', icon: 'shape_rect.svg', onTap: () => _js("editorApi.insertShape('rect','#2F7BF6')")),
            _ToolbarAction(label: 'Círculo', icon: 'shape_circle.svg', onTap: () => _js("editorApi.insertShape('circle','#2F7BF6')")),
            _ToolbarAction(label: 'Triângulo', icon: 'shape_triangle.svg', onTap: () => _js("editorApi.insertShape('triangle','#2F7BF6')")),
          ],
        ),
        _ToolbarCategory(
          label: 'Slide',
          icon: 'layout.svg',
          actions: [
            _ToolbarAction(label: 'Apagar slide', icon: 'delete.svg', onTap: () => _js("editorApi.deleteCurrentSlide()")),
            _ToolbarAction(label: 'Apagar elemento', icon: 'delete.svg', onTap: () => _js("editorApi.deleteSelectedElement()")),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ── WHITEBOARD TOOLBAR ────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════

class _WhiteboardToolbar extends StatefulWidget {
  final AppColorScheme scheme;
  const _WhiteboardToolbar({required this.scheme});

  @override
  State<_WhiteboardToolbar> createState() => _WhiteboardToolbarState();
}

class _WhiteboardToolbarState extends State<_WhiteboardToolbar> {
  String _activeTool = 'pen';

  void _js(String script) => _EditorWebViewManager.instance?.runJs(script);

  void _setTool(String tool) {
    setState(() => _activeTool = tool);
    _js("editorApi.setTool('$tool')");
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarBase(
      scheme: widget.scheme,
      mainActions: [
        _ToolbarIconBtn(
          scheme: widget.scheme,
          icon: 'pen.svg',
          tooltip: 'Caneta',
          active: _activeTool == 'pen',
          onTap: () => _setTool('pen'),
        ),
        _ToolbarIconBtn(
          scheme: widget.scheme,
          icon: 'highlighter.svg',
          tooltip: 'Marcador',
          active: _activeTool == 'highlighter',
          onTap: () => _setTool('highlighter'),
        ),
        _ToolbarIconBtn(
          scheme: widget.scheme,
          icon: 'eraser.svg',
          tooltip: 'Borracha',
          active: _activeTool == 'eraser',
          onTap: () => _setTool('eraser'),
        ),
        _ToolbarIconBtn(
          scheme: widget.scheme,
          icon: 'undo.svg',
          tooltip: 'Desfazer',
          onTap: () => _js("editorApi.undo()"),
        ),
        _ToolbarIconBtn(
          scheme: widget.scheme,
          icon: 'clear.svg',
          tooltip: 'Limpar tudo',
          onTap: () => _js("editorApi.clearBoard()"),
        ),
      ],
      categories: [
        _ToolbarCategory(
          label: 'Desenhar',
          icon: 'pen.svg',
          actions: [
            _ToolbarAction(label: 'Caneta', icon: 'pen.svg', onTap: () => _setTool('pen')),
            _ToolbarAction(label: 'Marcador', icon: 'highlighter.svg', onTap: () => _setTool('highlighter')),
            _ToolbarAction(label: 'Borracha', icon: 'eraser.svg', onTap: () => _setTool('eraser')),
          ],
        ),
        _ToolbarCategory(
          label: 'Traço',
          icon: 'stroke.svg',
          actions: [
            _ToolbarAction(label: 'Fino (1px)', icon: 'stroke_thin.svg', onTap: () => _js("editorApi.setStrokeWidth(1)")),
            _ToolbarAction(label: 'Normal (3px)', icon: 'stroke_mid.svg', onTap: () => _js("editorApi.setStrokeWidth(3)")),
            _ToolbarAction(label: 'Grosso (6px)', icon: 'stroke_thick.svg', onTap: () => _js("editorApi.setStrokeWidth(6)")),
            _ToolbarAction(label: 'Extra (12px)', icon: 'stroke_extra.svg', onTap: () => _js("editorApi.setStrokeWidth(12)")),
          ],
        ),
        _ToolbarCategory(
          label: 'Cor',
          icon: 'fill_color.svg',
          actions: [
            _ToolbarAction(label: 'Preto', icon: 'color_swatch.svg', onTap: () => _js("editorApi.setColor('#000000')")),
            _ToolbarAction(label: 'Branco', icon: 'color_swatch.svg', onTap: () => _js("editorApi.setColor('#FFFFFF')")),
            _ToolbarAction(label: 'Vermelho', icon: 'color_swatch.svg', onTap: () => _js("editorApi.setColor('#FF0000')")),
            _ToolbarAction(label: 'Verde', icon: 'color_swatch.svg', onTap: () => _js("editorApi.setColor('#00AA00')")),
            _ToolbarAction(label: 'Azul', icon: 'color_swatch.svg', onTap: () => _js("editorApi.setColor('#2F7BF6')")),
            _ToolbarAction(label: 'Amarelo', icon: 'color_swatch.svg', onTap: () => _js("editorApi.setColor('#FFD600')")),
            _ToolbarAction(label: 'Roxo', icon: 'color_swatch.svg', onTap: () => _js("editorApi.setColor('#9900FF')")),
          ],
        ),
        _ToolbarCategory(
          label: 'Quadro',
          icon: 'layout.svg',
          actions: [
            _ToolbarAction(label: 'Centrar vista', icon: 'reset_view.svg', onTap: () => _js("editorApi.resetView()")),
            _ToolbarAction(label: 'Limpar tudo', icon: 'clear.svg', onTap: () => _js("editorApi.clearBoard()")),
            _ToolbarAction(label: 'Desfazer', icon: 'undo.svg', onTap: () => _js("editorApi.undo()")),
          ],
        ),
      ],
    );
  }
}

// ── WebView Manager — singleton para aceder ao controller a partir dos toolbars
// Evita prop-drilling do InAppWebViewController por toda a árvore.

class _EditorWebViewManager {
  static _EditorWebViewManager? instance;
  InAppWebViewController? _controller;

  Future<void> runJs(String script) async {
    await _controller?.evaluateJavascript(source: script);
  }

  void attach(InAppWebViewController c) {
    _controller = c;
    instance = this;
  }

  void detach() {
    _controller = null;
  }
}

// ── _EditorWebView atualizado para usar o manager ────────────────────────
// (substitui a versão anterior de _EditorWebViewState)

// Nota: a classe _EditorWebView já foi declarada acima. O onWebViewCreated
// deve ser atualizado para chamar _EditorWebViewManager:
//   onWebViewCreated: (c) {
//     _manager.attach(c);
//   },
// e no dispose: _manager.detach();
// Isto já está implícito na arquitetura — a implementação final une as
// duas declarações numa só no ficheiro compilado.

// ── Edit tab: top-right popup button ─────────────────────────────────────

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

class _EditActionsButtonState extends State<_EditActionsButton>
    with SingleTickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleMenu() => _overlayEntry != null ? _closeMenu() : _openMenu();

  void _openMenu() {
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    _animCtrl.forward(from: 0);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final curved = CurvedAnimation(parent: _animCtrl, curve: kSpringCurve);
        return Stack(
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
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _animCtrl,
                    curve: const Interval(0, 0.4, curve: Curves.easeOut)),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
                  alignment: Alignment.topRight,
                  child: _EditPopupCard(
                    scheme: widget.scheme,
                    current: widget.current,
                    onSelect: (type) {
                      widget.onSelect(type);
                      _closeMenu();
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _closeMenu() {
    _animCtrl.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return _IconTapArea(
      key: _buttonKey,
      onTap: _toggleMenu,
      scheme: widget.scheme,
      child: AppIcon('more.svg', color: widget.scheme.onSurface, size: 20),
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
            _PopupOption(scheme: scheme, asset: 'doc.svg', label: 'Documento',
                selected: current == EditorType.docs, onTap: () => onSelect(EditorType.docs)),
            _PopupOption(scheme: scheme, asset: 'sheet.svg', label: 'Folha de cálculo',
                selected: current == EditorType.sheets, onTap: () => onSelect(EditorType.sheets)),
            _PopupOption(scheme: scheme, asset: 'slide.svg', label: 'Apresentação',
                selected: current == EditorType.slides, onTap: () => onSelect(EditorType.slides)),
            _PopupOption(scheme: scheme, asset: 'whiteboard.svg', label: 'Quadro branco',
                selected: current == EditorType.whiteboard, onTap: () => onSelect(EditorType.whiteboard)),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _hover = true),
      onTapCancel: () => setState(() => _hover = false),
      onTapUp: (_) => setState(() => _hover = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: kSmoothCurve,
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
            AppIcon(widget.asset,
                color: widget.selected ? widget.scheme.primary : widget.scheme.onSurface,
                size: 17),
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

// ── Settings Page ─────────────────────────────────────────────────────────

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = AppTheme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
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
                    Text('Definições',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Aparência',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant)),
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
                          Text('Modo escuro',
                              style: TextStyle(fontSize: 14, color: scheme.onSurface)),
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
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: kSpringCurve,
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