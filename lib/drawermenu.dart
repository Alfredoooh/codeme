import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'api_service.dart';

// ══════════════════════════════════════════════════════════════
// TABS
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
// SPRING NAV
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
// CONVERSATION ITEM — agora espelha o payload real do worker
// (id, title, messages, pinned, archived, updatedAt).
// ══════════════════════════════════════════════════════════════

class ConversationItem {
  final String id;
  final String title;
  final String preview;
  final bool pinned;
  final bool archived;
  final int updatedAt;

  const ConversationItem({
    required this.id,
    required this.title,
    required this.preview,
    this.pinned = false,
    this.archived = false,
    this.updatedAt = 0,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> j) {
    String preview = '';
    final messages = j['messages'];
    if (messages is List && messages.isNotEmpty) {
      final last = messages.last;
      if (last is Map) preview = last['content']?.toString() ?? '';
    }
    return ConversationItem(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Nova conversa',
      preview: preview,
      pinned: j['pinned'] == true,
      archived: j['archived'] == true,
      updatedAt: (j['updatedAt'] is num) ? (j['updatedAt'] as num).toInt() : 0,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CONVERSATIONS CONTROLLER — carrega/gere a lista real via API,
// notifica o drawer quando muda (nova conversa criada no chat,
// eliminação, pin, etc.)
// ══════════════════════════════════════════════════════════════

class ConversationsController extends ChangeNotifier {
  List<ConversationItem> items = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    final token = authController.token;
    if (token == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final raw = await ConversationsApiService.list(token);
      items = raw.map((j) => ConversationItem.fromJson(j)).toList();
    } catch (_) {
      error = 'Não foi possível carregar as conversas';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> togglePin(String id, bool pinned) async {
    final token = authController.token;
    if (token == null) return;
    final idx = items.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = items[idx];
    items[idx] = ConversationItem(
      id: old.id, title: old.title, preview: old.preview,
      pinned: pinned, archived: old.archived, updatedAt: old.updatedAt,
    );
    notifyListeners();
    await ConversationsApiService.pin(token, id, pinned);
  }

  Future<void> delete(String id) async {
    final token = authController.token;
    if (token == null) return;
    items.removeWhere((c) => c.id == id);
    notifyListeners();
    await ConversationsApiService.delete(token, id);
  }

  void upsertLocal(ConversationItem item) {
    final idx = items.indexWhere((c) => c.id == item.id);
    if (idx == -1) {
      items.insert(0, item);
    } else {
      items[idx] = item;
    }
    notifyListeners();
  }
}

final ConversationsController conversationsController = ConversationsController();

// ══════════════════════════════════════════════════════════════
// DRAWER
// ══════════════════════════════════════════════════════════════

class AppDrawer extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final AppTab currentTab;
  final ValueChanged<AppTab> onSelectTab;
  final ValueChanged<String>? onOpenConversation;
  final VoidCallback? onNewChat;

  const AppDrawer({
    super.key,
    required this.s,
    required this.onClose,
    required this.onSettings,
    required this.currentTab,
    required this.onSelectTab,
    this.onOpenConversation,
    this.onNewChat,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static const List<AppTab> _allTabs = [
    AppTab.ai,
    AppTab.edit,
    AppTab.templates,
    AppTab.projects,
  ];

  @override
  void initState() {
    super.initState();
    conversationsController.addListener(_onConvsChanged);
    if (conversationsController.items.isEmpty && !conversationsController.loading) {
      conversationsController.load();
    }
  }

  @override
  void dispose() {
    conversationsController.removeListener(_onConvsChanged);
    super.dispose();
  }

  void _onConvsChanged() { if (mounted) setState(() {}); }

  void _confirmDelete(BuildContext context, ConversationItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _DeleteConversationSheet(
        s: widget.s,
        title: item.title,
        onConfirm: () {
          Navigator.pop(ctx);
          conversationsController.delete(item.id);
        },
      ),
    );
  }

  void _openConvOptions(BuildContext context, ConversationItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConversationOptionsSheet(
        s: widget.s,
        item: item,
        onTogglePin: () {
          Navigator.pop(ctx);
          conversationsController.togglePin(item.id, !item.pinned);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDelete(context, item);
        },
        onOpen: () {
          Navigator.pop(ctx);
          widget.onOpenConversation?.call(item.id);
          widget.onClose();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final pinned = conversationsController.items.where((c) => c.pinned).toList();
    final others = conversationsController.items.where((c) => !c.pinned).toList();

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -200) widget.onClose();
      },
      child: Container(
        color: s.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: s.onSurface,
                      ),
                    ),
                    AppTap(
                      onTap: () {
                        widget.onNewChat?.call();
                        widget.onClose();
                      },
                      s: s,
                      child: AppIcon('new_chat.svg', color: s.onSurfaceVariant, size: 20),
                    ),
                  ],
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
                        selected: widget.currentTab == tab,
                        onTap: () => widget.onSelectTab(tab),
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
                child: _buildConvBody(s, pinned, others),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: _AccountPill(s: s, onOpenSettings: widget.onSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConvBody(
    AppColorScheme s,
    List<ConversationItem> pinned,
    List<ConversationItem> others,
  ) {
    if (conversationsController.loading && conversationsController.items.isEmpty) {
      return Center(
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant),
          ),
        ),
      );
    }
    if (conversationsController.error != null && conversationsController.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            conversationsController.error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
          ),
        ),
      );
    }
    if (pinned.isEmpty && others.isEmpty) {
      return Center(
        child: Text(
          'Sem conversas ainda',
          style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Row(children: [
              AppIcon('pin.svg', color: s.onSurfaceVariant, size: 13),
              const SizedBox(width: 6),
              Text('Fixadas',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.onSurfaceVariant)),
            ]),
          ),
          for (final item in pinned)
            _ConvTile(
              s: s,
              item: item,
              onTap: () {
                widget.onOpenConversation?.call(item.id);
                widget.onClose();
              },
              onLongPress: () => _openConvOptions(context, item),
            ),
          const SizedBox(height: 8),
        ],
        for (final item in others)
          _ConvTile(
            s: s,
            item: item,
            onTap: () {
              widget.onOpenConversation?.call(item.id);
              widget.onClose();
            },
            onLongPress: () => _openConvOptions(context, item),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Drawer tab tile ───────────────────────────────────────────

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
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ConvTile({
    required this.s,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });
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
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _h ? widget.s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.item.title,
                    style: TextStyle(fontSize: 14, color: widget.s.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (widget.item.preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(widget.item.preview,
                      style:
                          TextStyle(fontSize: 12, color: widget.s.onSurfaceVariant),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            if (widget.item.pinned) ...[
              const SizedBox(width: 6),
              AppIcon('pin.svg', color: widget.s.onSurfaceVariant, size: 13),
            ],
          ]),
        ),
      );
}

