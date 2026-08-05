import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// SPRING NAV (slide lateral, SEM recoil no conteúdo)
// ══════════════════════════════════════════════════════════════

class SpringNav {
  final AnimationController slideCtrl;

  SpringNav({required TickerProvider vsync})
      : slideCtrl = AnimationController.unbounded(vsync: vsync);

  static const _desc =
      SpringDescription(mass: 1, stiffness: 260, damping: 28);

  void open()  => slideCtrl.animateWith(SpringSimulation(_desc, slideCtrl.value, 0.0, 0));
  void close() => slideCtrl.animateWith(SpringSimulation(_desc, slideCtrl.value, 1.0, 0));
  void dispose() => slideCtrl.dispose();
}

// ══════════════════════════════════════════════════════════════
// CONVERSATION ITEM
// ══════════════════════════════════════════════════════════════

class ConversationItem {
  final String id, title, preview;
  const ConversationItem(
      {required this.id, required this.title, required this.preview});
}

final List<ConversationItem> conversations = [];

// ══════════════════════════════════════════════════════════════
// DRAWER
// ══════════════════════════════════════════════════════════════

class AppDrawer extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onClose;
  final VoidCallback onSettings;

  const AppDrawer({
    super.key,
    required this.s,
    required this.onClose,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: s.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(children: [
                  Text('Conversas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: s.onSurface,
                      )),
                  const Spacer(),
                  AppTap(
                    onTap: onClose, s: s, size: 32,
                    child:
                        AppIcon('close.svg', color: s.onSurfaceVariant, size: 14),
                  ),
                ]),
              ),
              Expanded(
                child: conversations.isEmpty
                    ? Center(
                        child: Text(
                          'Sem conversas ainda',
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: conversations.length,
                        itemBuilder: (_, i) =>
                            _ConvTile(s: s, item: conversations[i]),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: _AccountPill(s: s, onTap: onSettings),
              ),
            ],
          ),
        ),
      );
}

// ── Conversation tile ─────────────────────────────────────────

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  const _ConvTile({required this.s, required this.item});
  @override State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _h = true),
        onTapCancel: ()  => setState(() => _h = false),
        onTapUp:     (_) => setState(() => _h = false),
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _h ? widget.s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.item.title,
                style: TextStyle(fontSize: 14, color: widget.s.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(widget.item.preview,
                style:
                    TextStyle(fontSize: 12, color: widget.s.onSurfaceVariant),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

// ── Account pill ──────────────────────────────────────────────

class _AccountPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _AccountPill({required this.s, required this.onTap});
  @override State<_AccountPill> createState() => _AccountPillState();
}

class _AccountPillState extends State<_AccountPill> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _p = true),
        onTapCancel: ()  => setState(() => _p = false),
        onTapUp:     (_) => setState(() => _p = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _p ? widget.s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: widget.s.primary, shape: BoxShape.circle),
              child: Text('U',
                  style: TextStyle(
                      color: widget.s.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Utilizador',
                  style:
                      TextStyle(fontSize: 14, color: widget.s.onSurface),
                  overflow: TextOverflow.ellipsis),
            ),
            AppIcon('settings.svg',
                color: widget.s.onSurfaceVariant, size: 16),
          ]),
        ),
      );
}