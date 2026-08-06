import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// TABS — 4 tabs: IA | Editor | Templates | Projetos
// ══════════════════════════════════════════════════════════════

enum AppTab { ai, edit, templates, projects }

extension AppTabX on AppTab {
  String get svg       => const {
        AppTab.ai:        'ai_tab.svg',
        AppTab.edit:      'edit_tab.svg',
        AppTab.templates: 'templates.svg',
        AppTab.projects:  'projects.svg',
      }[this]!;

  String get svgFilled => const {
        AppTab.ai:        'ai_tab_filled.svg',
        AppTab.edit:      'edit_tab_filled.svg',
        AppTab.templates: 'templates_filled.svg',
        AppTab.projects:  'projects_filled.svg',
      }[this]!;

  String get label => const {
        AppTab.ai:        'IA',
        AppTab.edit:      'Editor',
        AppTab.templates: 'Templates',
        AppTab.projects:  'Projetos',
      }[this]!;
}

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
  final AppTab currentTab;
  final ValueChanged<AppTab> onSelectTab;

  const AppDrawer({
    super.key,
    required this.s,
    required this.onClose,
    required this.onSettings,
    required this.currentTab,
    required this.onSelectTab,
  });

  static const List<AppTab> _allTabs = [
    AppTab.ai,
    AppTab.edit,
    AppTab.templates,
    AppTab.projects,
  ];

  @override
  Widget build(BuildContext context) => GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -200) onClose();
        },
        child: Container(
          color: s.surface,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: s.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      for (final tab in _allTabs)
                        _DrawerTabTile(
                          s: s,
                          tab: tab,
                          selected: currentTab == tab,
                          onTap: () => onSelectTab(tab),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                  child: Text(
                    'Conversas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: s.onSurfaceVariant,
                    ),
                  ),
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
                  child: _AccountPill(s: s, onOpenSettings: onSettings),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Drawer tab tile (IA / Editor / Templates / Projetos) ───────
// Pill totalmente curvo (cápsula) quando ativo.

class _DrawerTabTile extends StatefulWidget {
  final AppColorScheme s;
  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerTabTile({
    required this.s,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_DrawerTabTile> createState() => _DrawerTabTileState();
}

class _DrawerTabTileState extends State<_DrawerTabTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s   = widget.s;
    final sel = widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: kCupertinoOut,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel
              ? s.navIndicatorBg
              : (_pressed ? s.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          sel
              ? AppIcon(widget.tab.svg,
                  color: s.onSurface, size: 20, useColorAsset: true)
              : AppIcon(widget.tab.svg, color: s.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Text(
            widget.tab.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? s.navLabelActive : s.onSurface,
            ),
          ),
        ]),
      ),
    );
  }
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
// Cápsula totalmente curva, fundo sempre visível (cardBackground).
// Sem ícone de definições: no lugar tem um botão que abre um popup
// (mesmo padrão do AiConversationMenuButton) com opções rápidas —
// alterar tema (toggle directo), definições e terminar sessão.
// Ícones exclusivamente SVG (AppIcon), nada de Icons.* Material.

class _AccountPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onOpenSettings;
  const _AccountPill({required this.s, required this.onOpenSettings});
  @override State<_AccountPill> createState() => _AccountPillState();
}

class _AccountPillState extends State<_AccountPill> {
  bool _p = false;

  void _openUserInfo() {
    // TODO: ligar aqui a navegação real para o perfil do utilizador,
    // caso venhas a querer um ecrã de perfil separado das definições.
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(999),
        boxShadow: s.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:   (_) => setState(() => _p = true),
            onTapCancel: ()  => setState(() => _p = false),
            onTapUp:     (_) => setState(() => _p = false),
            onTap: _openUserInfo,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _p ? s.hover : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: s.primary, shape: BoxShape.circle),
                  child: Text('U',
                      style: TextStyle(
                          color: s.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Utilizador',
                      style: TextStyle(fontSize: 14, color: s.onSurface),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
        ),
        _AccountQuickMenuButton(s: s, onOpenSettings: widget.onOpenSettings),
      ]),
    );
  }
}

// ── Botão que abre o popup de opções rápidas da conta ──────────
// Mesmo padrão de overlay (fade + scale) do AiConversationMenuButton
// em aitab.dart, ancorado ao próprio botão.

class _AccountQuickMenuButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onOpenSettings;
  const _AccountQuickMenuButton(
      {required this.s, required this.onOpenSettings});
  @override
  State<_AccountQuickMenuButton> createState() =>
      _AccountQuickMenuButtonState();
}

class _AccountQuickMenuButtonState extends State<_AccountQuickMenuButton>
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
          // Abre para cima do botão, já que este fica junto ao fundo
          // do drawer (perto do rodapé do ecrã).
          bottom: MediaQuery.of(ctx).size.height - off.dy + 6,
          left: off.dx + sz.width - 220,
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
                alignment: Alignment.bottomRight,
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
                  children: [
                    _AccountQuickOption(
                      s: s,
                      icon: 'theme.svg',
                      label: s.isDark ? 'Modo claro' : 'Modo escuro',
                      onTap: () { appTheme.toggleDark(); _close(); },
                    ),
                    _AccountQuickOption(
                      s: s,
                      icon: 'settings.svg',
                      label: 'Definições',
                      onTap: () { widget.onOpenSettings(); _close(); },
                    ),
                    _AccountQuickOption(
                      s: s,
                      icon: 'logout.svg',
                      label: 'Terminar sessão',
                      destructive: true,
                      onTap: () {
                        // TODO: ligar aqui a lógica real de terminar sessão.
                        _close();
                      },
                    ),
                  ],
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
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.hover,
            shape: BoxShape.circle,
          ),
          child: AppIcon('more_filled.svg',
              color: widget.s.onSurfaceVariant, size: 18),
        ),
      );
}

class _AccountQuickOption extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _AccountQuickOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  @override State<_AccountQuickOption> createState() => _AccountQuickOptionState();
}

class _AccountQuickOptionState extends State<_AccountQuickOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final color = widget.destructive ? s.error : s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _h ? s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          AppIcon(widget.icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(widget.label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.normal,
              )),
        ]),
      ),
    );
  }
}