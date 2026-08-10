// ══════════════════════════════════════════════════════════════
// FILE: lib/drawermenu.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'chat_search.dart';

// ══════════════════════════════════════════════════════════════
// TABS
// ══════════════════════════════════════════════════════════════

enum AppTab { ai, edit }

extension AppTabX on AppTab {
  String get svg       => const {
        AppTab.ai:   'ai_tab.svg',
        AppTab.edit: 'edit_tab.svg',
      }[this]!;

  String get svgFilled => const {
        AppTab.ai:   'ai_tab_filled.svg',
        AppTab.edit: 'edit_tab_filled.svg',
      }[this]!;

  String get label => const {
        AppTab.ai:   'IA',
        AppTab.edit: 'Editor',
      }[this]!;
}

// ══════════════════════════════════════════════════════════════
// CONVERSATION ITEM
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
// CONVERSATIONS CONTROLLER
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

  Future<void> archive(String id, bool archived) async {
    final token = authController.token;
    if (token == null) return;
    final idx = items.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = items[idx];
    items[idx] = ConversationItem(
      id: old.id, title: old.title, preview: old.preview,
      pinned: old.pinned, archived: archived, updatedAt: old.updatedAt,
    );
    notifyListeners();
    await ConversationsApiService.archive(token, id, archived);
  }

  Future<void> rename(String id, String newTitle) async {
    final token = authController.token;
    if (token == null) return;
    final idx = items.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = items[idx];
    items[idx] = ConversationItem(
      id: old.id, title: newTitle, preview: old.preview,
      pinned: old.pinned, archived: old.archived, updatedAt: old.updatedAt,
    );
    notifyListeners();
    await ConversationsApiService.rename(token, id, newTitle);
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
// DRAWER — deixou de ser o Drawer nativo do Flutter (Scaffold.drawer).
// Passa a ser um Material puro: largura, slide horizontal, clip dos
// cantos arredondados e o barrier por trás do drawer são geridos pelo
// Stack manual em main.dart (RootShell), com um AnimationController
// próprio. Este widget fica sempre montado na árvore, mesmo fechado —
// só desliza para fora da tela via Transform.translate — nunca é
// destruído/recriado ao reabrir.
// ══════════════════════════════════════════════════════════════

class AppDrawer extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final VoidCallback onGoHome;
  final AppTab currentTab;
  final ValueChanged<AppTab> onSelectTab;
  final ValueChanged<String>? onOpenConversation;
  final VoidCallback? onNewChat;
  final String? activeConversationId;

  const AppDrawer({
    super.key,
    required this.s,
    required this.onClose,
    required this.onSettings,
    required this.onGoHome,
    required this.currentTab,
    required this.onSelectTab,
    this.onOpenConversation,
    this.onNewChat,
    this.activeConversationId,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static const List<AppTab> _navigableTabs = [
    AppTab.ai,
    AppTab.edit,
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

  void _openSearch(BuildContext context) {
    widget.onClose();
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => ChatSearchScreen(
        s: widget.s,
        onOpenConversation: (id) {
          widget.onOpenConversation?.call(id);
        },
      ),
    ));
  }

  void _goHome() {
    widget.onClose();
    widget.onGoHome();
  }

  void _openConversation(ConversationItem item) {
    widget.onOpenConversation?.call(item.id);
    widget.onClose();
  }

  void _openConvPopup(BuildContext context, GlobalKey anchorKey, ConversationItem item) {
    showConversationOptionsPopup(
      context,
      widget.s,
      anchorKey: anchorKey,
      item: item,
      onOpen: () => _openConversation(item),
      onTogglePin: () => conversationsController.togglePin(item.id, !item.pinned),
      onArchive: () => conversationsController.archive(item.id, !item.archived),
      onRename: () => _openRenamePopup(context, item),
      onDelete: () => _confirmDeletePopup(context, anchorKey, item),
    );
  }

  void _openRenamePopup(BuildContext context, ConversationItem item) {
    showRenameSheet(
      context,
      widget.s,
      currentTitle: item.title,
      onConfirm: (newTitle) => conversationsController.rename(item.id, newTitle),
    );
  }

  void _confirmDeletePopup(BuildContext context, GlobalKey anchorKey, ConversationItem item) {
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

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final pinned = conversationsController.items.where((c) => c.pinned && !c.archived).toList();
    final others = conversationsController.items.where((c) => !c.pinned && !c.archived).toList();

    return Material(
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
                  Row(children: [
                    AppTap(
                      onTap: () => _openSearch(context),
                      s: s,
                      size: 32,
                      child: AppIcon('search.svg', color: s.onSurfaceVariant, size: 16),
                    ),
                    const SizedBox(width: 2),
                    AppTap(
                      onTap: _goHome,
                      s: s,
                      size: 32,
                      child: AppIcon('home.svg', color: s.onSurfaceVariant, size: 17),
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  for (final tab in _navigableTabs)
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
              active: item.id == widget.activeConversationId,
              onTap: () => _openConversation(item),
              onOptions: (key) => _openConvPopup(context, key, item),
              onArchive: () => conversationsController.archive(item.id, true),
              onDelete: () => conversationsController.delete(item.id),
            ),
          const SizedBox(height: 8),
        ],
        for (final item in others)
          _ConvTile(
            s: s,
            item: item,
            active: item.id == widget.activeConversationId,
            onTap: () => _openConversation(item),
            onOptions: (key) => _openConvPopup(context, key, item),
            onArchive: () => conversationsController.archive(item.id, true),
            onDelete: () => conversationsController.delete(item.id),
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
          AppIcon(
            sel ? widget.tab.svgFilled : widget.tab.svg,
            color: sel ? s.navLabelActive : s.onSurfaceVariant,
            size: 20,
          ),
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

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<GlobalKey> onOptions;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  const _ConvTile({
    required this.s,
    required this.item,
    required this.active,
    required this.onTap,
    required this.onOptions,
    required this.onArchive,
    required this.onDelete,
  });
  @override State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> with SingleTickerProviderStateMixin {
  bool _h = false;
  final GlobalKey _anchorKey = GlobalKey();

  double _dragDx = 0;
  bool _resolved = false;

  static const double _threshold = 96;

  void _onDragUpdate(DragUpdateDetails d) {
    if (_resolved) return;
    setState(() => _dragDx += d.delta.dx);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_resolved) {
      setState(() => _dragDx = 0);
      return;
    }
    if (_dragDx <= -_threshold) {
      setState(() => _resolved = true);
      widget.onDelete();
    } else if (_dragDx >= _threshold) {
      setState(() => _resolved = true);
      widget.onArchive();
    } else {
      setState(() => _dragDx = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bg = _dragDx < 0
        ? s.error
        : _dragDx > 0
            ? s.primary
            : Colors.transparent;
    final icon = _dragDx < 0 ? 'trash.svg' : 'archive.svg';
    final iconColor = _dragDx < 0 ? s.onError : s.onPrimary;

    return AnimatedOpacity(
      opacity: _resolved ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: Stack(children: [
        if (_dragDx != 0)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              alignment: _dragDx < 0 ? Alignment.centerRight : Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIcon(icon, color: iconColor, size: 18),
            ),
          ),
        Transform.translate(
          offset: Offset(_dragDx, 0),
          child: GestureDetector(
            key: _anchorKey,
            behavior: HitTestBehavior.opaque,
            onTapDown:   (_) => setState(() => _h = true),
            onTapCancel: ()  => setState(() => _h = false),
            onTapUp:     (_) => setState(() => _h = false),
            onTap: widget.onTap,
            onLongPress: () => widget.onOptions(_anchorKey),
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.active
                    ? s.navIndicatorBg
                    : (_h ? s.hover : s.surface),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.active ? FontWeight.w600 : FontWeight.normal,
                          color: widget.active ? s.navLabelActive : s.onSurface,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (widget.item.preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(widget.item.preview,
                          style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                ),
                if (widget.item.pinned) ...[
                  const SizedBox(width: 6),
                  AppIcon('pin.svg', color: s.onSurfaceVariant, size: 13),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

void showConversationOptionsPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required ConversationItem item,
  required VoidCallback onOpen,
  required VoidCallback onTogglePin,
  required VoidCallback onArchive,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) {
  final box = anchorKey.currentContext!.findRenderObject() as RenderBox;
  final off = box.localToGlobal(Offset.zero);
  final sz = box.size;
  final screenSize = MediaQuery.of(context).size;

  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 190),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    const width = 232.0;
    const estimatedHeight = 244.0;
    final desiredTop = off.dy + sz.height + 6;
    final overflowsBottom = desiredTop + estimatedHeight > screenSize.height - 24;
    final top = overflowsBottom ? null : desiredTop;
    final bottom = overflowsBottom ? screenSize.height - off.dy + 6 : null;
    final left = off.dx.clamp(12.0, screenSize.width - width - 12);

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: close,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        ),
      ),
      Positioned(
        top: top,
        bottom: bottom,
        left: left,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, child) => Opacity(
            opacity: CurvedAnimation(
                    parent: controller, curve: const Interval(0, 0.5, curve: Curves.easeOut))
                .value,
            child: Transform.scale(
              scale: Tween(begin: 0.92, end: 1.0)
                  .animate(CurvedAnimation(parent: controller, curve: kCupertinoOut))
                  .value,
              alignment: overflowsBottom ? Alignment.bottomLeft : Alignment.topLeft,
              child: child,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: width,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.floatingSurface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ConvPopupRow(
                    s: s, icon: 'send.svg', label: 'Abrir conversa',
                    onTap: () { close(); onOpen(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: 'pin.svg',
                    label: item.pinned ? 'Desafixar' : 'Fixar',
                    onTap: () { close(); onTogglePin(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: 'archive.svg',
                    label: item.archived ? 'Desarquivar' : 'Arquivar',
                    onTap: () { close(); onArchive(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: 'edit.svg', label: 'Renomear',
                    onTap: () { close(); onRename(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: 'trash.svg', label: 'Eliminar',
                    destructive: true,
                    onTap: () { close(); onDelete(); },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  });

  Overlay.of(context).insert(entry);
  controller.forward();
}

class _ConvPopupRow extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool useEditorIcon;
  const _ConvPopupRow({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.useEditorIcon = false,
  });
  @override State<_ConvPopupRow> createState() => _ConvPopupRowState();
}

class _ConvPopupRowState extends State<_ConvPopupRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.destructive ? widget.s.error : widget.s.onSurface;
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
          color: _h ? widget.s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          widget.useEditorIcon
              ? EditorTypeIcon(widget.icon, size: 18)
              : AppIcon(widget.icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(widget.label,
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

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

Future<void> showRenameSheet(
  BuildContext context,
  AppColorScheme s, {
  required String currentTitle,
  required ValueChanged<String> onConfirm,
  String title = 'Renomear conversa',
  String hint = 'Título da conversa',
}) {
  final ctrl = TextEditingController(text: currentTitle);
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: SheetGrabber(s: s)),
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: TextStyle(fontSize: 15, color: s.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                    filled: true,
                    fillColor: s.hover,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (v) {
                    Navigator.pop(ctx);
                    onConfirm(v.trim());
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    onConfirm(ctrl.text.trim());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Confirmar',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: s.onPrimary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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
  final GlobalKey _anchorKey = GlobalKey();

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
    final box = _anchorKey.currentContext!.findRenderObject() as RenderBox;
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
        key: _anchorKey,
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: IgnorePointer(
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