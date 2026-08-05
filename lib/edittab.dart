import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'colors.dart';
import 'widgets.dart';
import 'sheets.dart';

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
}

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
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EDIT TYPE BUTTON (dropdown no header)
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
    final box = context.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz  = box.size;
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
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
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
  Widget build(BuildContext context) => AppTap(
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