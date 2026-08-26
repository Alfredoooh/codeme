import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../colors.dart';
import '../widgets.dart';
import '../sheets.dart';
import '../app_sheet.dart';
import '../auth_service.dart';
import 'app_types.dart';
import 'docs.dart' show ScreenBackButton;

class SlidesScreen extends StatefulWidget {
  const SlidesScreen({super.key});
  @override State<SlidesScreen> createState() => _SlidesScreenState();
}

class _SlidesScreenState extends State<SlidesScreen> with ThemeReactive<SlidesScreen> {
  static const EditorType _type = EditorType.slides;
  InAppWebViewController? _ctrl;
  bool _aiEditing = false;

  String _documentTitle = 'Apresentação';
  String? _lastSavedContent;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _restoringContent = false;

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
    // ThemeReactive já ouve appTheme para o setState() geral (rebuild
    // dos widgets Flutter). Este segundo listener é só para empurrar
    // a cor para dentro do WebView, que não faz parte da árvore de
    // widgets e por isso não é atualizado pelo rebuild do ThemeReactive.
    appTheme.addListener(_pushPrimaryColorToWebView);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingLoad());
  }

  @override
  void dispose() {
    editTabController.removeListener(_onPendingLoad);
    appTheme.removeListener(_pushPrimaryColorToWebView);
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
    ctrl.evaluateJavascript(source: "editorApi.setContentFromAi('$escaped')");
  }

  void _resetHistory(String content) {
    _undoStack.clear();
    _redoStack.clear();
    _lastSavedContent = content;
    _restoringContent = false;
  }

  void _runJs(String script) => _ctrl?.evaluateJavascript(source: script);

  // Manda a cor primária atual (já formatada como #RRGGBB por
  // AppColorScheme.primaryColorHex) para dentro do editor. Chamado
  // no onLoadStop (primeira carga) e sempre que appTheme notifica
  // (o utilizador mudou a cor em Definições > Personalização).
  void _pushPrimaryColorToWebView() {
    final s = AppTheme.of(context);
    _runJs("editorApi.setPrimaryColor('${s.primaryColorHex}')");
  }

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
      _redoStack.add(_lastSavedContent ?? '{}');
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
      _undoStack.add(_lastSavedContent ?? '{}');
      final next = _redoStack.removeLast();
      _lastSavedContent = next;
      _restoringContent = true;
      final escaped = next.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
      _runJs("editorApi.setContent('$escaped')");
      Future.delayed(const Duration(milliseconds: 50), () => _restoringContent = false);
    });
  }

  void _openColorPicker(BuildContext context, AppColorScheme s, String cb) async {
    final hex = await showColorPickerSheet(context, s);
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

  void _onInsertImage() async {
    final url = await showImageUrlDialog(context, AppTheme.of(context));
    if (url == null || url.trim().isEmpty) return;
    _runJs("editorApi.insertImage('$url')");
  }

  void _onInsertShape(String shapeKind) {
    showColorPickerSheet(context, AppTheme.of(context)).then((hex) {
      if (hex != null) _runJs("editorApi.insertShape('$shapeKind','$hex')");
    });
  }

  void _onInsertChart() {
    showChartConfigDialog(context, AppTheme.of(context)).then((json) {
      if (json != null && json.trim().isNotEmpty) {
        final safe = json.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
        _runJs("editorApi.insertChart(JSON.parse('$safe'))");
      }
    });
  }

  void _onOpenMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final s = AppTheme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: s.outline.withOpacity(0.4), borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: AppIcon('add', color: s.onSurface, size: 20),
                title: const Text('Adicionar slide'),
                onTap: () { Navigator.pop(ctx); _runJs("editorApi.addSlide()"); },
              ),
              ListTile(
                leading: AppIcon('trash', color: s.error, size: 20),
                title: const Text('Excluir slide atual'),
                onTap: () { Navigator.pop(ctx); _runJs("editorApi.deleteCurrentSlide()"); },
              ),
              ListTile(
                leading: AppIcon('image', color: s.onSurface, size: 20),
                title: const Text('Inserir imagem'),
                onTap: () { Navigator.pop(ctx); _onInsertImage(); },
              ),
              ListTile(
                leading: AppIcon('chart', color: s.onSurface, size: 20),
                title: const Text('Inserir gráfico'),
                onTap: () { Navigator.pop(ctx); _onInsertChart(); },
              ),
              ListTile(
                leading: AppIcon('sparkles', color: s.onSurface, size: 20),
                title: const Text('Editar com IA'),
                onTap: () { Navigator.pop(ctx); _openAiEditModal(); },
              ),
            ],
          ),
        );
      },
    );
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
                child: kIsWeb ? const SizedBox.shrink() : InAppWebView(
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
                        final cb = args.isNotEmpty ? args[0] as String : 'editorApi.setSelectedTextColor';
                        _openColorPicker(context, s, cb);
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
                      handlerName: 'onElementSelected',
                      callback: (args) {},
                    );
                    c.addJavaScriptHandler(
                      handlerName: 'openImagePicker',
                      callback: (_) => showImagePickerSheet(context, s),
                    );
                    c.addJavaScriptHandler(
                      handlerName: 'openAiEditForSelection',
                      callback: (args) {
                        final selected = args.isNotEmpty ? args[0]?.toString() : null;
                        _openAiEditModal(preselectedText: (selected != null && selected.isNotEmpty) ? selected : null);
                      },
                    );
                  },
                  onLoadStop: (c, _) {
                    _onPendingLoad();
                    c.evaluateJavascript(source: "editorApi.setThemeMode('${s.isDark ? 'dark' : 'light'}')");
                    c.evaluateJavascript(source: "editorApi.setPrimaryColor('${s.primaryColorHex}')");
                  },
                ),
              ),
              _ScreenHeader(
                s: s,
                title: _documentTitle,
                onUndo: _undo,
                onRedo: _redo,
                onMenu: _onOpenMenu,
              ),
              _SlidesBottomToolbar(
                s: s,
                onAddSlide: () => _runJs("editorApi.addSlide()"),
                onDeleteSlide: () => _runJs("editorApi.deleteCurrentSlide()"),
                onInsertText: () => _runJs("editorApi.insertTextBox()"),
                onInsertImage: _onInsertImage,
                onInsertShape: () => _onInsertShape('rect'),
                onInsertCircle: () => _onInsertShape('circle'),
                onInsertChart: _onInsertChart,
                onDeleteElement: () => _runJs("editorApi.deleteSelectedElement()"),
                onBold: () => _runJs("editorApi.applyTextFormat('bold')"),
                onItalic: () => _runJs("editorApi.applyTextFormat('italic')"),
                onUnderline: () => _runJs("editorApi.applyTextFormat('underline')"),
                onTextColor: () => _openColorPicker(context, s, 'editorApi.setSelectedTextColor'),
                onShapeColor: () => _openColorPicker(context, s, 'editorApi.setSelectedShapeColor'),
                onFontSize: (px) => _runJs("editorApi.setSelectedFontSize($px)"),
                onAiEdit: () => _openAiEditModal(),
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
  const _ScreenHeader({required this.s, required this.title, required this.onUndo, required this.onRedo, required this.onMenu});

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
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: s.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: s.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderIconButton(s: s, assetName: 'undo', onTap: onUndo),
                Container(width: 1, height: 20, color: s.outline),
                _HeaderIconButton(s: s, assetName: 'redo', onTap: onRedo),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(s: s, assetName: 'more_vert', onTap: onMenu),
        ]),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.s, required this.assetName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: s.cardBackground, shape: BoxShape.circle, boxShadow: s.cardShadow),
        child: AppIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

