// ══════════════════════════════════════════════════════════════
// FILE: lib/edittab.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'colors.dart';
import 'widgets.dart';
import 'sheets.dart';
import 'api_service.dart';
import 'auth_service.dart';
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

  String get svgAsset => const {
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

  String get aiDocType => const {
        EditorType.docs:       'doc',
        EditorType.sheets:     'sheet',
        EditorType.slides:     'slide',
        EditorType.whiteboard: 'whiteboard',
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
// EDIT TAB CONTROLLER
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
// EDIT TAB — dispose explícito dos WebViews adicionado. Isto é a
// correção real do cinza no drawer: sem chamar controller.dispose()
// aqui, a superfície nativa Android do Hybrid Composition podia
// sobreviver 1-2 frames depois do widget Flutter já ter sido
// removido da árvore, e nesse intervalo compunha por cima de
// QUALQUER overlay Flutter (incluindo o drawer), porque o z-order
// dessa superfície é gerido pelo sistema operativo Android, não pelo
// Stack/Positioned do Flutter. Chamar dispose() explicitamente no
// WidgetsBinding do próprio widget garante que a View nativa é
// destruída no mesmo ciclo, antes do próximo frame poder desenhar
// outra coisa por cima dela.
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

  bool _aiEditing = false;

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingLoad());
  }

  @override
  void dispose() {
    editTabController.removeListener(_onPendingLoad);
    // Dispose explícito de cada WebViewController — força o Android a
    // destruir a superfície nativa Hybrid Composition de imediato, no
    // mesmo ciclo de dispose do widget Flutter, em vez de deixar essa
    // destruição pendente para um frame futuro incerto. Isto é o que
    // impede a superfície órfã de aparecer como retângulo cinza sólido
    // por cima do drawer ou de qualquer outro overlay.
    for (final ctrl in _controllers.values) {
      try {
        ctrl?.dispose();
      } catch (_) {
        // Alguns estados internos do plugin podem já ter sido
        // limpos pelo próprio Flutter antes de chegarmos aqui —
        // ignorar é seguro, o objetivo (não sobrar superfície viva)
        // já está garantido de qualquer forma pelo dispose do
        // widget nativo em si.
      }
    }
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

  void _injectLocalCanvas(InAppWebViewController ctrl, LocalCanvasItem item) {
    _injectCanvas(ctrl, item.content);
  }

  void _runJs(String script) =>
      _controllers[widget.editorType]?.evaluateJavascript(source: script);

  void _openColorPicker(BuildContext context, AppColorScheme s, String cb) async {
    final hex = await showColorPickerSheet(context, s);
    if (hex != null) _runJs("$cb('$hex')");
  }

  Future<String> _getCurrentContent() async {
    final ctrl = _controllers[widget.editorType];
    if (ctrl == null) return '';
    try {
      final result = await ctrl.callAsyncJavaScript(functionBody: 'return editorApi.getContent();');
      return result?.value?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<String?> _getCurrentSelection() async {
    final ctrl = _controllers[widget.editorType];
    if (ctrl == null) return null;
    try {
      final result = await ctrl.callAsyncJavaScript(
        functionBody:
            'return (typeof editorApi.getSelection === "function") ? editorApi.getSelection() : "";',
      );
      final val = result?.value?.toString();
      return (val == null || val.isEmpty) ? null : val;
    } catch (_) {
      return null;
    }
  }

  void _setCurrentContent(String content) => _injectCanvas(_controllers[widget.editorType]!, content);

  Future<void> _openAiEditModal({String? preselectedText}) async {
    final s = AppTheme.of(context);
    final instruction = await showAiEditModal(context, s, hasSelection: preselectedText != null);
    if (instruction == null || instruction.trim().isEmpty) return;
    await _runAiEdit(instruction.trim(), selection: preselectedText);
  }

  Future<void> _runAiEdit(String instruction, {String? selection}) async {
    final token = authController.token;
    if (token == null || _aiEditing) return;
    setState(() => _aiEditing = true);
    try {
      final current = await _getCurrentContent();
      final updated = await AiApiService.editDocument(
        token: token,
        currentContent: current,
        instruction: instruction,
        docType: widget.editorType.aiDocType,
        selection: selection,
      );
      if (mounted && updated.trim().isNotEmpty) {
        _setCurrentContent(updated);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível aplicar a edição.')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s   = AppTheme.of(context);
    final idx = EditorType.values.indexOf(widget.editorType);

    return Stack(children: [
      IndexedStack(
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
              useHybridComposition: true,
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
              c.addJavaScriptHandler(
                handlerName: 'openAiEditForSelection',
                callback: (args) {
                  final selected = args.isNotEmpty ? args[0]?.toString() : null;
                  if (t == widget.editorType) {
                    _openAiEditModal(preselectedText: (selected != null && selected.isNotEmpty) ? selected : null);
                  }
                },
              );
            },
            onLoadStop: (c, _) => _onPendingLoad(),
          );
        }).toList(),
      ),
      Positioned(
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 84,
        child: _AiEditFab(
          s: s,
          busy: _aiEditing,
          onTap: () => _openAiEditModal(),
        ),
      ),
    ]);
  }
}

// ── FAB circular de sparkles ─────────────────────────────────────

class _AiEditFab extends StatefulWidget {
  final AppColorScheme s;
  final bool busy;
  final VoidCallback onTap;
  const _AiEditFab({required this.s, required this.busy, required this.onTap});
  @override State<_AiEditFab> createState() => _AiEditFabState();
}

class _AiEditFabState extends State<_AiEditFab> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   widget.busy ? null : (_) => setState(() => _p = true),
      onTapCancel: widget.busy ? null : ()  => setState(() => _p = false),
      onTapUp:     widget.busy ? null : (_) => setState(() => _p = false),
      onTap:       widget.busy ? null : widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 52, height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary,
            shape: BoxShape.circle,
            boxShadow: s.floatingShadow,
          ),
          child: widget.busy
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(s.onPrimary),
                  ),
                )
              : AppIcon('sparkles.svg', color: s.onPrimary, size: 22),
        ),
      ),
    );
  }
}

// ── Modal de input do FAB de sparkles ─────────────────────────────

Future<String?> showAiEditModal(
  BuildContext context,
  AppColorScheme s, {
  bool hasSelection = false,
}) {
  final ctrl = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: SheetGrabber(s: s)),
                Row(children: [
                  AppIcon('sparkles.svg', color: s.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    hasSelection ? 'Editar seleção com IA' : 'Editar documento com IA',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  hasSelection
                      ? 'Diz o que queres mudar no trecho selecionado.'
                      : 'Diz o que queres alterar — a IA aplica direto no documento.',
                  style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 1, maxLines: 4,
                  style: TextStyle(fontSize: 15, color: s.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Ex: torna este parágrafo mais formal',
                    hintStyle: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                    filled: true,
                    fillColor: s.hover,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (v) => Navigator.pop(ctx, v),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, ctrl.text),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon('sparkles.svg', color: s.onPrimary, size: 16),
                        const SizedBox(width: 8),
                        Text('Aplicar',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600, color: s.onPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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
            EditorTypeIcon(widget.type.svgAsset, size: 18),
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