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
  String get svg => const {
        AppTab.ai: 'ai_tab.svg',
        AppTab.edit: 'edit_tab.svg',
      }[this]!;

  String get svgFilled => const {
        AppTab.ai: 'ai_tab_filled.svg',
        AppTab.edit: 'edit_tab_filled.svg',
      }[this]!;

  String get label => const {
        AppTab.ai: 'IA',
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
      id: old.id,
      title: old.title,
      preview: old.preview,
      pinned: pinned,
      archived: old.archived,
      updatedAt: old.updatedAt,
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
      id: old.id,
      title: old.title,
      preview: old.preview,
      pinned: old.pinned,
      archived: archived,
      updatedAt: old.updatedAt,
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
      id: old.id,
      title: newTitle,
      preview: old.preview,
      pinned: old.pinned,
      archived: old.archived,
      updatedAt: old.updatedAt,
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
// DRAWER
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

  void _onConvsChanged() {
    if (mounted) setState(() {});
  }

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

  void _goHome() {
    _closeDrawer();
    widget.onGoHome();
  }

  void _openConversation(ConversationItem item) {
    widget.onOpenConversation?.call(item.id);
    _closeDrawer();
  }

  void _openConvPopup(
      BuildContext context, LayerLink anchorLink, ConversationItem item) {
    final s = AppTheme.of(context);
    showConversationOptionsPopup(
      context,
      s,
      anchorLink: anchorLink,
      item: item,
      onOpen: () => _openConversation(item),
      onTogglePin: () =>
          conversationsController.togglePin(item.id, !item.pinned),
      onArchive: () => conversationsController.archive(item.id, !item.archived),
      onRename: () => _openRenamePopup(context, item),
      onDelete: () => _confirmDeletePopup(context, item),
    );
  }

  void _openRenamePopup(BuildContext context, ConversationItem item) {
    showRenameSheet(
      context,
      currentTitle: item.title,
      onConfirm: (newTitle) => conversationsController.rename(item.id, newTitle),
    );
  }

  void _confirmDeletePopup(BuildContext context, ConversationItem item) {
    final s = AppTheme.of(context);
    showFluentBottomSheet(
      context: context,
      s: s,
      child: _DeleteConversationSheet(
        s: s,
        title: item.title,
        onConfirm: () {
          Navigator.pop(context);
          conversationsController.delete(item.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final pinned = conversationsController.items
        .where((c) => c.pinned && !c.archived)
        .toList();
    final others = conversationsController.items
        .where((c) => !c.pinned && !c.archived)
        .toList();

    return Material(
      color: s.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                kSpaceL,
                kSpaceM,
                kSpaceM,
                kSpaceS,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: kTypeSubtitle,
                      fontWeight: FontWeight.bold,
                      color: s.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      AppTap(
                        onTap: () => _openSearch(context),
                        s: s,
                        size: kSpaceXXXL,
                        child: AppIcon('search.svg',
                            color: s.onSurfaceVariant, size: 16),
                      ),
                      SizedBox(width: kSpaceXXS),
                      AppTap(
                        onTap: _goHome,
                        s: s,
                        size: kSpaceXXXL,
                        child: AppIcon('home.svg',
                            color: s.onSurfaceVariant, size: 17),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: kSpaceS),
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
              padding: EdgeInsets.fromLTRB(
                kSpaceL,
                kSpaceL,
                kSpaceM,
                kSpaceS,
              ),
              child: Text(
                'Conversas',
                style: TextStyle(
                  fontSize: kTypeBody,
                  fontWeight: FontWeight.w600,
                  color: s.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: _buildConvBody(s, pinned, others),
            ),
            Padding(
              padding: EdgeInsets.all(kSpaceS + kSpaceXXS),
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
    if (conversationsController.loading &&
        conversationsController.items.isEmpty) {
      return Center(
        child: FluentShimmer(
          s: s,
          width: kSpaceXL,
          height: kSpaceXL,
        ),
      );
    }
    if (conversationsController.error != null &&
        conversationsController.items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: kSpaceXXL),
          child: Text(
            conversationsController.error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: kTypeBody, color: s.onSurfaceVariant),
          ),
        ),
      );
    }
    if (pinned.isEmpty && others.isEmpty) {
      return Center(
        child: Text(
          'Sem conversas ainda',
          style: TextStyle(fontSize: kTypeBody, color: s.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: kSpaceS),
      children: [
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(kSpaceS, kSpaceXS, kSpaceS, kSpaceS),
            child: Row(
              children: [
                AppIcon('pin.svg', color: s.onSurfaceVariant, size: 13),
                SizedBox(width: kSpaceS),
                Text(
                  'Fixadas',
                  style: TextStyle(
                    fontSize: kTypeCaption,
                    fontWeight: FontWeight.w600,
                    color: s.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final item in pinned)
            _ConvTile(
              s: s,
              item: item,
              active: item.id == widget.activeConversationId,
              onTap: () => _openConversation(item),
              onOptions: (link) => _openConvPopup(context, link, item),
              onArchive: () => conversationsController.archive(item.id, true),
              onDelete: () => conversationsController.delete(item.id),
            ),
          if (others.isNotEmpty)
            Padding(
              padding:
                  EdgeInsets.symmetric(vertical: kSpaceS, horizontal: kSpaceS),
              child: FluentDivider(s: s),
            )
          else
            SizedBox(height: kSpaceS),
        ],
        for (final item in others)
          _ConvTile(
            s: s,
            item: item,
            active: item.id == widget.activeConversationId,
            onTap: () => _openConversation(item),
            onOptions: (link) => _openConvPopup(context, link, item),
            onArchive: () => conversationsController.archive(item.id, true),
            onDelete: () => conversationsController.delete(item.id),
          ),
        SizedBox(height: kSpaceS),
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
    final s = AppTheme.of(context);
    final sel = widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: kDurationNormal,
        curve: kCupertinoOut,
        margin: EdgeInsets.symmetric(vertical: kSpaceXXS),
        padding: EdgeInsets.symmetric(
          horizontal: kSpaceM,
          vertical: kSpaceS + kSpaceXXS,
        ),
        decoration: BoxDecoration(
          color: sel
              ? s.navIndicatorBg
              : (_pressed ? s.subtleFillHover : Colors.transparent),
          borderRadius: BorderRadius.circular(kRadiusCircle),
        ),
        child: Row(
          children: [
            AppIcon(
              sel ? widget.tab.svgFilled : widget.tab.svg,
              color: sel ? s.navLabelActive : s.onSurfaceVariant,
              size: 20,
            ),
            SizedBox(width: kSpaceM),
            Text(
              widget.tab.label,
              style: TextStyle(
                fontSize: kTypeBody,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? s.navLabelActive : s.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<LayerLink> onOptions;
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
  @override
  State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile>
    with SingleTickerProviderStateMixin {
  bool _h = false;
  final LayerLink _anchorLink = LayerLink();

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
    final s = AppTheme.of(context);
    final bg = _dragDx < 0
        ? s.error
        : _dragDx > 0
            ? s.primary
            : Colors.transparent;
    final icon = _dragDx < 0 ? 'trash.svg' : 'archive.svg';
    final iconColor = _dragDx < 0 ? s.onError : s.onPrimary;

    return AnimatedOpacity(
      opacity: _resolved ? 0.0 : 1.0,
      duration: kDurationSlow,
      child: Stack(
        children: [
          if (_dragDx != 0)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: kSpaceXXS),
                alignment:
                    _dragDx < 0 ? Alignment.centerRight : Alignment.centerLeft,
                padding: EdgeInsets.symmetric(horizontal: kSpaceL),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(kRadiusLarge),
                ),
                child: AppIcon(icon, color: iconColor, size: 18),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragDx, 0),
            child: CompositedTransformTarget(
              link: _anchorLink,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _h = true),
                onTapCancel: () => setState(() => _h = false),
                onTapUp: (_) => setState(() => _h = false),
                onTap: widget.onTap,
                onLongPress: () => widget.onOptions(_anchorLink),
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: AnimatedContainer(
                  duration: kDurationFast,
                  margin: EdgeInsets.symmetric(vertical: kSpaceXXS),
                  padding: EdgeInsets.symmetric(
                    horizontal: kSpaceM,
                    vertical: kSpaceS + kSpaceXXS,
                  ),
                  decoration: BoxDecoration(
                    color: widget.active
                        ? s.navIndicatorBg
                        : (_h ? s.subtleFillHover : s.surface),
                    borderRadius: BorderRadius.circular(kRadiusLarge),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.title,
                              style: TextStyle(
                                fontSize: kTypeBody,
                                fontWeight: widget.active
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: widget.active
                                    ? s.navLabelActive
                                    : s.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.item.preview.isNotEmpty) ...[
                              SizedBox(height: kSpaceXXS),
                              Text(
                                widget.item.preview,
                                style: TextStyle(
                                    fontSize: kTypeCaption,
                                    color: s.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.item.pinned) ...[
                        SizedBox(width: kSpaceS),
                        AppIcon('pin.svg',
                            color: s.onSurfaceVariant, size: 13),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Popup de opções de conversa ───────────────────────────────

void showConversationOptionsPopup(
  BuildContext context,
  AppColorScheme s, {
  required LayerLink anchorLink,
  required ConversationItem item,
  required VoidCallback onOpen,
  required VoidCallback onTogglePin,
  required VoidCallback onArchive,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) {
  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: kDurationNormal,
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    const width = 232.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: anchorLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, child) => Opacity(
              opacity: CurvedAnimation(
                parent: controller,
                curve: const Interval(0, 0.5, curve: Curves.easeOut),
              ).value,
              child: Transform.scale(
                scale: Tween(begin: 0.92, end: 1.0)
                    .animate(
                        CurvedAnimation(parent: controller, curve: kCupertinoOut))
                    .value,
                alignment: Alignment.topLeft,
                child: child,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: width,
                child: FluentPopupContainer(
                  s: s,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ConvPopupRow(
                        s: s,
                        icon: 'send.svg',
                        label: 'Abrir conversa',
                        onTap: () {
                          close();
                          onOpen();
                        },
                      ),
                      _ConvPopupRow(
                        s: s,
                        icon: 'pin.svg',
                        label: item.pinned ? 'Desafixar' : 'Fixar',
                        onTap: () {
                          close();
                          onTogglePin();
                        },
                      ),
                      _ConvPopupRow(
                        s: s,
                        icon: 'archive.svg',
                        label: item.archived ? 'Desarquivar' : 'Arquivar',
                        onTap: () {
                          close();
                          onArchive();
                        },
                      ),
                      _ConvPopupRow(
                        s: s,
                        icon: 'edit.svg',
                        label: 'Renomear',
                        onTap: () {
                          close();
                          onRename();
                        },
                      ),
                      _ConvPopupRow(
                        s: s,
                        icon: 'trash.svg',
                        label: 'Eliminar',
                        destructive: true,
                        onTap: () {
                          close();
                          onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
  @override
  State<_ConvPopupRow> createState() => _ConvPopupRowState();
}

class _ConvPopupRowState extends State<_ConvPopupRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final color = widget.destructive ? s.error : s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _h = true),
      onTapCancel: () => setState(() => _h = false),
      onTapUp: (_) => setState(() => _h = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: kDurationFast,
        padding: EdgeInsets.symmetric(
          horizontal: kSpaceM,
          vertical: kSpaceS + kSpaceXXS,
        ),
        decoration: BoxDecoration(
          color: _h ? s.subtleFillHover : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusCircle),
        ),
        child: Row(
          children: [
            widget.useEditorIcon
                ? EditorTypeIcon(widget.icon, size: 18)
                : AppIcon(widget.icon, size: 18, color: color),
            SizedBox(width: kSpaceS + kSpaceXXS),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: kTypeBody,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
  Widget build(BuildContext context) {
    return FluentBottomSheet(
      s: s,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Eliminar "$title"?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: kTypeBody,
              fontWeight: FontWeight.w500,
              color: s.onSurface,
            ),
          ),
          SizedBox(height: kSpaceXL),
          Row(
            children: [
              Expanded(
                child: FluentButton(
                  s: s,
                  label: 'Cancelar',
                  onTap: () => Navigator.pop(context),
                  style: FluentButtonStyle.secondary,
                ),
              ),
              SizedBox(width: kSpaceS + kSpaceXXS),
              Expanded(
                child: FluentButton(
                  s: s,
                  label: 'Eliminar',
                  onTap: onConfirm,
                  style: FluentButtonStyle.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showRenameSheet(
  BuildContext context, {
  required String currentTitle,
  required ValueChanged<String> onConfirm,
  String title = 'Renomear conversa',
  String hint = 'Título da conversa',
}) {
  final s = AppTheme.of(context);
  return showFluentBottomSheet<void>(
    context: context,
    s: s,
    child: _RenameSheet(
      s: s,
      currentTitle: currentTitle,
      onConfirm: onConfirm,
      title: title,
      hint: hint,
    ),
  );
}

class _RenameSheet extends StatefulWidget {
  final AppColorScheme s;
  final String currentTitle;
  final ValueChanged<String> onConfirm;
  final String title;
  final String hint;
  const _RenameSheet({
    required this.s,
    required this.currentTitle,
    required this.onConfirm,
    required this.title,
    required this.hint,
  });
  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.currentTitle);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return FluentBottomSheet(
      s: s,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: kTypeBody,
              fontWeight: FontWeight.w600,
              color: s.onSurface,
            ),
          ),
          SizedBox(height: kSpaceM),
          FluentTextField(
            s: s,
            controller: _ctrl,
            autofocus: true,
            hint: widget.hint,
            fillColor: s.subtleFillHover,
            radius: kRadiusXLarge,
            contentPadding: EdgeInsets.symmetric(
              horizontal: kSpaceL,
              vertical: kSpaceM,
            ),
            onSubmitted: (v) {
              Navigator.pop(context);
              widget.onConfirm(v.trim());
            },
          ),
          SizedBox(height: kSpaceL),
          SizedBox(
            width: double.infinity,
            child: FluentButton(
              s: s,
              label: 'Confirmar',
              onTap: () {
                Navigator.pop(context);
                widget.onConfirm(_ctrl.text.trim());
              },
              style: FluentButtonStyle.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ACCOUNT PILL
// ══════════════════════════════════════════════════════════════

class _AccountPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onOpenSettings;
  const _AccountPill({required this.s, required this.onOpenSettings});
  @override
  State<_AccountPill> createState() => _AccountPillState();
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
    final fallback = Text(
      initial,
      style: TextStyle(
        color: s.onPrimary,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
      ),
    );

    if (avatar == null || avatar.isEmpty) return fallback;

    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return Image.network(
        avatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      );
    }

    final bytes = _decodeAvatar(avatar);
    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final user = authController.user;
    final name = user?.name ?? 'Utilizador';
    final avatar = user?.avatar;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(kRadiusCircle),
        boxShadow: s.cardShadow,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: kSpaceXS,
        vertical: kSpaceXS,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _p = true),
              onTapCancel: () => setState(() => _p = false),
              onTapUp: (_) => setState(() => _p = false),
              onTap: widget.onOpenSettings,
              child: AnimatedContainer(
                duration: kDurationFast,
                padding: EdgeInsets.symmetric(
                  horizontal: kSpaceXS + kSpaceXXS,
                  vertical: kSpaceXS,
                ),
                decoration: BoxDecoration(
                  color: _p ? s.subtleFillHover : Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadiusCircle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: s.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _buildAvatarContent(
                        s,
                        avatar,
                        initial,
                        size: 32,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: kSpaceS + kSpaceXXS),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(fontSize: kTypeBody, color: s.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _AccountQuickMenuButton(
            s: s,
            onOpenSettings: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _AccountQuickMenuButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onOpenSettings;
  const _AccountQuickMenuButton({
    required this.s,
    required this.onOpenSettings,
  });
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
      vsync: this,
      duration: kDurationNormal,
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    _ov?.remove();
    super.dispose();
  }

  void _toggle() => _ov == null ? _open() : _close();

  void _open() {
    final box = _anchorKey.currentContext!.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz = box.size;
    _ac.forward(from: 0);

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      return Stack(
        children: [
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
                  curve: const Interval(0, 0.5, curve: Curves.easeOut),
                ).value,
                child: Transform.scale(
                  scale: Tween(begin: 0.92, end: 1.0)
                      .animate(
                        CurvedAnimation(parent: _ac, curve: kCupertinoOut),
                      )
                      .value,
                  alignment: Alignment.bottomRight,
                  child: child,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: 220,
                  child: FluentPopupContainer(
                    s: s,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AccountQuickOption(
                          s: s,
                          icon: 'theme.svg',
                          label: s.isDark ? 'Modo claro' : 'Modo escuro',
                          onTap: () {
                            appTheme.toggleDark();
                            _close();
                          },
                        ),
                        _AccountQuickOption(
                          s: s,
                          icon: 'settings.svg',
                          label: 'Definições',
                          onTap: () {
                            widget.onOpenSettings();
                            _close();
                          },
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
          ),
        ],
      );
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
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _anchorKey,
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: IgnorePointer(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.subtleFillHover,
            shape: BoxShape.circle,
          ),
          child: AppIcon(
            'more_filled.svg',
            color: widget.s.onSurfaceVariant,
            size: 18,
          ),
        ),
      ),
    );
  }
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
  @override
  State<_AccountQuickOption> createState() => _AccountQuickOptionState();
}

class _AccountQuickOptionState extends State<_AccountQuickOption> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final color = widget.destructive ? s.error : s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _h = true),
      onTapCancel: () => setState(() => _h = false),
      onTapUp: (_) => setState(() => _h = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: kDurationFast,
        padding: EdgeInsets.symmetric(
          horizontal: kSpaceM,
          vertical: kSpaceS + kSpaceXXS,
        ),
        decoration: BoxDecoration(
          color: _h ? s.subtleFillHover : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusCircle),
        ),
        child: Row(
          children: [
            AppIcon(widget.icon, color: color, size: 18),
            SizedBox(width: kSpaceS + kSpaceXXS),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: kTypeBody,
                color: color,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}