class _SlidesBottomToolbar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onAddSlide;
  final VoidCallback onDeleteSlide;
  final VoidCallback onInsertText;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertShape;
  final VoidCallback onInsertCircle;
  final VoidCallback onInsertChart;
  final VoidCallback onDeleteElement;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onTextColor;
  final VoidCallback onShapeColor;
  final ValueChanged<double> onFontSize;
  final VoidCallback onAiEdit;

  const _SlidesBottomToolbar({
    required this.s,
    required this.onAddSlide,
    required this.onDeleteSlide,
    required this.onInsertText,
    required this.onInsertImage,
    required this.onInsertShape,
    required this.onInsertCircle,
    required this.onInsertChart,
    required this.onDeleteElement,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onTextColor,
    required this.onShapeColor,
    required this.onFontSize,
    required this.onAiEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: s.cardBackground, boxShadow: s.navBarShadow),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ToolbarButton(s: s, assetName: 'add', onTap: onAddSlide),
              _ToolbarButton(s: s, assetName: 'trash', onTap: onDeleteSlide),
              _ToolbarButton(s: s, assetName: 'text', onTap: onInsertText),
              _ToolbarButton(s: s, assetName: 'image', onTap: onInsertImage),
              _ToolbarButton(s: s, assetName: 'rect', onTap: onInsertShape),
              _ToolbarButton(s: s, assetName: 'circle', onTap: onInsertCircle),
              _ToolbarButton(s: s, assetName: 'chart', onTap: onInsertChart),
              _ToolbarButton(s: s, assetName: 'trash_element', onTap: onDeleteElement),
              _ToolbarButton(s: s, assetName: 'bold', onTap: onBold),
              _ToolbarButton(s: s, assetName: 'italic', onTap: onItalic),
              _ToolbarButton(s: s, assetName: 'underline', onTap: onUnderline),
              _ToolbarButton(s: s, assetName: 'palette', onTap: onTextColor),
              _ToolbarButton(s: s, assetName: 'fill', onTap: onShapeColor),
              _ToolbarButton(s: s, assetName: 'sparkles', onTap: onAiEdit),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  const _ToolbarButton({required this.s, required this.assetName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        child: AppIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

Future<String?> showImageUrlDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('URL da imagem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'https://')),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context, ctrl.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Inserir', style: TextStyle(color: s.onPrimary)),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<String?> showChartConfigDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Configuração do gráfico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: '{"type":"bar",...}')),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context, ctrl.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Inserir', style: TextStyle(color: s.onPrimary)),
            ),
          ),
        ],
      ),
    ),
  );
}