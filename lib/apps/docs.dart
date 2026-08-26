// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/docs.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../colors.dart';
import '../widgets.dart';
import '../sheets.dart';
import '../api_service.dart';
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

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingLoad());
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
    _injectCanvas(ctrl, pending.content);
    editTabController.consumePendingLocalLoad();
  }

  void _injectCanvas(InAppWebViewController ctrl, String content) {
    final escaped = content.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    ctrl.evaluateJavascript(source: "editorApi.setContent('$escaped')");
  }

  void _runJs(String script) => _ctrl?.evaluateJavascript(source: script);

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
      final current = await _getCurrentContent();
      final updated = await AiApiService.editDocument(
        token: token, currentContent: current, instruction: instruction,
        docType: _type.aiDocType, selection: selection,
      );
      if (mounted && updated.trim().isNotEmpty) _setCurrentContent(updated);
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
                padding: const EdgeInsets.only(top: 58),
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
                  },
                  onLoadStop: (c, _) => _onPendingLoad(),
                ),
              ),
              _ScreenHeader(s: s, title: _type.label),
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
  const _ScreenHeader({required this.s, required this.title});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)],
          ),
        ),
        child: Row(children: [
          ScreenBackButton(s: s),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: s.onSurface)),
        ]),
      ),
    );
  }
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
          child: AppIcon('chevron_left.svg', size: 20, color: widget.s.onSurface),
        ),
      ),
    );
  }
}