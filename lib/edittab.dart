import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'colors.dart';
import 'widgets.dart';
import 'sheets.dart';
import 'api_service.dart';
import 'aitab.dart' show LocalCanvasItem, LocalCanvasKind, LocalCanvasKindX;

// ══════════════════════════════════════════════════════════════
// EDITOR TYPE ENUM
// ══════════════════════════════════════════════════════════════

enum EditorType { docs, sheets, slides, whiteboard }

extension EditorTypeX on EditorType {
  String get label => const {
        EditorType.docs:       'Documento',
        EditorType.sheets:     'Folha de cálculo',
        EditorType.slides:     'Apresentação',
        EditorType.whiteboard: 'Quadro branco',
      }[this]!;

  String get pngAsset => const {
        EditorType.docs:       'doc.png',
        EditorType.sheets:     'sheet.png',
        EditorType.slides:     'slide.png',
        EditorType.whiteboard: 'whiteboard.png',
      }[this]!;

  String get htmlAsset => const {
        EditorType.docs:       'assets/editor/docs.html',
        EditorType.sheets:     'assets/editor/sheets.html',
        EditorType.slides:     'assets/editor/slides.html',
        EditorType.whiteboard: 'assets/editor/whiteboard.html',
      }[this]!;

  static EditorType fromCanvasKind(CanvasKind k) {
    switch (k) {
      case CanvasKind.sheet: return EditorType.sheets;
      case CanvasKind.slide: return EditorType.slides;
      case CanvasKind.whiteboard: return EditorType.whiteboard;
      case CanvasKind.doc: return EditorType.docs;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// EDIT TAB CONTROLLER — agora suporta dois tipos de pedido de carga:
// o antigo CanvasItem (vindo de api_service.dart, usado noutros
// pontos da app se existirem) e o novo LocalCanvasItem (vindo da
// AiTab, que inclui também blocos de código genéricos tratados como
// "documento" — ponto 6/7 do pedido).
// ══════════════════════════════════════════════════════════════

class EditTabController extends ChangeNotifier {
  CanvasItem? _pendingLoad;
  LocalCanvasItem? _pendingLocalLoad;

  CanvasItem? get pendingLoad => _pendingLoad;
  LocalCanvasItem? get pendingLocalLoad => _pendingLocalLoad;

  void requestLoad(CanvasItem item) {
    _pendingLoad = item;
    _pendingLocalLoad = null;
    notifyListeners();
  }

  void requestLoadLocal(LocalCanvasItem item) {
    _pendingLocalLoad = item;
    _pendingLoad = null;
    notifyListeners();
  }

  void consumePendingLoad() {
    _pendingLoad = null;
  }

  void consumePendingLocalLoad() {
    _pendingLocalLoad = null;
  }
}

final EditTabController editTabController = EditTabController();

// ══════════════════════════════════════════════════════════════
// EDIT TAB
// ══════════════════════════════════════════════════════════════

class EditTab extends StatefulWidget {
  final EditorType editorType;
  const EditTab({super.key, required this.editorType});
  @override State<EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<EditTab> {
  final Map<EditorType, InAppWebViewController?> _controllers = {
    for (final t in EditorType.values) t: null,
  };

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingLoad());
  }

  @override
  void dispose() {
    editTabController.removeListener(_onPendingLoad);
    super.dispose();
  }

  void _onPendingLoad() {
    final pending = editTabController.pendingLoad;
    if (pending != null) {
      final targetType = EditorTypeX.fromCanvasKind(pending.kind);
      final ctrl = _controllers[targetType];
      if (ctrl != null) {
        _injectCanvas(ctrl, pending.content);
        editTabController.consumePendingLoad();
      }
    }

    final pendingLocal = editTabController.pendingLocalLoad;
    if (pendingLocal != null) {
      final targetType = pendingLocal.kind.editorType;
      final ctrl = _controllers[targetType];
      if (ctrl != null) {
        _injectLocalCanvas(ctrl, pendingLocal);
        editTabController.consumePendingLocalLoad();
      }
    }
  }

  void _injectCanvas(InAppWebViewController ctrl, String content) {
    final escaped = content
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');
    ctrl.evaluateJavascript(source: "editorApi.setContent('$escaped')");
  }

  /// Injeta um LocalCanvasItem no editor certo. Blocos de código
  /// (LocalCanvasKind.code) são envolvidos num <pre><code> simples
  /// antes de irem para o editor de documentos, para ficarem
  /// legíveis/monoespaçados dentro do docs.html — ponto 6/7.
  void _injectLocalCanvas(InAppWebViewController ctrl, LocalCanvasItem item) {
    String htmlContent;
    switch (item.kind) {
      case LocalCanvasKind.code:
        final escapedCode = item.content
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        htmlContent = '<pre style="font-family:monospace;white-space:pre-wrap;background:#f4f4f4;padding:12px;border-radius:8px;">$escapedCode</pre>';
        break;
      case LocalCanvasKind.doc:
        htmlContent = item.content;
        break;
      case LocalCanvasKind.sheet:
      case LocalCanvasKind.slide:
      case LocalCanvasKind.whiteboard:
        // Conteúdo JSON cru — o próprio editor (sheets.html/slides.html/
        // whiteboard.html) é responsável por interpretar via a mesma
        // editorApi.setContent, exatamente como já fazia para
        // CanvasItem.content antes desta alteração.
        htmlContent = item.content;
        break;
    }
    _injectCanvas(ctrl, htmlContent);
  }

  void _runJs(String script) =>
      _controllers[widget.editorType]?.evaluateJavascript(source: script);

  void _openColorPicker(BuildContext context, AppColorScheme s, String cb) async {
    final hex = await showColorPickerSheet(context, s);
    if (hex != null) _runJs("$cb('$hex')");
  }

  @override
  Widget build(BuildContext context) {
    final s   = AppTheme.of(context);
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
            c.addJavaScriptHandler(
              handlerName: 'openColorPicker',
              callback: (args) {
                final cb =
                    args.isNotEmpty ? args[0] as String : 'editorApi.setColor';
                _openColorPicker(context, s, cb);
              },
            );
            c.addJavaScriptHandler(
              handlerName: 'openImagePicker',
              callback: (_) {
                showImagePickerSheet(context, s);
              },
            );
            c.addJavaScriptHandler(
              handlerName: 'openLinkSheet',
              callback: (_) {
                showLinkSheet(context, s, (url, text) {
                  _runJs("editorApi.insertLink('$url','$text')");
                });
              },
            );
          },
          onLoadStop: (c, _) => _onPendingLoad(),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EDIT TYPE BUTTON (dropdown no header) — posição corrigida
// (ponto 2, mesma lógica de fallback simétrico usada em aitab.dart).
// ══════════════════════════════════════════════════════════════

class EditTypeButton extends StatefulWidget {
  final AppColorScheme s;
  final EditorType current;
  final ValueChanged<EditorType> onSelect;
  const EditTypeButton(
      {super.key, required this.s, required this.current, required this.onSelect});
  @override State<EditTypeButton> createState() => _EditTypeButtonState();
}

class _EditTypeButtonState extends State<EditTypeButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _ov;
  late AnimationController _ac;
  final GlobalKey _anchorBoxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() { _ac.dispose(); _ov?.remove(); super.dispose(); }

  void _toggle() => _ov == null ? _open() : _close();

  void _open() {
    final box = _anchorBoxKey.currentContext!.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz  = box.size;
    _ac.forward(from: 0);

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      final screenSize = MediaQuery.of(ctx).size;
      const estimatedHeight = 200.0;
      final desiredTop = off.dy + sz.height + 6;
      final overflowsBottom = desiredTop + estimatedHeight > screenSize.height - 24;
      final top = overflowsBottom ? null : desiredTop;
      final bottom = overflowsBottom ? screenSize.height - off.dy + 6 : null;
      final right = (screenSize.width - off.dx - sz.width).clamp(12.0, screenSize.width - 220 - 12);

      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: top,
          bottom: bottom,
          right: right,
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
                alignment: overflowsBottom ? Alignment.bottomRight : Alignment.topRight,
                child: child,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: s.floatingSurface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: s.floatingShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: EditorType.values
                      .map((t) => _TypeOption(
                            s: s,
                            type: t,
                            selected: widget.current == t,
                            onTap: () { widget.onSelect(t); _close(); },
                          ))
                      .toList(),
                ),
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
  Widget build(BuildContext context) => GestureDetector(
        key: _anchorBoxKey,
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: IgnorePointer(
          child: AppTap(
            onTap: () {},
            s: widget.s,
            size: 36,
            child: AppIcon('more_filled.svg', color: widget.s.onSurface, size: 20),
          ),
        ),
      );
}

class _TypeOption extends StatefulWidget {
  final AppColorScheme s;
  final EditorType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption(
      {required this.s, required this.type, required this.selected, required this.onTap});
  @override State<_TypeOption> createState() => _TypeOptionState();
}

class _TypeOptionState extends State<_TypeOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _h = true),
        onTapCancel: ()  => setState(() => _h = false),
        onTapUp:     (_) => setState(() => _h = false),
        onTap:       widget.onTap,
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