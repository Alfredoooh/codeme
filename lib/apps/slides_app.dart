// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/slides_app.dart
// ══════════════════════════════════════════════════════════════
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

Future<T?> _showAppPopupMenu<T>(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required List<PopupMenuEntry<T>> items,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox;
  final offset = box.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = box.size;
  final position = RelativeRect.fromLTRB(
    offset.dx,
    offset.dy + size.height,
    overlayBox.size.width - (offset.dx + size.width),
    overlayBox.size.height - (offset.dy + size.height),
  );
  return showMenu<T>(
    context: context,
    position: position,
    color: s.floatingSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: s.outline.withOpacity(0.25)),
    ),
    items: items,
  );
}

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

  bool _readyForWebView = false;

  final GlobalKey _moreMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
    appTheme.addListener(_pushPrimaryColorToWebView);
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

  // Menu "more" como popup
  void _openMenu() async {
    final result = await _showAppPopupMenu<int>(
      context,
      AppTheme.of(context),
      anchorKey: _moreMenuKey,
      items: [
        PopupMenuItem(value: 1, child: _buildPopupItem('add', 'Adicionar slide', false)),
        PopupMenuItem(value: 2, child: _buildPopupItem('trash', 'Excluir slide atual', true)),
        PopupMenuItem(value: 3, child: _buildPopupItem('image', 'Inserir imagem', false)),
        PopupMenuItem(value: 4, child: _buildPopupItem('chart', 'Inserir gráfico', false)),
        PopupMenuItem(value: 5, child: _buildPopupItem('sparkles', 'Editar com IA', false)),
      ],
    );
    if (result == 1) _runJs("editorApi.addSlide()");
    else if (result == 2) _runJs("editorApi.deleteCurrentSlide()");
    else if (result == 3) _onInsertImage();
    else if (result == 4) _onInsertChart();
    else if (result == 5) _openAiEditModal();
  }

  Widget _buildPopupItem(String assetName, String label, bool destructive) {
    final s = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AppIcon(assetName, size: 18, color: destructive ? s.error : s.onSurface),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 14, color: destructive ? s.error : s.onSurface)),
        ],
      ),
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
                onMenu: _openMenu,
                menuKey: _moreMenuKey,
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
          _HeaderIconButton(s: s, assetName: 'undo', onTap: onUndo),
          _HeaderIconButton(s: s, assetName: 'redo', onTap: onRedo),
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
  const _HeaderIconButton({
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