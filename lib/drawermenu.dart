// ══════════════════════════════════════════════════════════════
// FILE: lib/drawermenu.dart
// ══════════════════════════════════════════════════════════════
// ATUALIZADO: CupertinoContextMenu no long-press das conversas e
// CupertinoActionSheet no botão de opções do pill de utilizador,
// curvas mais acentuadas nos cards, ícones CupertinoIcons.
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
import 'app_sheet.dart';

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
      _sortByRecency();
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
    _sortByRecency();
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
    _sortByRecency();
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
    _sortByRecency();
    notifyListeners();
    await ConversationsApiService.rename(token, id, newTitle);
  }

  Future<void> delete(String id) async {
    final token = authController.token;
    if (token == null) return;
    items.removeWhere((c) => c.id == id);
    _sortByRecency();
    notifyListeners();
    await ConversationsApiService.delete(token, id);
  }

  void upsertLocal(ConversationItem item) {
    items.removeWhere((c) => c.id == item.id);
    items.insert(0, item);
    _sortByRecency();
    notifyListeners();
  }

  void _sortByRecency() {
    items.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
}

final ConversationsController conversationsController = ConversationsController();

// ══════════════════════════════════════════════════════════════
// DRAWER — renderizado dentro do painel deslizante em main.dart
// ══════════════════════════════════════════════════════════════

class AppDrawer extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onClose;
  final VoidCallback onSettings;
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
  ];

  @override
  void initState() {
    super.initState();
    conversationsController.addListener(_onConvsChanged);
    authController.addListener(_onAuthChanged);
    _syncConversations();
  }

  @override
  void dispose() {
    conversationsController.removeListener(_onConvsChanged);
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onConvsChanged() { if (mounted) setState(() {}); }

  void _onAuthChanged() {
    if (!mounted) return;
    _syncConversations();
    setState(() {});
  }

  void _syncConversations() {
    if (authController.token != null &&
        conversationsController.items.isEmpty &&
        !conversationsController.loading) {
      conversationsController.load();
    }
  }

  void _closeDrawer() => widget.onClose();

  void _openSearch(BuildContext context) {
    _closeDrawer();
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => ChatSearchScreen(
        s: widget.s,
        onOpenConversation: (id) {
          widget.onOpenConversation?.call(id);
        },
      ),
    ));
  }

  void _openConversation(ConversationItem item) {
    widget.onOpenConversation?.call(item.id);
    _closeDrawer();
  }

  void _openRenamePopup(BuildContext context, ConversationItem item) {
    showRenameSheet(
      context,
      widget.s,
      currentTitle: item.title,
      onConfirm: (newTitle) => conversationsController.rename(item.id, newTitle),
    );
  }

  void _confirmDeletePopup(BuildContext context, ConversationItem item) {
    showAppSheet(
      context,
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
      color: s.pageBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                      color: s.onSurface,
                    ),
                  ),
                  Row(children: [
                    if (widget.onNewChat != null)
                      _HeaderIconButton(
                        s: s,
                        icon: CupertinoIcons.add,
                        onTap: widget.onNewChat!,
                      ),
                    const SizedBox(width: 6),
                    _HeaderIconButton(
                      s: s,
                      icon: CupertinoIcons.search,
                      onTap: () => _openSearch(context),
                    ),
                    const SizedBox(width: 6),
                    _HeaderIconButton(
                      s: s,
                      icon: CupertinoIcons.xmark,
                      onTap: _closeDrawer,
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _GroupedRows(
                s: s,
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
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 10),
              child: Text(
                'CONVERSAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: s.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: _buildConvBody(context, s, pinned, others),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _AccountPill(s: s, onOpenSettings: widget.onSettings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConvBody(
    BuildContext context,
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              Icon(CupertinoIcons.pin_fill, color: s.onSurfaceVariant, size: 13),
              const SizedBox(width: 6),
              Text('Fixadas',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: s.onSurfaceVariant)),
            ]),
          ),
          _GroupedRows(
            s: s,
            children: [
              for (final item in pinned)
                _ConvTile(
                  s: s,
                  item: item,
                  active: item.id == widget.activeConversationId,
                  onTap: () => _openConversation(item),
                  onOpen: () => _openConversation(item),
                  onTogglePin: () => conversationsController.togglePin(item.id, !item.pinned),
                  onArchive: () => conversationsController.archive(item.id, !item.archived),
                  onRename: () => _openRenamePopup(context, item),
                  onDelete: () => _confirmDeletePopup(context, item),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (others.isNotEmpty)
          _GroupedRows(
            s: s,
            children: [
              for (final item in others)
                _ConvTile(
                  s: s,
                  item: item,
                  active: item.id == widget.activeConversationId,
                  onTap: () => _openConversation(item),
                  onOpen: () => _openConversation(item),
                  onTogglePin: () => conversationsController.togglePin(item.id, !item.pinned),
                  onArchive: () => conversationsController.archive(item.id, !item.archived),
                  onRename: () => _openRenamePopup(context, item),
                  onDelete: () => _confirmDeletePopup(context, item),
                ),
            ],
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Ícone do header (nova conversa / pesquisar / fechar) ──────

class _HeaderIconButton extends StatefulWidget {
  final AppColorScheme s;
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.s, required this.icon, required this.onTap});
  @override State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 34, height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.hover : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, color: s.onSurfaceVariant, size: 19),
      ),
    );
  }
}

