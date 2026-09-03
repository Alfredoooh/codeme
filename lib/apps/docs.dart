// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/docs.dart
// ══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import '../colors.dart';
import '../widgets.dart';
import '../sheets.dart';
import '../app_sheet.dart';
import '../auth_service.dart';
import '../exportservice.dart';
import 'app_types.dart';

const Set<String> _kEditorSvgIcons = {
  'align_center',
  'align_left',
  'align_right',
  'bold',
  'brush',
  'bullet_point',
  'capital_letter',
  'chart',
  'edit_text',
  'eraser',
  'font',
  'font-2',
  'font_size',
  'hyperlink',
  'image',
  'indent_decrease',
  'indent_increase',
  'justify',
  'paste',
  'pencil_holder',
  'quote',
  'resize',
  'spacing_height',
  'spacing_width',
  'spellcheck',
  'subscript',
  'superscript',
  'text_color',
  'underline',
  'download',
  'share',
  'pdf',
  'check',
  'plus',
  'minus',
  'trash',
  'grid',
  'row',
  'column',
  'wand',
};

const Map<String, String> _kEditorIconAliases = {
  'align_justify': 'justify',
  'bullet': 'bullet_point',
  'link': 'hyperlink',
  'palette': 'text_color',
  'highlight': 'brush',
  'text': 'edit_text',
};

