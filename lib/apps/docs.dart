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

  // Adia a montagem do WebView até a transição de entrada da rota
  // terminar. Criar a PlatformView do WebView durante o slide do
  // CupertinoPageRoute engasga o frame — por isso a navegação para
  // cá "não é suave" comparada à Settings, que não tem WebView
  // nenhum. Enquanto _readyForWebView é false, mostramos só um
  // SizedBox no lugar; assim que a rota termina de deslizar,
  // fazemos setState e o WebView entra depois do slide já parado.
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
    showTableDialog(context, AppTheme.of(context), (rows, cols) {
      _runJs("editorApi.insertTable($rows,$cols)");
    });
  }

  void _onInsertImage() async {
    final url = await showImageUrlDialog(context, AppTheme.of(context));
    if (url == null || url.trim().isEmpty) return;
    _runJs("editorApi.insertImageAtCursor('$url')");
  }

  void _onInsertLink() {
    showLinkSheet(context, AppTheme.of(context), (url, text) {
      _runJs("editorApi.insertLink('$url','$text')");
    });
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
                leading: AppIcon('table', color: s.onSurface, size: 20),
                title: const Text('Inserir tabela'),
                onTap: () { Navigator.pop(ctx); _onInsertTable(); },
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
                leading: AppIcon('shapes', color: s.onSurface, size: 20),
                title: const Text('Inserir forma'),
                onTap: () { Navigator.pop(ctx); _showShapeMenu(); },
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

  void _showShapeMenu() {
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
              ListTile(
                leading: AppIcon('rect', color: s.onSurface, size: 20),
                title: const Text('Retângulo'),
                onTap: () { Navigator.pop(ctx); _onInsertShape('rect'); },
              ),
              ListTile(
                leading: AppIcon('circle', color: s.onSurface, size: 20),
                title: const Text('Círculo'),
                onTap: () { Navigator.pop(ctx); _onInsertShape('circle'); },
              ),
              ListTile(
                leading: AppIcon('line', color: s.onSurface, size: 20),
                title: const Text('Linha'),
                onTap: () { Navigator.pop(ctx); _onInsertShape('line'); },
              ),
              ListTile(
                leading: AppIcon('arrow', color: s.onSurface, size: 20),
                title: const Text('Seta'),
                onTap: () { Navigator.pop(ctx); _onInsertShape('arrow'); },
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
                              final cb = args.isNotEmpty ? args[0] as String : 'editorApi.setColor';
                              _openColorPicker(context, s, cb);
                            },
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'openImagePicker',
                            callback: (_) => showImagePickerSheet(context, s),
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
                onMenu: _onOpenMenu,
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
                onTextColor: () => _openColorPicker(context, s, 'editorApi.setColor'),
                onHighlight: () => _openColorPicker(context, s, 'editorApi.setHighlight'),
                onInsertImage: _onInsertImage,
                onInsertTable: _onInsertTable,
                onInsertLink: _onInsertLink,
                onInsertShape: () => _showShapeMenu(),
                onInsertChart: _onInsertChart,
                onAiEdit: () => _openAiEditModal(),
                onFront: () => _runJs("editorApi.trazerParaFrente()"),
                onBack: () => _runJs("editorApi.enviarParaTras()"),
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
          // Gap adicionado entre o título com reticências e o bloco
          // de undo/redo — antes ficavam colados quando o título
          // truncava perto do limite do Expanded.
          const SizedBox(width: 12),
          // Undo/redo sem pill: cada botão solto, sem Container de
          // fundo/borda/sombra a envolvê-los.
          _HeaderIconButton(s: s, assetName: 'undo', onTap: onUndo),
          _HeaderIconButton(s: s, assetName: 'redo', onTap: onRedo),
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
  });

  @override
  Widget build(BuildContext context) {
    // Toolbar flutuante: descolada das bordas por margin lateral e
    // inferior, com bordas totalmente curvas (circular(28), não um
    // canto reto colado na tela) e floatingShadow em vez de
    // navBarShadow — a sombra pensada para elementos soltos, com
    // blur/offset maiores que a sombra plana de barra colada.
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
              _ToolbarButton(s: s, assetName: 'align_left', onTap: onAlignLeft),
              _ToolbarButton(s: s, assetName: 'align_center', onTap: onAlignCenter),
              _ToolbarButton(s: s, assetName: 'align_right', onTap: onAlignRight),
              _ToolbarButton(s: s, assetName: 'align_justify', onTap: onJustify),
              _ToolbarButton(s: s, assetName: 'bullet', onTap: onBullet),
              _ToolbarButton(s: s, assetName: 'numbered', onTap: onNumbered),
              _ToolbarButton(s: s, assetName: 'palette', onTap: onTextColor),
              _ToolbarButton(s: s, assetName: 'highlight', onTap: onHighlight),
              _ToolbarButton(s: s, assetName: 'image', onTap: onInsertImage),
              _ToolbarButton(s: s, assetName: 'table', onTap: onInsertTable),
              _ToolbarButton(s: s, assetName: 'link', onTap: onInsertLink),
              _ToolbarButton(s: s, assetName: 'shapes', onTap: onInsertShape),
              _ToolbarButton(s: s, assetName: 'chart', onTap: onInsertChart),
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

Future<void> showTableDialog(BuildContext context, AppColorScheme s, void Function(int, int) onInsert) {
  final rowsCtrl = TextEditingController(text: '2');
  final colsCtrl = TextEditingController(text: '2');
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Inserir tabela', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: rowsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Linhas'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: colsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Colunas'))),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              final r = int.tryParse(rowsCtrl.text) ?? 2;
              final c = int.tryParse(colsCtrl.text) ?? 2;
              Navigator.pop(context);
              onInsert(r, c);
            },
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