// ── Grupo de linhas — raio maior nas pontas externas, raio
// interno também mais visível nas junções, mesma lógica de antes
// mas com curvas mais acentuadas em toda a escala. ─────────────

class _GroupedRows extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> children;
  const _GroupedRows({required this.s, required this.children});

  static const double _outerRadius = 20;
  static const double _innerRadius = 6;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(_RowCard(
        s: s,
        radius: _radiusFor(i, children.length),
        child: children[i],
      ));
      if (i != children.length - 1) rows.add(const SizedBox(height: 2));
    }
    return Column(children: rows);
  }

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) return BorderRadius.circular(_outerRadius);
    final isFirst = index == 0;
    final isLast  = index == count - 1;
    return BorderRadius.only(
      topLeft:     Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight:    Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft:  Radius.circular(isLast  ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast  ? _outerRadius : _innerRadius),
    );
  }
}

class _RowCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;
  const _RowCard({required this.s, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: s.cardBackground, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

// ── Drawer tab tile ─────────────────────────────────────────

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
        duration: const Duration(milliseconds: 100),
        color: _pressed ? s.hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          AppIcon(
            sel ? widget.tab.svgFilled : widget.tab.svg,
            color: sel ? s.navLabelActive : s.onSurfaceVariant,
            size: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.tab.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? s.navLabelActive : s.onSurface,
              ),
            ),
          ),
          if (sel)
            Icon(CupertinoIcons.checkmark, color: s.primary, size: 16),
        ]),
      ),
    );
  }
}

