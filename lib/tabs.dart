import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'theme.dart';
import 'widgets.dart';
import 'sheets.dart';

// ══════════════════════════════════════════════════════════════
// TAB SWITCHER
// ══════════════════════════════════════════════════════════════

class TabSwitcher extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const TabSwitcher({super.key, required this.index, required this.children});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: kCupertinoOut,
        switchOutCurve: kCupertinoIn,
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(index), child: children[index]),
      );
}

// ══════════════════════════════════════════════════════════════
// CHAT TAB
// ══════════════════════════════════════════════════════════════

class ChatTab extends StatefulWidget {
  final VoidCallback onFirstMessage;
  const ChatTab({super.key, required this.onFirstMessage});
  @override State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final List<String>           _msgs  = [];

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final isFirst = _msgs.isEmpty;
    setState(() { _msgs.add(t); _ctrl.clear(); });
    if (isFirst) widget.onFirstMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: kCupertinoOut);
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(children: [
      Expanded(
        child: _msgs.isEmpty
            ? _EmptyState(s: s)
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _msgs.length,
                itemBuilder: (_, i) => _Bubble(s: s, text: _msgs[i]),
              ),
      ),
      _ChatInput(s: s, ctrl: _ctrl, onSend: _send),
      const SizedBox(height: 84),
    ]);
  }
}

// ── Empty state
class _EmptyState extends StatelessWidget {
  final AppColorScheme s;
  const _EmptyState({required this.s});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/logo.png', width: 72, height: 72, fit: BoxFit.contain),
          const SizedBox(height: 20),
          Text(
            'Torna-te mais produtivo!',
            style: TextStyle(
              // Fonte display — usa fontFamily do tema se configurado,
              // caso contrário usa fontFamilyFallback ou o sistema.
              // Para usar uma custom font basta registar em pubspec.yaml
              // e passar fontFamily: 'NomeDaFonte' aqui.
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: s.onSurface,
              letterSpacing: -0.5,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}

// ── Bolha de mensagem
class _Bubble extends StatefulWidget {
  final AppColorScheme s;
  final String text;
  const _Bubble({required this.s, required this.text});
  @override State<_Bubble> createState() => _BubbleState();
}
class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale, _op;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = Tween(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: kCupertinoOut));
    _op = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _c.forward();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Opacity(
          opacity: _op.value.clamp(0.0, 1.0),
          child: Transform.scale(
              scale: _scale.value, alignment: Alignment.centerRight, child: child),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: widget.s.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.s.cardShadow,
            ),
            child: Text(widget.text,
                style:
                    TextStyle(color: widget.s.onPrimaryContainer, fontSize: 14)),
          ),
        ),
      );
}

// ── Input do chat
class _ChatInput extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _ChatInput({required this.s, required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: ctrl,
                  minLines: 1, maxLines: 6,
                  style: TextStyle(fontSize: 15, color: s.onSurface),
                  cursorColor: s.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Escreva uma mensagem...',
                    hintStyle: TextStyle(fontSize: 15, color: s.onSurfaceVariant),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onSend,
                      child: Container(
                        width: 34, height: 34,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(color: s.primary, shape: BoxShape.circle),
                        child: AppIcon('send.svg', color: s.onPrimary, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// TEMPLATES TAB — sem mock, lista vazia
// ══════════════════════════════════════════════════════════════

class TemplatesTab extends StatelessWidget {
  const TemplatesTab({super.key});

  static const _categories = ['Todos', 'Documentos', 'Apresentações', 'Folhas', 'Quadros'];

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Text('Templates',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: s.onSurface)),
      ),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) =>
              _CategoryChip(s: s, label: _categories[i], selected: i == 0),
        ),
      ),
      const SizedBox(height: 16),
      // Lista vazia — sem mock
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.doc_text,
                size: 48, color: s.onSurfaceVariant.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text('Sem templates ainda',
                style: TextStyle(fontSize: 15, color: s.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Em breve',
                style: TextStyle(
                    fontSize: 13,
                    color: s.onSurfaceVariant.withOpacity(0.55))),
          ]),
        ),
      ),
    ]);
  }
}

class _CategoryChip extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final bool selected;
  const _CategoryChip({required this.s, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: kCupertinoOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? s.primary : s.outline.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? s.onPrimary : s.onSurfaceVariant,
            )),
      );
}

// ══════════════════════════════════════════════════════════════
// EDITOR TYPES
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
              callback: (_) => showImagePickerSheet(context, s),
            );
            c.addJavaScriptHandler(
              handlerName: 'openLinkSheet',
              callback: (_) => showLinkSheet(context, s, (url, text) {
                _runJs("editorApi.insertLink('$url','$text')");
              }),
            );
          },
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EDIT TYPE BUTTON (dropdown)
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
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
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
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
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
      {required this.s,
      required this.type,
      required this.selected,
      required this.onTap});
  @override State<_TypeOption> createState() => _TypeOptionState();
}

class _TypeOptionState extends State<_TypeOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _h = true),
        onTapCancel: () => setState(() => _h = false),
        onTapUp: (_) => setState(() => _h = false),
        onTap: widget.onTap,
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