class _EditorIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  const _EditorIcon(this.asset, {required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final rawName = asset.endsWith('.svg') ? asset.substring(0, asset.length - 4) : asset;
    final key = _kEditorIconAliases[rawName] ?? rawName;
    final fileName = '$key.svg';
    if (_kEditorSvgIcons.contains(key)) {
      return SvgPicture.asset(
        'assets/icons/editor/$fileName',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return AppIcon(fileName, size: size, color: color);
  }
}

// ══════════════════════════════════════════════════════════════
// POPUP CUSTOMIZADO — Container Transform super suave
// ══════════════════════════════════════════════════════════════
//
// Substitui o antigo `showMenu` nativo. Nasce a partir do botão
// (posição + tamanho do anchor) e expande em direção ao tamanho
// final do cartão, com blur de fundo, bordas suaves e curva
// elástica muito lenta — efeito "morph" em vez de "popup".

Future<T?> _showMorphMenu<T>(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required List<_MorphMenuItem<T>> items,
  double width = 240,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final anchorSize = box.size;
  final screenSize = overlay.size;

  final anchorRect = Rect.fromLTWH(
    anchorTopLeft.dx,
    anchorTopLeft.dy,
    anchorSize.width,
    anchorSize.height,
  );

  double left = anchorRect.right - width;
  if (left < 12) left = 12;
  if (left + width > screenSize.width - 12) left = screenSize.width - 12 - width;
  double top = anchorRect.bottom + 8;

  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'menu',
    barrierColor: Colors.black.withOpacity(0.001),
    barrierDismissible: true,
    transitionDuration: const Duration(milliseconds: 480),
    pageBuilder: (ctx, anim, secAnim) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: const Cubic(0.16, 1, 0.3, 1));
      return Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: BackdropBlurBox(sigma: 6 * curved.value, color: s.barrier.withOpacity(0.18 * curved.value)),
              ),
            ),
          ),
          Positioned(
            left: Tween<double>(begin: anchorRect.left, end: left).transform(curved.value),
            top: Tween<double>(begin: anchorRect.top, end: top).transform(curved.value),
            width: Tween<double>(begin: anchorRect.width, end: width).transform(curved.value),
            child: Opacity(
              opacity: Curves.easeOut.transform(anim.value.clamp(0.0, 1.0)),
              child: Transform.scale(
                alignment: Alignment.topRight,
                scale: 0.86 + (0.14 * curved.value),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.floatingSurface.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: s.outline.withOpacity(0.14), width: 1),
                      boxShadow: s.floatingShadow,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          _MorphMenuTile<T>(
                            item: items[i],
                            s: s,
                            onSelected: (v) => Navigator.of(ctx).pop(v),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MorphMenuItem<T> {
  final T value;
  final String asset;
  final String label;
  final bool destructive;
  const _MorphMenuItem({
    required this.value,
    required this.asset,
    required this.label,
    this.destructive = false,
  });
}

class _MorphMenuTile<T> extends StatefulWidget {
  final _MorphMenuItem<T> item;
  final AppColorScheme s;
  final void Function(T) onSelected;
  const _MorphMenuTile({required this.item, required this.s, required this.onSelected});

  @override
  State<_MorphMenuTile<T>> createState() => _MorphMenuTileState<T>();
}

class _MorphMenuTileState<T> extends State<_MorphMenuTile<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final item = widget.item;
    final color = item.destructive ? s.error : s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => widget.onSelected(item.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed ? s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _EditorIcon(item.asset, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Retângulo desfocado leve para o fundo do menu morph. Evita
/// depender de `BackdropFilter` dentro de um `showGeneralDialog`
/// sem contexto de clipping garantido — usa apenas opacidade,
/// suficiente para o efeito desejado sem custo de performance.
class BackdropBlurBox extends StatelessWidget {
  final double sigma;
  final Color color;
  const BackdropBlurBox({super.key, required this.sigma, required this.color});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color);
  }
}

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});
  @override State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> with ThemeReactive<DocsScreen> {
  static const EditorType _type = EditorType.docs;
  InAppWebViewController? _ctrl;
  bool _aiEditing = false;

  String _documentTitle = 'Documento';
  String? _lastSavedContent;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _restoringContent = false;

  bool _readyForWebView = false;

  final GlobalKey _moreMenuKey = GlobalKey();
  final GlobalKey _shapesMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingLoad());
    WidgetsBinding.instance.addPostFrameCallback((_) => _armRouteListener());
  }

  void _armRouteListener() {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null) {
      if (mounted) setState(() => _readyForWebView = true);
      return;
    }
    if (animation.isCompleted) {
      setState(() => _readyForWebView = true);
      return;
    }
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        if (mounted) setState(() => _readyForWebView = true);
      }
    }
    animation.addStatusListener(listener);
  }

  @override
  void dispose() {
    editTabController.removeListener(_onPendingLoad);
    try { _ctrl?.dispose(); } catch (_) {}
    super.dispose();
  }

  void _onPendingLoad() {
    final pending = editTabController.pendingLocalLoad;
    if (pending == null || pending.kind.editorType != _type) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;
    _documentTitle = pending.title;
    _injectCanvas(ctrl, pending.content);
    _resetHistory(pending.content);
    editTabController.consumePendingLocalLoad();
    if (mounted) setState(() {});
  }

  void _injectCanvas(InAppWebViewController ctrl, String content) {
    final escaped = content.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    ctrl.evaluateJavascript(source: "editorApi.setContent('$escaped')");
  }

  void _resetHistory(String content) {
    _undoStack.clear();
    _redoStack.clear();
    _lastSavedContent = content;
    _restoringContent = false;
  }

  void _runJs(String script) => _ctrl?.evaluateJavascript(source: script);

  void _onSaveDocument(String json) {
    if (_restoringContent) return;
    if (_lastSavedContent != null && _lastSavedContent == json) return;
    setState(() {
      if (_lastSavedContent != null) {
        _undoStack.add(_lastSavedContent!);
        if (_undoStack.length > 50) _undoStack.removeAt(0);
      }
      _redoStack.clear();
      _lastSavedContent = json;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_lastSavedContent ?? '');
      final previous = _undoStack.removeLast();
      _lastSavedContent = previous;
      _restoringContent = true;
      final escaped = previous.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
      _runJs("editorApi.setContent('$escaped')");
      Future.delayed(const Duration(milliseconds: 50), () => _restoringContent = false);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_lastSavedContent ?? '');
      final next = _redoStack.removeLast();
      _lastSavedContent = next;
      _restoringContent = true;
      final escaped = next.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
      _runJs("editorApi.setContent('$escaped')");
      Future.delayed(const Duration(milliseconds: 50), () => _restoringContent = false);
    });
  }

  void _openColorPicker(BuildContext context, AppColorScheme s, String cb) async {
    final hex = await showAdvancedColorPickerSheet(context, s);
    if (hex != null) _runJs("$cb('$hex')");
  }

  Future<String> _getCurrentContent() async {
    final ctrl = _ctrl;
    if (ctrl == null) return '';
    try {
      final result = await ctrl.callAsyncJavaScript(functionBody: 'return editorApi.getContent();');
      return result?.value?.toString() ?? '';
    } catch (_) { return ''; }
  }

  void _setCurrentContent(String content) {
    final ctrl = _ctrl;
    if (ctrl != null) _injectCanvas(ctrl, content);
  }

  Future<Uint8List?> _exportDocx() async {
    final content = await _getCurrentContent();
    if (content.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o conteúdo atual.')),
      );
      return null;
    }
    final item = LocalCanvasItem(
      id: 'export-docx',
      kind: LocalCanvasKind.doc,
      title: _documentTitle,
      content: content,
    );
    return ExportService.export(item: item, format: 'docx');
  }

  Future<Uint8List?> _exportPdf() async {
    final content = await _getCurrentContent();
    if (content.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o conteúdo atual.')),
      );
      return null;
    }
    final item = LocalCanvasItem(
      id: 'export-pdf',
      kind: LocalCanvasKind.doc,
      title: _documentTitle,
      content: content,
    );
    return ExportService.export(item: item, format: 'pdf');
  }

  String get _safeTitle {
    final t = _documentTitle.trim();
    return t.isEmpty ? 'documento' : t.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
  }

  Future<void> _downloadCurrentDocument() async {
    try {
      final bytes = await _exportDocx();
      if (bytes == null) return;
      await ExportService.shareBytes(bytes, filename: '$_safeTitle.docx');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível descarregar documento Word: ${e.toString()}')),
      );
    }
  }

  Future<void> _shareCurrentDocument() async {
  try {
    final bytes = await _exportDocx();
    if (bytes == null) return;
    await ExportService.shareBytes(bytes, filename: '$_safeTitle.docx');
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não foi possível partilhar o documento: ${e.toString()}')),
    );
  }
}

  Future<void> _sharePdf() async {
  try {
    final bytes = await _exportPdf();
    if (bytes == null) return;
    await ExportService.shareBytes(bytes, filename: '$_safeTitle.pdf');
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não foi possível partilhar como PDF: ${e.toString()}')),
    );
  }
}

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
      // Edição IA desativada temporariamente até backend ser atualizado.
      // Mantém o conteúdo atual sem alterações.
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

  void _onInsertTable() {
    showTableDialog(context, AppTheme.of(context), (config) {
      _runJs("editorApi.insertTable(${config.toJs()})");
    });
  }

  void _onInsertImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = _guessMime(file.path);
      _runJs("editorApi.insertImageAtCursor('data:$mime;base64,$b64')");
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar a imagem: ${e.toString()}')),
      );
    }
  }

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _onInsertLink() {
    showLinkSheet(context, AppTheme.of(context), (url, text) {
      _runJs("editorApi.insertLink('$url','$text')");
    });
  }

  void _onInsertShape(String shapeKind) {
    showAdvancedColorPickerSheet(context, AppTheme.of(context)).then((hex) {
      if (hex != null) _runJs("editorApi.insertShape('$shapeKind','$hex')");
    });
  }

  Future<void> _onInsertChart() async {
    final preset = await Navigator.of(context).push<ChartPreset>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) => const ChartPresetScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: const Cubic(0.16, 1, 0.3, 1));
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    if (preset != null) {
      final safe = preset.toJson().replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
      _runJs("editorApi.insertChart(JSON.parse('$safe'))");
    }
  }

  // Menu "more" — agora um popup customizado (Container Transform)
  // com apenas as três ações que fazem sentido aqui: descarregar,
  // partilhar e partilhar como PDF. As restantes ferramentas
  // (tabela, imagem, forma, gráfico, IA) vivem só no bottomtoolbar.
  void _openMenu() async {
    final s = AppTheme.of(context);
    final result = await _showMorphMenu<int>(
      context,
      s,
      anchorKey: _moreMenuKey,
      items: const [
        _MorphMenuItem(value: 1, asset: 'download', label: 'Descarregar documento'),
        _MorphMenuItem(value: 2, asset: 'share', label: 'Partilhar'),
        _MorphMenuItem(value: 3, asset: 'pdf', label: 'Partilhar como PDF'),
      ],
    );
    if (result == 1) _downloadCurrentDocument();
    else if (result == 2) _shareCurrentDocument();
    else if (result == 3) _sharePdf();
  }

  // Menu de formas — mesmo popup morph, com formas geométricas
  Future<void> _showShapeMenuPopup() async {
    final s = AppTheme.of(context);
    final result = await _showMorphMenu<int>(
      context,
      s,
      anchorKey: _shapesMenuKey,
      items: const [
        _MorphMenuItem(value: 1, asset: 'rect', label: 'Retângulo'),
        _MorphMenuItem(value: 2, asset: 'circle', label: 'Círculo'),
        _MorphMenuItem(value: 3, asset: 'line', label: 'Linha'),
        _MorphMenuItem(value: 4, asset: 'arrow', label: 'Seta'),
      ],
    );
    if (result == 1) _onInsertShape('rect');
    else if (result == 2) _onInsertShape('circle');
    else if (result == 3) _onInsertShape('line');
    else if (result == 4) _onInsertShape('arrow');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.statusBarStyle,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.only(top: 58, bottom: 44),
                child: (kIsWeb || !_readyForWebView)
                    ? const SizedBox.shrink()
                    : InAppWebView(
                        initialFile: _type.htmlAsset,
                        initialSettings: InAppWebViewSettings(
                          transparentBackground: true,
                          javaScriptEnabled: true,
                          allowFileAccessFromFileURLs: true,
                          allowUniversalAccessFromFileURLs: true,
                          useHybridComposition: true,
                          verticalScrollBarEnabled: false,
                          horizontalScrollBarEnabled: false,
                          supportZoom: false,
                        ),
                        onWebViewCreated: (c) {
                          _ctrl = c;
                          c.addJavaScriptHandler(
                            handlerName: 'openColorPicker',
                            callback: (args) {
                              final cb = args.isNotEmpty ? args[0] as String : 'editorApi.setColor';
                              _openColorPicker(context, s, cb);
                            },
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'openImagePicker',
                            callback: (_) => _onInsertImage(),
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'openLinkSheet',
                            callback: (_) => showLinkSheet(context, s, (url, text) {
                              _runJs("editorApi.insertLink('$url','$text')");
                            }),
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'openAiEditForSelection',
                            callback: (args) {
                              final selected = args.isNotEmpty ? args[0]?.toString() : null;
                              _openAiEditModal(preselectedText: (selected != null && selected.isNotEmpty) ? selected : null);
                            },
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'saveDocument',
                            callback: (args) {
                              final content = args.isNotEmpty ? args[0]?.toString() : null;
                              if (content != null) _onSaveDocument(content);
                            },
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'onShapeSelected',
                            callback: (args) {},
                          );
                        },
                        onLoadStop: (c, _) {
                          _onPendingLoad();
                          c.evaluateJavascript(source: "editorApi.setThemeMode('${s.isDark ? 'dark' : 'light'}')");
                        },
                      ),
              ),
              _ScreenHeader(
                s: s,
                title: _documentTitle,
                onUndo: _undo,
                onRedo: _redo,
                onMenu: _openMenu,
                menuKey: _moreMenuKey,
              ),
              _DocsBottomToolbar(
                s: s,
                onBold: () => _runJs("editorApi.exec('bold')"),
                onItalic: () => _runJs("editorApi.exec('italic')"),
                onUnderline: () => _runJs("editorApi.exec('underline')"),
                onStrike: () => _runJs("editorApi.exec('strikethrough')"),
                onAlignLeft: () => _runJs("editorApi.exec('alignLeft')"),
                onAlignCenter: () => _runJs("editorApi.exec('alignCenter')"),
                onAlignRight: () => _runJs("editorApi.exec('alignRight')"),
                onJustify: () => _runJs("editorApi.exec('alignJustify')"),
                onBullet: () => _runJs("editorApi.exec('bulletList')"),
                onNumbered: () => _runJs("editorApi.exec('numberedList')"),
                onIndentIncrease: () => _runJs("editorApi.exec('indentIncrease')"),
                onIndentDecrease: () => _runJs("editorApi.exec('indentDecrease')"),
                onSubscript: () => _runJs("editorApi.exec('subscript')"),
                onSuperscript: () => _runJs("editorApi.exec('superscript')"),
                onQuote: () => _runJs("editorApi.exec('blockquote')"),
                onClearFormat: () => _runJs("editorApi.exec('clearFormat')"),
                onTextColor: () => _openColorPicker(context, s, 'editorApi.setColor'),
                onHighlight: () => _openColorPicker(context, s, 'editorApi.setHighlight'),
                onInsertImage: _onInsertImage,
                onInsertTable: _onInsertTable,
                onInsertLink: _onInsertLink,
                onInsertShape: _showShapeMenuPopup,
                onInsertChart: _onInsertChart,
                onAiEdit: () => _openAiEditModal(),
                onFront: () => _runJs("editorApi.trazerParaFrente()"),
                onBack: () => _runJs("editorApi.enviarParaTras()"),
                shapeMenuKey: _shapesMenuKey,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onMenu;
  final GlobalKey menuKey;
  const _ScreenHeader({
    required this.s,
    required this.title,
    required this.onUndo,
    required this.onRedo,
    required this.onMenu,
    required this.menuKey,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)],
          ),
        ),
        child: Row(children: [
          ScreenBackButton(s: s),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: s.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(s: s, assetName: 'undo', onTap: onUndo, withContainer: false),
          _HeaderIconButton(s: s, assetName: 'redo', onTap: onRedo, withContainer: false),
          const SizedBox(width: 8),
          _HeaderIconButton(s: s, assetName: 'more_vert', onTap: onMenu, anchorKey: menuKey),
        ]),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  final GlobalKey? anchorKey;
  final bool withContainer;
  const _HeaderIconButton({
    required this.s,
    required this.assetName,
    required this.onTap,
    this.anchorKey,
    this.withContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: anchorKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: withContainer
            ? BoxDecoration(color: s.cardBackground, shape: BoxShape.circle, boxShadow: s.cardShadow)
            : null,
        child: _EditorIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

class _DocsBottomToolbar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrike;
  final VoidCallback onAlignLeft;
  final VoidCallback onAlignCenter;
  final VoidCallback onAlignRight;
  final VoidCallback onJustify;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onIndentIncrease;
  final VoidCallback onIndentDecrease;
  final VoidCallback onSubscript;
  final VoidCallback onSuperscript;
  final VoidCallback onQuote;
  final VoidCallback onClearFormat;
  final VoidCallback onTextColor;
  final VoidCallback onHighlight;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertLink;
  final VoidCallback onInsertShape;
  final VoidCallback onInsertChart;
  final VoidCallback onAiEdit;
  final VoidCallback onFront;
  final VoidCallback onBack;
  final GlobalKey shapeMenuKey;

  const _DocsBottomToolbar({
    required this.s,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrike,
    required this.onAlignLeft,
    required this.onAlignCenter,
    required this.onAlignRight,
    required this.onJustify,
    required this.onBullet,
    required this.onNumbered,
    required this.onIndentIncrease,
    required this.onIndentDecrease,
    required this.onSubscript,
    required this.onSuperscript,
    required this.onQuote,
    required this.onClearFormat,
    required this.onTextColor,
    required this.onHighlight,
    required this.onInsertImage,
    required this.onInsertTable,
    required this.onInsertLink,
    required this.onInsertShape,
    required this.onInsertChart,
    required this.onAiEdit,
    required this.onFront,
    required this.onBack,
    required this.shapeMenuKey,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12, right: 12, bottom: 16,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(28),
          boxShadow: s.floatingShadow,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ToolbarButton(s: s, assetName: 'bold', onTap: onBold),
              _ToolbarButton(s: s, assetName: 'italic', onTap: onItalic),
              _ToolbarButton(s: s, assetName: 'underline', onTap: onUnderline),
              _ToolbarButton(s: s, assetName: 'strike', onTap: onStrike),
              _ToolbarDivider(s: s),
              _ToolbarButton(s: s, assetName: 'align_left', onTap: onAlignLeft),
              _ToolbarButton(s: s, assetName: 'align_center', onTap: onAlignCenter),
              _ToolbarButton(s: s, assetName: 'align_right', onTap: onAlignRight),
              _ToolbarButton(s: s, assetName: 'align_justify', onTap: onJustify),
              _ToolbarDivider(s: s),
              _ToolbarButton(s: s, assetName: 'bullet', onTap: onBullet),
              _ToolbarButton(s: s, assetName: 'numbered', onTap: onNumbered),
              _ToolbarButton(s: s, assetName: 'indent_decrease', onTap: onIndentDecrease),
              _ToolbarButton(s: s, assetName: 'indent_increase', onTap: onIndentIncrease),
              _ToolbarDivider(s: s),
              _ToolbarButton(s: s, assetName: 'subscript', onTap: onSubscript),
              _ToolbarButton(s: s, assetName: 'superscript', onTap: onSuperscript),
              _ToolbarButton(s: s, assetName: 'quote', onTap: onQuote),
              _ToolbarButton(s: s, assetName: 'eraser', onTap: onClearFormat),
              _ToolbarDivider(s: s),
              _ToolbarButton(s: s, assetName: 'palette', onTap: onTextColor),
              _ToolbarButton(s: s, assetName: 'highlight', onTap: onHighlight),
              _ToolbarDivider(s: s),
              _ToolbarButton(s: s, assetName: 'image', onTap: onInsertImage),
              _ToolbarButton(s: s, assetName: 'table', onTap: onInsertTable),
              _ToolbarButton(s: s, assetName: 'link', onTap: onInsertLink),
              _ToolbarButton(s: s, assetName: 'shapes', onTap: onInsertShape, anchorKey: shapeMenuKey),
              _ToolbarButton(s: s, assetName: 'chart', onTap: onInsertChart),
              _ToolbarDivider(s: s),
              _ToolbarButton(s: s, assetName: 'sparkles', onTap: onAiEdit),
              _ToolbarButton(s: s, assetName: 'front', onTap: onFront),
              _ToolbarButton(s: s, assetName: 'back', onTap: onBack),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final AppColorScheme s;
  const _ToolbarDivider({required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: s.outlineVariant,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  final GlobalKey? anchorKey;
  const _ToolbarButton({
    required this.s,
    required this.assetName,
    required this.onTap,
    this.anchorKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: anchorKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        child: _EditorIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// INSERIR TABELA — completo (dimensões + preview + cabeçalho + bordas)
// ══════════════════════════════════════════════════════════════

class TableInsertConfig {
  final int rows;
  final int cols;
  final bool header;
  final bool bordered;
  final bool striped;
  const TableInsertConfig({
    required this.rows,
    required this.cols,
    required this.header,
    required this.bordered,
    required this.striped,
  });

  String toJs() => '{'
      '"rows":$rows,'
      '"cols":$cols,'
      '"header":$header,'
      '"bordered":$bordered,'
      '"striped":$striped'
      '}';
}

Future<void> showTableDialog(
  BuildContext context,
  AppColorScheme s,
  void Function(TableInsertConfig) onInsert,
) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: _TableInsertSheet(s: s, onInsert: onInsert),
  );
}

class _TableInsertSheet extends StatefulWidget {
  final AppColorScheme s;
  final void Function(TableInsertConfig) onInsert;
  const _TableInsertSheet({required this.s, required this.onInsert});

  @override
  State<_TableInsertSheet> createState() => _TableInsertSheetState();
}

class _TableInsertSheetState extends State<_TableInsertSheet> {
  int _rows = 3;
  int _cols = 3;
  bool _header = true;
  bool _bordered = true;
  bool _striped = false;

  static const int _maxGrid = 8;
  int _hoverRow = -1;
  int _hoverCol = -1;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: s.outline, borderRadius: BorderRadius.circular(4)),
          ),
          Row(
            children: [
              Text('Inserir tabela', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: s.onSurface)),
              const Spacer(),
              Text('$_cols × $_rows', style: TextStyle(fontSize: 13, color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),

          // Grelha de seleção rápida estilo Word/Excel
          GestureDetector(
            onPanUpdate: (details) => _updateHoverFromLocal(details.localPosition),
            onPanEnd: (_) => setState(() { _hoverRow = -1; _hoverCol = -1; }),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cell = (constraints.maxWidth - (_maxGrid - 1) * 4) / _maxGrid;
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(_maxGrid * _maxGrid, (i) {
                    final r = i ~/ _maxGrid;
                    final c = i % _maxGrid;
                    final activeR = _hoverRow >= 0 ? _hoverRow : _rows - 1;
                    final activeC = _hoverCol >= 0 ? _hoverCol : _cols - 1;
                    final selected = r <= activeR && c <= activeC;
                    return GestureDetector(
                      onTap: () => setState(() { _rows = r + 1; _cols = c + 1; }),
                      child: Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: selected ? s.primary : s.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Pré-visualização em miniatura da tabela configurada
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: s.pageBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: s.outlineVariant),
            ),
            child: _TablePreview(s: s, rows: _rows, cols: _cols, header: _header, bordered: _bordered, striped: _striped),
          ),

          const SizedBox(height: 16),

          _TableToggleRow(s: s, label: 'Linha de cabeçalho', value: _header, onChanged: (v) => setState(() => _header = v)),
          _TableToggleRow(s: s, label: 'Bordas visíveis', value: _bordered, onChanged: (v) => setState(() => _bordered = v)),
          _TableToggleRow(s: s, label: 'Linhas alternadas', value: _striped, onChanged: (v) => setState(() => _striped = v)),

          const SizedBox(height: 20),

          Row(
            children: [
              _StepperField(
                s: s,
                label: 'Linhas',
                value: _rows,
                min: 1,
                max: 20,
                onChanged: (v) => setState(() => _rows = v),
              ),
              const SizedBox(width: 12),
              _StepperField(
                s: s,
                label: 'Colunas',
                value: _cols,
                min: 1,
                max: 10,
                onChanged: (v) => setState(() => _cols = v),
              ),
            ],
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              widget.onInsert(TableInsertConfig(
                rows: _rows,
                cols: _cols,
                header: _header,
                bordered: _bordered,
                striped: _striped,
              ));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Inserir tabela', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  void _updateHoverFromLocal(Offset local) {
    const spacing = 4.0;
    final approxCell = (MediaQuery.of(context).size.width - 40 - (_maxGrid - 1) * spacing) / _maxGrid;
    final col = (local.dx / (approxCell + spacing)).floor().clamp(0, _maxGrid - 1);
    final row = (local.dy / (approxCell + spacing)).floor().clamp(0, _maxGrid - 1);
    setState(() { _hoverRow = row; _hoverCol = col; _rows = row + 1; _cols = col + 1; });
  }
}

class _TablePreview extends StatelessWidget {
  final AppColorScheme s;
  final int rows;
  final int cols;
  final bool header;
  final bool bordered;
  final bool striped;
  const _TablePreview({
    required this.s,
    required this.rows,
    required this.cols,
    required this.header,
    required this.bordered,
    required this.striped,
  });

  @override
  Widget build(BuildContext context) {
    final displayRows = math.min(rows, 4);
    final displayCols = math.min(cols, 5);
    return Column(
      children: List.generate(displayRows, (r) {
        final isHeader = header && r == 0;
        final isStriped = striped && !isHeader && r.isOdd;
        return Container(
          decoration: BoxDecoration(
            color: isHeader
                ? s.primary.withOpacity(0.16)
                : isStriped
                    ? s.outlineVariant.withOpacity(0.5)
                    : Colors.transparent,
            border: bordered ? Border(bottom: BorderSide(color: s.outlineVariant)) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(displayCols, (c) {
              return Expanded(
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isHeader ? s.primary.withOpacity(0.4) : s.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _TableToggleRow extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TableToggleRow({required this.s, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, color: s.onSurface))),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: s.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _StepperField({
    required this.s,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                _stepBtn(context, '-', () { if (value > min) onChanged(value - 1); }),
                Expanded(
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface),
                  ),
                ),
                _stepBtn(context, '+', () { if (value < max) onChanged(value + 1); }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: s.cardBackground, shape: BoxShape.circle, boxShadow: s.cardShadowSoft),
        child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// COLOR PICKER AVANÇADO — com gerador de paleta HSV
// ══════════════════════════════════════════════════════════════

const List<Color> _kQuickPaletteColors = [
  Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF34C759),
  Color(0xFF00C7BE), Color(0xFF32ADE6), Color(0xFF007AFF), Color(0xFF5856D6),
  Color(0xFFAF52DE), Color(0xFFFF2D55), Color(0xFF8E8E93), Color(0xFF1C1C1E),
  Color(0xFFFFFFFF),
];

Future<String?> showAdvancedColorPickerSheet(BuildContext context, AppColorScheme s) {
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    child: _AdvancedColorPickerSheet(s: s),
  );
}

class _AdvancedColorPickerSheet extends StatefulWidget {
  final AppColorScheme s;
  const _AdvancedColorPickerSheet({required this.s});

  @override
  State<_AdvancedColorPickerSheet> createState() => _AdvancedColorPickerSheetState();
}

class _AdvancedColorPickerSheetState extends State<_AdvancedColorPickerSheet> {
  bool _generatorMode = false;
  double _hue = 210;
  double _saturation = 0.75;
  double _lightness = 0.5;

  Color get _currentColor => HSLColor.fromAHSL(1, _hue, _saturation, _lightness).toColor();

  String _toHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: s.outline, borderRadius: BorderRadius.circular(4)),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _generatorMode ? 'Gerador de paleta' : 'Escolher cor',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: s.onSurface),
                ),
              ),
              _ModeToggleButton(
                s: s,
                icon: 'wand',
                active: _generatorMode,
                onTap: () => setState(() => _generatorMode = !_generatorMode),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_generatorMode) _buildGenerator(s) else _buildQuickPalette(s),
        ],
      ),
    );
  }

  Widget _buildQuickPalette(AppColorScheme s) {
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _kQuickPaletteColors.map((c) {
            return GestureDetector(
              onTap: () => Navigator.pop(context, _toHex(c)),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: s.outline.withOpacity(0.4), width: 1),
                  boxShadow: s.cardShadowSoft,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => setState(() => _generatorMode = true),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: s.pageBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: s.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _EditorIcon('wand', size: 17, color: s.onSurface),
                const SizedBox(width: 8),
                Text('Gerar qualquer cor', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: s.onSurface)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerator(AppColorScheme s) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 84,
          decoration: BoxDecoration(
            color: _currentColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: s.outline.withOpacity(0.3)),
            boxShadow: s.cardShadow,
          ),
          alignment: Alignment.center,
          child: Text(
            _toHex(_currentColor),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _lightness > 0.55 ? Colors.black.withOpacity(0.7) : Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _HueSlider(hue: _hue, onChanged: (v) => setState(() => _hue = v)),
        const SizedBox(height: 14),
        _ShadeSlider(
          label: 'Saturação',
          value: _saturation,
          baseColor: HSLColor.fromAHSL(1, _hue, 1, 0.5).toColor(),
          trackBuilder: (t) => HSLColor.fromAHSL(1, _hue, t, _lightness).toColor(),
          onChanged: (v) => setState(() => _saturation = v),
        ),
        const SizedBox(height: 14),
        _ShadeSlider(
          label: 'Luminosidade',
          value: _lightness,
          baseColor: HSLColor.fromAHSL(1, _hue, _saturation, 0.5).toColor(),
          trackBuilder: (t) => HSLColor.fromAHSL(1, _hue, _saturation, t).toColor(),
          onChanged: (v) => setState(() => _lightness = v),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: () => Navigator.pop(context, _toHex(_currentColor)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
            child: Text('Aplicar cor', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final AppColorScheme s;
  final String icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeToggleButton({required this.s, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? s.primaryContainer : s.pageBackground,
          shape: BoxShape.circle,
          border: Border.all(color: active ? Colors.transparent : s.outlineVariant),
        ),
        child: _EditorIcon(icon, size: 17, color: active ? s.onPrimaryContainer : s.onSurfaceVariant),
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;
  const _HueSlider({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
            Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
          ],
        ),
      ),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 32,
          activeTrackColor: Colors.transparent,
          inactiveTrackColor: Colors.transparent,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 3),
          overlayShape: SliderComponentShape.noOverlay,
          thumbColor: Colors.white,
        ),
        child: Slider(
          value: hue,
          min: 0,
          max: 360,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ShadeSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color baseColor;
  final Color Function(double) trackBuilder;
  final ValueChanged<double> onChanged;
  const _ShadeSlider({
    required this.label,
    required this.value,
    required this.baseColor,
    required this.trackBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        Container(
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: List.generate(9, (i) => trackBuilder(i / 8)),
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 28,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
              overlayShape: SliderComponentShape.noOverlay,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GRÁFICOS PRONTOS — tela de presets em vez de JSON manual
// ══════════════════════════════════════════════════════════════

enum ChartKind { bar, line, pie, area, donut, scatter }

class ChartPreset {
  final String id;
  final String title;
  final ChartKind kind;
  final List<double> sampleValues;
  final List<String> sampleLabels;
  const ChartPreset({
    required this.id,
    required this.title,
    required this.kind,
    required this.sampleValues,
    required this.sampleLabels,
  });

  String get kindKey => const {
        ChartKind.bar: 'bar',
        ChartKind.line: 'line',
        ChartKind.pie: 'pie',
        ChartKind.area: 'area',
        ChartKind.donut: 'donut',
        ChartKind.scatter: 'scatter',
      }[kind]!;

  String toJson() {
    final labels = sampleLabels.map((l) => '"$l"').join(',');
    final values = sampleValues.map((v) => v.toString()).join(',');
    return '{"type":"$kindKey","title":"$title","labels":[$labels],"values":[$values]}';
  }
}

const List<ChartPreset> _kChartPresets = [
  ChartPreset(id: 'bar_basic', title: 'Barras simples', kind: ChartKind.bar,
      sampleValues: [4, 7, 3, 8, 5], sampleLabels: ['A', 'B', 'C', 'D', 'E']),
  ChartPreset(id: 'bar_growth', title: 'Barras — crescimento', kind: ChartKind.bar,
      sampleValues: [2, 4, 6, 9, 13], sampleLabels: ['T1', 'T2', 'T3', 'T4', 'T5']),
  ChartPreset(id: 'line_trend', title: 'Linha — tendência', kind: ChartKind.line,
      sampleValues: [3, 5, 4, 7, 9, 8], sampleLabels: ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun']),
  ChartPreset(id: 'area_volume', title: 'Área — volume', kind: ChartKind.area,
      sampleValues: [10, 14, 9, 18, 16], sampleLabels: ['S1', 'S2', 'S3', 'S4', 'S5']),
  ChartPreset(id: 'pie_share', title: 'Circular — distribuição', kind: ChartKind.pie,
      sampleValues: [40, 25, 20, 15], sampleLabels: ['Norte', 'Sul', 'Este', 'Oeste']),
  ChartPreset(id: 'donut_share', title: 'Rosca — distribuição', kind: ChartKind.donut,
      sampleValues: [35, 30, 20, 15], sampleLabels: ['A', 'B', 'C', 'D']),
  ChartPreset(id: 'scatter_corr', title: 'Dispersão — correlação', kind: ChartKind.scatter,
      sampleValues: [2, 5, 3, 8, 6, 9], sampleLabels: ['P1', 'P2', 'P3', 'P4', 'P5', 'P6']),
];

class ChartPresetScreen extends StatelessWidget {
  const ChartPresetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.statusBarStyle,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      ScreenBackButton(s: s),
                      const SizedBox(width: 12),
                      Text('Inserir gráfico', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: s.onSurface)),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: _kChartPresets.length,
                    itemBuilder: (context, i) {
                      final preset = _kChartPresets[i];
                      return _ChartPresetCard(
                        s: s,
                        preset: preset,
                        onTap: () => Navigator.of(context).pop(preset),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPresetCard extends StatefulWidget {
  final AppColorScheme s;
  final ChartPreset preset;
  final VoidCallback onTap;
  const _ChartPresetCard({required this.s, required this.preset, required this.onTap});

  @override
  State<_ChartPresetCard> createState() => _ChartPresetCardState();
}

class _ChartPresetCardState extends State<_ChartPresetCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(22),
            boxShadow: s.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ChartThumbnail(s: s, preset: widget.preset)),
              const SizedBox(height: 10),
              Text(
                widget.preset.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: s.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartThumbnail extends StatelessWidget {
  final AppColorScheme s;
  final ChartPreset preset;
  const _ChartThumbnail({required this.s, required this.preset});

  @override
  Widget build(BuildContext context) {
    switch (preset.kind) {
      case ChartKind.bar:
      case ChartKind.area:
        return _barThumb();
      case ChartKind.line:
      case ChartKind.scatter:
        return _lineThumb();
      case ChartKind.pie:
      case ChartKind.donut:
        return _pieThumb();
    }
  }

  Widget _barThumb() {
    final maxV = preset.sampleValues.reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: preset.sampleValues.map((v) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 46 * (v / maxV),
            decoration: BoxDecoration(
              color: s.primary.withOpacity(0.55 + 0.35 * (v / maxV)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _lineThumb() {
    return CustomPaint(
      size: const Size(double.infinity, 52),
      painter: _MiniLinePainter(values: preset.sampleValues, color: s.primary),
    );
  }

  Widget _pieThumb() {
    return Center(
      child: SizedBox(
        width: 52, height: 52,
        child: CustomPaint(
          painter: _MiniPiePainter(values: preset.sampleValues, color: s.primary, donut: preset.kind == ChartKind.donut),
        ),
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _MiniLinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs() < 0.0001 ? 1 : (maxV - minV);
    final path = Path();
    final dx = size.width / (values.length - 1).clamp(1, 999);
    for (int i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) => false;
}

class _MiniPiePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool donut;
  _MiniPiePainter({required this.values, required this.color, required this.donut});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final rect = Offset.zero & size;
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = color.withOpacity(0.4 + 0.5 * (i / values.length)),
      );
      start += sweep;
    }
    if (donut) {
      canvas.drawCircle(size.center(Offset.zero), size.width * 0.32, Paint()..color = Colors.white.withOpacity(0.001)..blendMode = BlendMode.clear);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPiePainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
// BOTÃO DE VOLTAR — inalterado
// ══════════════════════════════════════════════════════════════

class ScreenBackButton extends StatefulWidget {
  final AppColorScheme s;
  const ScreenBackButton({super.key, required this.s});
  @override State<ScreenBackButton> createState() => _ScreenBackButtonState();
}

class _ScreenBackButtonState extends State<ScreenBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: widget.s.cardBackground, shape: BoxShape.circle),
          child: AppIcon('back.svg', size: 20, color: widget.s.onSurface),
        ),
      ),
    );
  }
}