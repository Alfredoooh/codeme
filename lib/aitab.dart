import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// AI TAB
// ══════════════════════════════════════════════════════════════

class AiTab extends StatefulWidget {
  final VoidCallback onFirstMessage;
  const AiTab({super.key, required this.onFirstMessage});
  @override State<AiTab> createState() => _AiTabState();
}

enum QuickAction { doc, sheet, slide, whiteboard }

extension QuickActionX on QuickAction {
  String get asset => const {
        QuickAction.doc:        'doc.png',
        QuickAction.sheet:      'sheet.png',
        QuickAction.slide:      'slide.png',
        QuickAction.whiteboard: 'whiteboard.png',
      }[this]!;

  String get label => const {
        QuickAction.doc:        'Criar documento Word',
        QuickAction.sheet:      'Criar folha de cálculo',
        QuickAction.slide:      'Criar apresentação',
        QuickAction.whiteboard: 'Criar com o canvas',
      }[this]!;

  Color get tint => const {
        QuickAction.doc:        Color(0xFF2B579A), // azul Word
        QuickAction.sheet:      Color(0xFF217346), // verde Excel
        QuickAction.slide:      Color(0xFFD24726), // laranja/vermelho PowerPoint
        QuickAction.whiteboard: Color(0xFFE1306C), // vermelho/rosa
      }[this]!;
}

class _AiTabState extends State<AiTab> {
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

  void _onQuickAction(QuickAction action) {
    // TODO: liga aqui a acção real de cada toggle (abrir editor, etc.)
  }

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(children: [
      Expanded(
        child: _msgs.isEmpty
            ? _EmptyState(s: s, onQuickAction: _onQuickAction)
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

// ── Empty state — apenas os toggles, sem logo nem saudação ─────

class _EmptyState extends StatelessWidget {
  final AppColorScheme s;
  final ValueChanged<QuickAction> onQuickAction;
  const _EmptyState({required this.s, required this.onQuickAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: QuickAction.values
                .map((a) => _QuickActionChip(
                      s: s,
                      action: a,
                      onTap: () => onQuickAction(a),
                    ))
                .toList(),
          ),
        ),
      );
}

// ── Toggle individual (chip com ícone + label) ──────────────────

class _QuickActionChip extends StatefulWidget {
  final AppColorScheme s;
  final QuickAction action;
  final VoidCallback onTap;
  const _QuickActionChip({
    required this.s,
    required this.action,
    required this.onTap,
  });

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.action.tint.withOpacity(s.isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/png/${widget.action.asset}',
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              Text(
                widget.action.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.action.tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bolha de mensagem ─────────────────────────────────────────

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
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0, 0.5, curve: Curves.easeOut)));
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
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: widget.s.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.s.cardShadow,
            ),
            child: Text(widget.text,
                style: TextStyle(
                    color: widget.s.onPrimaryContainer, fontSize: 14)),
          ),
        ),
      );
}

// ── Chat input ────────────────────────────────────────────────

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
                    hintText: 'Escreve uma mensagem...',
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
                        decoration: BoxDecoration(
                            color: s.primary, shape: BoxShape.circle),
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