// ── Sheet de opções de uma conversa (fixar / eliminar) ─────────

class _ConversationOptionsSheet extends StatelessWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onOpen;
  const _ConversationOptionsSheet({
    required this.s,
    required this.item,
    required this.onTogglePin,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: SheetGrabber(s: s)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: s.onSurfaceVariant)),
                ),
                const SizedBox(height: 8),
                SheetOptionsGroup(s: s, options: [
                  _SheetOption(
                    s: s,
                    icon: 'send.svg',
                    label: 'Abrir conversa',
                    onTap: onOpen,
                  ),
                  _SheetOption(
                    s: s,
                    icon: 'pin.svg',
                    label: item.pinned ? 'Desafixar' : 'Fixar',
                    onTap: onTogglePin,
                  ),
                  _SheetOption(
                    s: s,
                    icon: 'trash.svg',
                    label: 'Eliminar',
                    destructive: true,
                    onTap: onDelete,
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}

class _SheetOption extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _SheetOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  @override State<_SheetOption> createState() => _SheetOptionState();
}

class _SheetOptionState extends State<_SheetOption> {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: _h ? s.hover : Colors.transparent,
        child: Row(children: [
          AppIcon(widget.icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(widget.label, style: TextStyle(fontSize: 15, color: color)),
        ]),
      ),
    );
  }
}

// ── Confirmação de eliminação ───────────────────────────────

class _DeleteConversationSheet extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onConfirm;
  const _DeleteConversationSheet({
    required this.s,
    required this.title,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: SheetGrabber(s: s)),
                Text(
                  'Eliminar "$title"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: s.onSurface),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: _SheetActionButton(
                      s: s,
                      label: 'Cancelar',
                      filled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetActionButton(
                      s: s,
                      label: 'Eliminar',
                      filled: true,
                      onTap: onConfirm,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}

class _SheetActionButton extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _SheetActionButton(
      {required this.s,
      required this.label,
      required this.filled,
      required this.onTap});
  @override State<_SheetActionButton> createState() => _SheetActionButtonState();
}

class _SheetActionButtonState extends State<_SheetActionButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? s.error : s.hover,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.filled ? s.onError : s.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Account pill — agora com dados reais do authController ─────

class _AccountPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onOpenSettings;
  const _AccountPill({required this.s, required this.onOpenSettings});
  @override State<_AccountPill> createState() => _AccountPillState();
}

class _AccountPillState extends State<_AccountPill> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final user = authController.user;
    final name = user?.name ?? 'Utilizador';
    final avatar = user?.avatar;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

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
            onTap: widget.onOpenSettings,
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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: s.primary, shape: BoxShape.circle),
                  child: (avatar != null && avatar.isNotEmpty)
                      ? Image.memory(
                          _decodeAvatar(avatar),
                          width: 32, height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(initial,
                              style: TextStyle(
                                  color: s.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        )
                      : Text(initial,
                          style: TextStyle(
                              color: s.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
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

Uint8List _decodeAvatar(String raw) {
  final commaIdx = raw.indexOf(',');
  final b64 = raw.startsWith('data:') && commaIdx != -1
      ? raw.substring(commaIdx + 1)
      : raw;
  return base64Decode(b64);
}

// ── Botão que abre o popup de opções rápidas da conta ──────────

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
                  color: s.floatingSurface,
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
                        _close();
                        authController.logout();
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