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

class SheetsScreen extends StatefulWidget {
  const SheetsScreen({super.key});
  @override State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> with ThemeReactive<SheetsScreen> {
  static const EditorType _type = EditorType.sheets;
  InAppWebViewController? _ctrl;
  bool _aiEditing = false;

  String _documentTitle = 'Folha de cálculo';
  String? _lastSavedContent;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _restoringContent = false;

  // Ver comentário equivalente em docs.dart: adia a montagem do
  // WebView até o slide de entrada da rota terminar, para não
  // engasgar a animação de navegação.
  bool _readyForWebView = false;

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
    ctrl.evaluateJavascript(source: "editorApi.setContentFromAi('$escaped')");
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

  void _addSingleRow() => _runJs("editorApi.insertRowBelow()");
  void _addFiftyRows() => _runJs("editorApi.addMoreRows(50)");

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

  Future<String?> _getSelectedCellKey() async {
    final ctrl = _ctrl;
    if (ctrl == null) return null;
    try {
      final result = await ctrl.callAsyncJavaScript(functionBody: 'return editorApi.getSelectedCellKey();');
      final key = result?.value?.toString();
      return (key != null && key.isNotEmpty) ? key : null;
    } catch (_) { return null; }
  }

  void _onInsertChart() async {
    final cellKey = await _getSelectedCellKey();
    if (cellKey == null) return;
    final configJson = await showChartConfigDialog(context, AppTheme.of(context));
    if (configJson == null || configJson.trim().isEmpty) return;
    final safeConfig = configJson.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    _runJs("editorApi.renderCellChart('$cellKey', JSON.parse('$safeConfig'))");
  }

  void _onInsertImage() async {
    final cellKey = await _getSelectedCellKey();
    if (cellKey == null) return;
    final url = await showImageUrlDialog(context, AppTheme.of(context));
    if (url == null || url.trim().isEmpty) return;
    _runJs("editorApi.renderCellImage('$cellKey', '$url')");
  }

  void _onInsertLink() {
    showLinkSheet(context, AppTheme.of(context), (url, text) {
      _runJs("editorApi.setCellLink('$url','$text')");
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
                title: const Text('Adicionar 50 linhas'),
                onTap: () { Navigator.pop(ctx); _addFiftyRows(); },
              ),
              ListTile(
                leading: AppIcon('chart', color: s.onSurface, size: 20),
                title: const Text('Inserir gráfico'),
                onTap: () { Navigator.pop(ctx); _onInsertChart(); },
              ),
              ListTile(
                leading: AppIcon('image', color: s.onSurface, size: 20),
                title: const Text('Inserir imagem'),
                onTap: () { Navigator.pop(ctx); _onInsertImage(); },
              ),
              ListTile(
                leading: AppIcon('link', color: s.onSurface, size: 20),
                title: const Text('Inserir hiperligação'),
                onTap: () { Navigator.pop(ctx); _onInsertLink(); },
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
                              final cb = args.isNotEmpty ? args[0] as String : 'editorApi.setCellColor';
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
                            handlerName: 'onCellSelected',
                            callback: (args) {},
                          );
                        },
                        onLoadStop: (c, _) {
                          _onPendingLoad();
                          c.evaluateJavascript(source: "editorApi.setThemeMode('${s.isDark ? 'dark' : 'light'}')");
                          c.evaluateJavascript(source: "editorApi.setFontScale(${appPreferences.textScaleFactor})");
                        },
                      ),
              ),
              _ScreenHeader(
                s: s,
                title: _documentTitle,
                onUndo: _undo,
                onRedo: _redo,
                onAddRow: _addSingleRow,
                onMenu: _onOpenMenu,
              ),
              _SheetBottomToolbar(
                s: s,
                onBold: () => _runJs("editorApi.applyFormat('bold')"),
                onItalic: () => _runJs("editorApi.applyFormat('italic')"),
                onUnderline: () => _runJs("editorApi.applyFormat('underline')"),
                onAlignLeft: () => _runJs("editorApi.setCellAlign('left')"),
                onAlignCenter: () => _runJs("editorApi.setCellAlign('center')"),
                onAlignRight: () => _runJs("editorApi.setCellAlign('right')"),
                onTextColor: () => _openColorPicker(context, s, 'editorApi.setCellColor'),
                onFillColor: () => _openColorPicker(context, s, 'editorApi.setCellFill'),
                onInsertImage: _onInsertImage,
                onInsertChart: _onInsertChart,
                onInsertLink: _onInsertLink,
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
  final VoidCallback onAddRow;
  final VoidCallback onMenu;

  const _ScreenHeader({
    required this.s,
    required this.title,
    required this.onUndo,
    required this.onRedo,
    required this.onAddRow,
    required this.onMenu,
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
          _HeaderIconButton(s: s, assetName: 'undo', onTap: onUndo),
          _HeaderIconButton(s: s, assetName: 'redo', onTap: onRedo),
          const SizedBox(width: 8),
          _HeaderIconButton(s: s, assetName: 'add', onTap: onAddRow),
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

class _SheetBottomToolbar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onAlignLeft;
  final VoidCallback onAlignCenter;
  final VoidCallback onAlignRight;
  final VoidCallback onTextColor;
  final VoidCallback onFillColor;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertChart;
  final VoidCallback onInsertLink;
  final VoidCallback onAiEdit;

  const _SheetBottomToolbar({
    required this.s,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onAlignLeft,
    required this.onAlignCenter,
    required this.onAlignRight,
    required this.onTextColor,
    required this.onFillColor,
    required this.onInsertImage,
    required this.onInsertChart,
    required this.onInsertLink,
    required this.onAiEdit,
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
              _ToolbarButton(s: s, assetName: 'align_left', onTap: onAlignLeft),
              _ToolbarButton(s: s, assetName: 'align_center', onTap: onAlignCenter),
              _ToolbarButton(s: s, assetName: 'align_right', onTap: onAlignRight),
              _ToolbarButton(s: s, assetName: 'palette', onTap: onTextColor),
              _ToolbarButton(s: s, assetName: 'fill', onTap: onFillColor),
              _ToolbarButton(s: s, assetName: 'image', onTap: onInsertImage),
              _ToolbarButton(s: s, assetName: 'chart', onTap: onInsertChart),
              _ToolbarButton(s: s, assetName: 'link', onTap: onInsertLink),
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