// ── Conversa individual — long-press abre CupertinoContextMenu
// nativo, com preview do próprio tile levantado e ações por
// baixo. Swipe continua a funcionar para arquivar/eliminar
// rápido sem precisar abrir o menu. ────────────────────────────

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onArchive;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _ConvTile({
    required this.s,
    required this.item,
    required this.active,
    required this.onTap,
    required this.onOpen,
    required this.onTogglePin,
    required this.onArchive,
    required this.onRename,
    required this.onDelete,
  });
  @override State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> {
  bool _h = false;

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

  Widget _buildTileContent(AppColorScheme s, {bool insideContextMenu = false}) {
    return Container(
      color: insideContextMenu
          ? s.cardBackground
          : (widget.active ? s.navIndicatorBg : (_h ? s.hover : Colors.transparent)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                  color: widget.active ? s.navLabelActive : s.onSurface,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (widget.item.preview.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(widget.item.preview,
                  style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        if (widget.item.pinned) ...[
          const SizedBox(width: 6),
          Icon(CupertinoIcons.pin_fill, color: s.onSurfaceVariant, size: 13),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final swipeBg = _dragDx < 0
        ? s.error
        : _dragDx > 0
            ? s.primary
            : Colors.transparent;
    final swipeIcon = _dragDx < 0 ? CupertinoIcons.delete_solid : CupertinoIcons.archivebox_fill;
    final swipeIconColor = _dragDx < 0 ? s.onError : s.onPrimary;

    return AnimatedOpacity(
      opacity: _resolved ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: Stack(children: [
        if (_dragDx != 0)
          Positioned.fill(
            child: Container(
              alignment: _dragDx < 0 ? Alignment.centerRight : Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              color: swipeBg,
              child: Icon(swipeIcon, color: swipeIconColor, size: 18),
            ),
          ),
        Transform.translate(
          offset: Offset(_dragDx, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: CupertinoContextMenu(
              actions: [
                CupertinoContextMenuAction(
                  trailingIcon: CupertinoIcons.arrow_up_right_square,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onOpen();
                  },
                  child: const Text('Abrir conversa'),
                ),
                CupertinoContextMenuAction(
                  trailingIcon: widget.item.pinned
                      ? CupertinoIcons.pin_slash
                      : CupertinoIcons.pin,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onTogglePin();
                  },
                  child: Text(widget.item.pinned ? 'Desafixar' : 'Fixar'),
                ),
                CupertinoContextMenuAction(
                  trailingIcon: CupertinoIcons.archivebox,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onArchive();
                  },
                  child: const Text('Arquivar'),
                ),
                CupertinoContextMenuAction(
                  trailingIcon: CupertinoIcons.pencil,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRename();
                  },
                  child: const Text('Renomear'),
                ),
                CupertinoContextMenuAction(
                  isDestructiveAction: true,
                  trailingIcon: CupertinoIcons.delete,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                  child: const Text('Eliminar'),
                ),
              ],
              previewBuilder: (ctx, animation, child) => Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: _buildTileContent(s, insideContextMenu: true),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown:   (_) => setState(() => _h = true),
                onTapCancel: ()  => setState(() => _h = false),
                onTapUp:     (_) => setState(() => _h = false),
                onTap: widget.onTap,
                child: _buildTileContent(s),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Sheet de confirmação de eliminação ────────────────────────

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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    );
  }
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

// ── Sheet de renomeação ────────────────────────────────────────

Future<void> showRenameSheet(
  BuildContext context,
  AppColorScheme s, {
  required String currentTitle,
  required ValueChanged<String> onConfirm,
  String title = 'Renomear conversa',
  String hint = 'Título da conversa',
}) {
  final ctrl = TextEditingController(text: currentTitle);
  return showAppSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
  );
}

// ══════════════════════════════════════════════════════════════
// ACCOUNT PILL — pill continua com borderRadius 999 (já é
// totalmente redondo). Botão de opções agora abre um
// CupertinoActionSheet nativo, mesmo conjunto de ações visual
// que o CupertinoContextMenu das conversas.
// ══════════════════════════════════════════════════════════════

class _AccountPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onOpenSettings;
  const _AccountPill({required this.s, required this.onOpenSettings});
  @override State<_AccountPill> createState() => _AccountPillState();
}

class _AccountPillState extends State<_AccountPill> {
  bool _p = false;

  Uint8List? _decodeAvatar(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return null;
    }
    try {
      final commaIdx = raw.indexOf(',');
      final b64 = raw.startsWith('data:') && commaIdx != -1
          ? raw.substring(commaIdx + 1)
          : raw;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Widget _buildAvatarContent(
    AppColorScheme s,
    String? avatar,
    String initial, {
    required double size,
    required double fontSize,
  }) {
    final fallback = Text(initial,
        style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w700, fontSize: fontSize));

    if (avatar == null || avatar.isEmpty) return fallback;

    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return Image.network(
        avatar,
        width: size, height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      );
    }

    final bytes = _decodeAvatar(avatar);
    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      width: size, height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  void _openOptions(BuildContext context) {
    final s = widget.s;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              appTheme.toggleDark();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon, size: 18),
                const SizedBox(width: 8),
                Text(s.isDark ? 'Modo claro' : 'Modo escuro'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onOpenSettings();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.settings, size: 18),
                SizedBox(width: 8),
                Text('Definições'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              authController.logout();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_arrow_right, size: 18),
                SizedBox(width: 8),
                Text('Terminar sessão'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

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
                  child: _buildAvatarContent(s, avatar, initial, size: 32, fontSize: 14),
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openOptions(context),
          child: Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.hover,
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.ellipsis, color: s.onSurfaceVariant, size: 18),
          ),
        ),
      ]),
    );
  }
}