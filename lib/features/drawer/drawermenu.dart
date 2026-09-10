// ══════════════════════════════════════════════════════════════
// FILE: lib/features/drawer/drawermenu.dart
// ══════════════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import '../../services/auth_service.dart';
// TODO: depende de api_service.dart (split futuro); manter este import para a etapa futura de split.
import '../../services/api_service.dart';
import '../chat_search/chat_search.dart';
import '../../core/widgets/app_sheet.dart';
import '../apps/sheets/sheets.dart';
import '../library/library_screen.dart';
import '../scheduled_tasks/scheduled_tasks_screen.dart';
import '../all_apps/all_apps_screen.dart';
import '../apps/app_types.dart';
import '../apps/app_shortcuts.dart';
import '../apps/registry/app_registry.dart';
import '../apps/app_detail_screen.dart';
// TODO: depende de apps/docs.dart (split futuro); manter este import para a etapa futura de split.
import '../apps/docs/docs.dart';
import '../apps/sheets/sheets_app.dart';
import '../apps/slides/slides_app.dart';
import '../apps/sound/sound.dart';

// ══════════════════════════════════════════════════════════════
// TABS
// ══════════════════════════════════════════════════════════════

enum AppTab { ai }

extension AppTabX on AppTab {
  String get svg => 'ai_tab.svg';

  String get svgFilled => svg;

  String get label => 'IA';
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

  /// Rótulo de data/hora amigável para a linha da conversa.
  String get timeLabel {
    if (updatedAt <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(thatDay).inDays;

    String two(int v) => v.toString().padLeft(2, '0');

    if (diffDays == 0) {
      return '${two(dt.hour)}:${two(dt.minute)}';
    } else if (diffDays == 1) {
      return 'Ontem';
    } else if (diffDays > 1 && diffDays < 7) {
      const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return dias[dt.weekday - 1];
    } else {
      final yy = (dt.year % 100).toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/$yy';
    }
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
// DRAWER (full-screen)
// ══════════════════════════════════════════════════════════════

class AppDrawer extends StatefulWidget {
  final AppColorScheme s;
  final Future<void> Function() onCloseAnimated;
  final VoidCallback onSettings;
  final ValueChanged<String>? onOpenConversation;
  final VoidCallback? onNewChat;
  final String? activeConversationId;

  const AppDrawer({
    super.key,
    required this.s,
    required this.onCloseAnimated,
    required this.onSettings,
    this.onOpenConversation,
    this.onNewChat,
    this.activeConversationId,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _pinnedExpanded = true;
  bool _allExpanded = true;
  bool _shortcutsExpanded = true;

  static const double _topBarContentHeight = 52.0;
  static const double _bottomBarReserve = 84.0;

  static const double _topCircleSize = 40.0;

  @override
  void initState() {
    super.initState();
    conversationsController.addListener(_onConvsChanged);
    authController.addListener(_onAuthChanged);
    appShortcutsController.addListener(_onShortcutsChanged);
    _syncConversations();
    appShortcutsController.load();
  }

  @override
  void dispose() {
    conversationsController.removeListener(_onConvsChanged);
    authController.removeListener(_onAuthChanged);
    appShortcutsController.removeListener(_onShortcutsChanged);
    super.dispose();
  }

  void _onConvsChanged() { if (mounted) setState(() {}); }

  void _onShortcutsChanged() { if (mounted) setState(() {}); }

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

  Future<void> _closeThenRun(VoidCallback navigate) async {
    await widget.onCloseAnimated();
    if (!mounted) return;
    navigate();
  }

  void _handleNewChat() {
    HapticFeedback.lightImpact();
    widget.onNewChat?.call();
    widget.onCloseAnimated();
  }

  void _openConversation(ConversationItem item) {
    widget.onOpenConversation?.call(item.id);
    widget.onCloseAnimated();
  }

  void _openConvModal(BuildContext context, ConversationItem item) {
    HapticFeedback.lightImpact();
    showConversationOptionsModal(
      context,
      widget.s,
      item: item,
      onOpen: () => _openConversation(item),
      onTogglePin: () => conversationsController.togglePin(item.id, !item.pinned),
      onRename: () => _openRenamePopup(context, item),
      onDelete: () => _confirmDeletePopup(context, item),
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

  void _confirmDeletePopup(BuildContext context, ConversationItem item) {
    showFlatBottomSheet(
      context: context,
      s: widget.s,
      builder: (sheetContext) => _DeleteConversationSheet(
        s: widget.s,
        title: item.title,
        onConfirm: () {
          Navigator.pop(sheetContext);
          conversationsController.delete(item.id);
        },
      ),
    );
  }

  void _openLibrary(BuildContext context) {
    HapticFeedback.lightImpact();
    _closeThenRun(() {
      Navigator.of(context).push(_FadePageRoute(
        builder: (_) => const LibraryScreen(),
      ));
    });
  }

  void _openScheduledTasks(BuildContext context) {
    HapticFeedback.lightImpact();
    _closeThenRun(() {
      Navigator.of(context).push(_FadePageRoute(
        builder: (_) => const ScheduledTasksScreen(),
      ));
    });
  }

  void _openAllApps(BuildContext context) {
    HapticFeedback.lightImpact();
    _closeThenRun(() {
      Navigator.of(context).push(AppPageRoute(
        builder: (_) => const AllAppsScreen(),
      ));
    });
  }

  void _openAllAppsInSelectionMode(BuildContext context) {
    HapticFeedback.lightImpact();
    _closeThenRun(() {
      Navigator.of(context).push(AppPageRoute(
        builder: (_) => const AllAppsScreen(startInSelectionMode: true),
      ));
    });
  }

  void _openShortcutApp(BuildContext context, String slug) {
    final entry = AppRegistry.bySlug(slug);
    if (entry == null) return;
    HapticFeedback.lightImpact();
    _closeThenRun(() {
      Navigator.of(context).push(AppPageRoute(
        builder: (_) => AppDetailScreen(app: entry),
      ));
    });
  }

  /// ✅ ALTERAÇÃO: o drawer NÃO fecha antes. A tela de ChatSearch é
  /// empilhada por cima com `_OverlayDisplayRoute` (fade + scale).
  /// A mesma animação serve de transição de saída.
  void _openChatSearch(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(_OverlayDisplayRoute(
      builder: (_) => ChatSearchScreen(
        s: widget.s,
        onOpenConversation: (id) {
          widget.onOpenConversation?.call(id);
        },
      ),
    ));
  }

  Uint8List? _decodeAvatarBytes(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return null;
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

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final pinned = conversationsController.items.where((c) => c.pinned && !c.archived).toList();
    final others = conversationsController.items.where((c) => !c.pinned && !c.archived).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final user = authController.user;
    final name = user?.name ?? 'Utilizador';
    final avatarUrl = (user?.avatar != null &&
            (user!.avatar!.startsWith('http://') || user.avatar!.startsWith('https://')))
        ? user.avatar
        : null;
    final avatarBytes = _decodeAvatarBytes(user?.avatar);
    final hasCustomAvatar = avatarUrl != null || avatarBytes != null;

    return SizedBox(
      width: screenWidth,
      child: Material(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: _topBarContentHeight),
                Expanded(
                  child: _buildConversationsPage(context, s, pinned, others),
                ),
                SizedBox(height: _bottomBarReserve),
              ],
            ),

            Positioned(
              top: 0, left: 0, right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    height: _topBarContentHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: s.pageBackground.withOpacity(0.78),
                      border: Border(
                        bottom: BorderSide(color: s.outline.withOpacity(0.10), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onSettings,
                          child: Container(
                            width: _topCircleSize, height: _topCircleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s.primary,
                            ),
                            child: ClipOval(
                              child: hasCustomAvatar
                                  ? (avatarBytes != null
                                      ? Image.memory(avatarBytes, fit: BoxFit.cover)
                                      : Image.network(avatarUrl!, fit: BoxFit.cover))
                                  : Image.asset(
                                      'assets/icons/png/avatar.png',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectionContainer.disabled(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: s.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _CircleIconButton(
                          s: s,
                          assetName: 'double_chevron_right',
                          size: _topCircleSize,
                          iconSize: 16,
                          onTap: widget.onCloseAnimated,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0, right: 0, bottom: 0,
              child: DrawerBottomFloatingBar(
                s: s,
                onSearchTap: () => _openChatSearch(context),
                onNewChatTap: widget.onNewChat != null ? _handleNewChat : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildConversationsPage(
    BuildContext context,
    AppColorScheme s,
    List<ConversationItem> pinned,
    List<ConversationItem> others,
  ) {
    if (conversationsController.loading && conversationsController.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _DrawerSkeleton(),
        ],
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

    final sections = <Widget>[];

    sections.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: DrawerSquareAction(
              s: s,
              iconAsset: 'plugins',
              label: 'Apps',
              onTap: () => _openAllApps(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DrawerSquareAction(
              s: s,
              iconAsset: 'library',
              label: 'Biblioteca',
              onTap: () => _openLibrary(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DrawerSquareAction(
              s: s,
              iconAsset: 'clock',
              label: 'Tarefas\nagendadas',
              onTap: () => _openScheduledTasks(context),
            ),
          ),
        ],
      ),
    ));

    sections.add(_ConversationGroupHeader(
      s: s,
      label: 'Atalhos de apps',
      expanded: _shortcutsExpanded,
      onTap: () => setState(() => _shortcutsExpanded = !_shortcutsExpanded),
    ));
    sections.add(_ShortcutsCrossFade(
      visible: _shortcutsExpanded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: _AppShortcutsRow(
          s: s,
          slugs: appShortcutsController.slugs,
          onTapShortcut: (slug) => _openShortcutApp(context, slug),
          onAddTap: () => _openAllAppsInSelectionMode(context),
        ),
      ),
    ));

    if (conversationsController.items.isEmpty && !conversationsController.loading) {
      sections.add(Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(
          child: Text(
            'Sem conversas ainda',
            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
          ),
        ),
      ));
    }

    if (pinned.isNotEmpty) {
      sections.add(_ConversationGroupHeader(
        s: s,
        label: 'Conversas fixadas',
        expanded: _pinnedExpanded,
        onTap: () => setState(() => _pinnedExpanded = !_pinnedExpanded),
      ));
      sections.add(_StaggeredRevealGroup(
        visible: _pinnedExpanded,
        s: s,
        children: [
          for (final item in pinned)
            _ConvTile(
              s: s,
              item: item,
              active: item.id == widget.activeConversationId,
              onTap: () => _openConversation(item),
              onOptionsTap: () => _openConvModal(context, item),
            ),
        ],
      ));
    }

    if (others.isNotEmpty) {
      sections.add(_ConversationGroupHeader(
        s: s,
        label: 'Todas as conversas',
        expanded: _allExpanded,
        onTap: () => setState(() => _allExpanded = !_allExpanded),
      ));
      sections.add(_StaggeredRevealGroup(
        visible: _allExpanded,
        s: s,
        children: [
          for (final item in others)
            _ConvTile(
              s: s,
              item: item,
              active: item.id == widget.activeConversationId,
              onTap: () => _openConversation(item),
              onOptionsTap: () => _openConvModal(context, item),
            ),
        ],
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: sections,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Cards quadrados de ação do drawer (Apps / Biblioteca / Tarefas)
// ══════════════════════════════════════════════════════════════

class DrawerSquareAction extends StatefulWidget {
  final AppColorScheme s;
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  const DrawerSquareAction({
    super.key,
    required this.s,
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  @override
  State<DrawerSquareAction> createState() => _DrawerSquareActionState();
}

class _DrawerSquareActionState extends State<DrawerSquareAction> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _p ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: _p ? s.hover : s.cardBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppIcon(widget.iconAsset, size: 22, color: s.onSurface),
                const SizedBox(height: 8),
                SelectionContainer.disabled(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                      color: s.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CROSSFADE DE RECOLHER/EXPANDIR PARA A SECÇÃO DE ATALHOS
// ══════════════════════════════════════════════════════════════

class _ShortcutsCrossFade extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _ShortcutsCrossFade({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 260),
      sizeCurve: Curves.easeOutCubic,
      firstCurve: Curves.easeOut,
      secondCurve: Curves.easeOut,
      crossFadeState: visible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: child,
      secondChild: const SizedBox(width: double.infinity, height: 0),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECÇÃO "Atalhos de apps"
// ══════════════════════════════════════════════════════════════

class _AppShortcutsRow extends StatelessWidget {
  final AppColorScheme s;
  final List<String> slugs;
  final ValueChanged<String> onTapShortcut;
  final VoidCallback onAddTap;
  const _AppShortcutsRow({
    required this.s,
    required this.slugs,
    required this.onTapShortcut,
    required this.onAddTap,
  });

  static const double _itemSize = 39.2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _itemSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final slug in slugs)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _AppShortcutIcon(
                s: s,
                slug: slug,
                size: _itemSize,
                onTap: () => onTapShortcut(slug),
              ),
            ),
          _AddShortcutButton(s: s, size: _itemSize, onTap: onAddTap),
        ],
      ),
    );
  }
}

class _AppShortcutIcon extends StatefulWidget {
  final AppColorScheme s;
  final String slug;
  final double size;
  final VoidCallback onTap;
  const _AppShortcutIcon({
    required this.s,
    required this.slug,
    required this.size,
    required this.onTap,
  });

  @override
  State<_AppShortcutIcon> createState() => _AppShortcutIconState();
}

class _AppShortcutIconState extends State<_AppShortcutIcon> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final entry = AppRegistry.bySlug(widget.slug);
    if (entry == null) return const SizedBox.shrink();
    final manifest = entry.manifest;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            manifest.isCircularIcon ? widget.size / 2 : 12,
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(manifest.iconAsset, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

// ✅ ALTERAÇÃO: traço mais grosso e ícone 'add'.
class _AddShortcutButton extends StatefulWidget {
  final AppColorScheme s;
  final double size;
  final VoidCallback onTap;
  const _AddShortcutButton({
    required this.s,
    required this.size,
    required this.onTap,
  });

  @override
  State<_AddShortcutButton> createState() => _AddShortcutButtonState();
}

class _AddShortcutButtonState extends State<_AddShortcutButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _DashedCirclePainter(
              color: s.onSurfaceVariant.withOpacity(0.55),
              // traço notoriamente mais grosso do que o original (1.4)
              strokeWidth: 2.4,
              gap: 4.2,
              dashLength: 5.0,
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.cardBackground,
              ),
              child: AppIcon(
                'add',
                size: widget.size * 0.42,
                color: s.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desenha um círculo com contorno tracejado (traço por traço).
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gap;

  const _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * 3.141592653589793 * radius;
    final segment = dashLength + gap;
    final dashCount = (circumference / segment).floor().clamp(6, 200);
    final anglePerDash = (2 * 3.141592653589793) / dashCount;
    final dashAngle = anglePerDash * (dashLength / segment);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * anglePerDash;
      canvas.drawArc(rect, startAngle, dashAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap;
  }
}

// ── Skeleton loader estruturado ─────────────────────────────

class _DrawerSkeleton extends StatelessWidget {
  const _DrawerSkeleton();

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(child: _SkeletonSquare(s: s, delayMs: 0)),
              const SizedBox(width: 10),
              Expanded(child: _SkeletonSquare(s: s, delayMs: 60)),
              const SizedBox(width: 10),
              Expanded(child: _SkeletonSquare(s: s, delayMs: 120)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SkeletonBlock(s: s, width: 110, height: 12, delayMs: 160),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                for (int i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _SkeletonCircle(s: s, size: 39.2, delayMs: 180 + i * 40),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: _SkeletonBlock(s: s, width: 140, height: 12, delayMs: 360),
        ),
        for (int i = 0; i < 3; i++)
          _SkeletonConvRow(s: s, delayMs: 400 + i * 70),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: _SkeletonBlock(s: s, width: 160, height: 12, delayMs: 640),
        ),
        for (int i = 0; i < 4; i++)
          _SkeletonConvRow(s: s, delayMs: 680 + i * 70),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final AppColorScheme s;
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final int delayMs;
  const _ShimmerBox({
    required this.s,
    this.width,
    required this.height,
    required this.borderRadius,
    required this.delayMs,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final base = s.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final highlight = s.isDark ? Colors.white.withOpacity(0.11) : Colors.black.withOpacity(0.09);
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, highlight, _shimmer.value),
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

class _SkeletonSquare extends StatelessWidget {
  final AppColorScheme s;
  final int delayMs;
  const _SkeletonSquare({required this.s, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: _ShimmerBox(
        s: s,
        height: double.infinity,
        borderRadius: BorderRadius.circular(18),
        delayMs: delayMs,
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final AppColorScheme s;
  final double size;
  final int delayMs;
  const _SkeletonCircle({required this.s, required this.size, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      s: s,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      delayMs: delayMs,
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final AppColorScheme s;
  final double width;
  final double height;
  final int delayMs;
  const _SkeletonBlock({
    required this.s,
    required this.width,
    required this.height,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      s: s,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(6),
      delayMs: delayMs,
    );
  }
}

class _SkeletonConvRow extends StatelessWidget {
  final AppColorScheme s;
  final int delayMs;
  const _SkeletonConvRow({required this.s, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(
            s: s,
            width: double.infinity,
            height: 15,
            borderRadius: BorderRadius.circular(7),
            delayMs: delayMs,
          ),
          const SizedBox(height: 6),
          _ShimmerBox(
            s: s,
            width: 60,
            height: 11,
            borderRadius: BorderRadius.circular(6),
            delayMs: delayMs + 40,
          ),
        ],
      ),
    );
  }
}

// ── Grupo com revelação progressiva ──

class _StaggeredRevealGroup extends StatelessWidget {
  final bool visible;
  final AppColorScheme s;
  final List<Widget> children;
  const _StaggeredRevealGroup({
    required this.visible,
    required this.s,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 260),
      sizeCurve: Curves.easeOutCubic,
      firstCurve: Curves.easeOut,
      secondCurve: Curves.easeOut,
      crossFadeState: visible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++)
            _StaggeredItem(index: i, child: children[i]),
        ],
      ),
      secondChild: const SizedBox(width: double.infinity, height: 0),
    );
  }
}

class _StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredItem({required this.index, required this.child});
  @override State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    final delay = Duration(milliseconds: (widget.index * 28).clamp(0, 260));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Cabeçalho de grupo expansível ─────────────────────────────

class _ConversationGroupHeader extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final bool interactive;

  const _ConversationGroupHeader({
    required this.s,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: interactive ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            SelectionContainer.disabled(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: s.onSurfaceVariant,
                ),
              ),
            ),
            if (interactive) ...[
              const Spacer(),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: AppIcon(
                  'chevron_down',
                  size: 14,
                  color: s.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Rota de transição por fade ────────────────────────────────

class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  _FadePageRoute({required this.builder})
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        );
}

// ✅ NOVO: rota com animação de "overlay display" — fade + scale.
// Usada para a tela de ChatSearch (abre por cima do drawer, sem o
// fechar primeiro; a mesma animação serve para sair).
class _OverlayDisplayRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  _OverlayDisplayRoute({required this.builder})
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}

// ── Botão circular genérico ───────────────────────────────────

class _CircleIconButton extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onTapDown;
  final double size;
  final double iconSize;
  final bool filled;

  const _CircleIconButton({
    required this.s,
    required this.assetName,
    this.onTap,
    this.onTapDown,
    this.size = 40,
    this.iconSize = 20,
    this.filled = false,
  });
  @override State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final backgroundColor = widget.filled
        ? s.primary
        : _p ? s.pressed : s.cardBackground;
    final iconColor = widget.filled ? s.onPrimary : s.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        setState(() => _p = true);
        widget.onTapDown?.call(d.globalPosition);
      },
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) {
        setState(() => _p = false);
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: widget.size, height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: widget.filled ? null : s.cardShadow,
          ),
          child: AppIcon(widget.assetName, color: iconColor, size: widget.iconSize),
        ),
      ),
    );
  }
}

// ── Conversa individual ──

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onOptionsTap;
  const _ConvTile({
    required this.s,
    required this.item,
    required this.active,
    required this.onTap,
    required this.onOptionsTap,
  });
  @override State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> {
  bool _h = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _handleLongPress() {
    HapticFeedback.lightImpact();
    widget.onOptionsTap();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    final Color bg;
    if (widget.active) {
      bg = s.isDark ? s.hover : s.primary.withOpacity(0.1);
    } else if (_h) {
      bg = s.hover;
    } else {
      bg = Colors.transparent;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectionContainer.disabled(
              child: Text(
                widget.item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                  color: widget.active ? s.navLabelActive : s.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.item.timeLabel.isNotEmpty) ...[
              const SizedBox(height: 3),
              SelectionContainer.disabled(
                child: Text(
                  widget.item.timeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: s.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHEET GENÉRICO PLANO
// ══════════════════════════════════════════════════════════════

const double _kFlatModalRadius = 20.0;

class _ModalHandlebar extends StatelessWidget {
  final AppColorScheme s;
  const _ModalHandlebar({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: s.onSurfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

// ✅ ALTERAÇÃO: no modo claro o modal é BRANCO PURO. No modo escuro
// mantém-se s.cardBackground, como antes.
Future<T?> showFlatBottomSheet<T>({
  required BuildContext context,
  required AppColorScheme s,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.isDark ? s.cardBackground : Colors.white,
    barrierColor: Colors.black.withOpacity(0.35),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_kFlatModalRadius)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModalHandlebar(s: s),
          Flexible(child: builder(sheetContext)),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// MODAL de opções da conversa
// ══════════════════════════════════════════════════════════════

void showConversationOptionsModal(
  BuildContext context,
  AppColorScheme s, {
  required ConversationItem item,
  required VoidCallback onOpen,
  required VoidCallback onTogglePin,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) async {
  final result = await showFlatBottomSheet<_ConversationPopupAction>(
    context: context,
    s: s,
    builder: (sheetContext) => _ConversationOptionsModalContent(s: s, item: item),
  );

  if (result == null) return;
  switch (result) {
    case _ConversationPopupAction.open:
      onOpen();
      break;
    case _ConversationPopupAction.togglePin:
      onTogglePin();
      break;
    case _ConversationPopupAction.rename:
      onRename();
      break;
    case _ConversationPopupAction.delete:
      onDelete();
      break;
  }
}

class _ConversationOptionsModalContent extends StatelessWidget {
  final AppColorScheme s;
  final ConversationItem item;
  const _ConversationOptionsModalContent({required this.s, required this.item});

  @override
  Widget build(BuildContext context) {
    final titleColor = s.isDark ? Colors.white : s.pageBackground;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: SelectionContainer.disabled(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ),
        ),
        _modalItem(context, 'open', 'Abrir conversa', _ConversationPopupAction.open),
        _modalItem(
          context,
          item.pinned ? 'pin_slash' : 'pin',
          item.pinned ? 'Desafixar' : 'Fixar',
          _ConversationPopupAction.togglePin,
        ),
        _modalItem(context, 'pencil', 'Renomear', _ConversationPopupAction.rename),
        _modalItem(context, 'trash', 'Eliminar', _ConversationPopupAction.delete, destructive: true),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }

  Widget _modalItem(
    BuildContext context,
    String iconAsset,
    String label,
    _ConversationPopupAction action, {
    bool destructive = false,
  }) {
    final color = destructive ? s.error : s.onSurface;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context, action);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AppIcon(iconAsset, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: SelectionContainer.disabled(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConversationPopupAction { open, togglePin, rename, delete }

// ── Popup de opções da conta ────

void showAccountOptionsPopupAt(
  BuildContext context,
  AppColorScheme s, {
  required Offset position,
  required VoidCallback onToggleTheme,
  required VoidCallback onOpenSettings,
  required VoidCallback onLogout,
}) async {
  final result = await showFlatBottomSheet<_AccountPopupAction>(
    context: context,
    s: s,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => Navigator.pop(sheetContext, _AccountPopupAction.toggleTheme),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              AppIcon(s.isDark ? 'sun' : 'moon', size: 18, color: s.onSurface),
              const SizedBox(width: 12),
              Text(s.isDark ? 'Modo claro' : 'Modo escuro',
                  style: TextStyle(fontSize: 15, color: s.onSurface, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        InkWell(
          onTap: () => Navigator.pop(sheetContext, _AccountPopupAction.openSettings),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              AppIcon('settings', size: 18, color: s.onSurface),
              const SizedBox(width: 12),
              Text('Definições', style: TextStyle(fontSize: 15, color: s.onSurface, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        InkWell(
          onTap: () => Navigator.pop(sheetContext, _AccountPopupAction.logout),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              AppIcon('logout', size: 18, color: s.error),
              const SizedBox(width: 12),
              Text('Terminar sessão', style: TextStyle(fontSize: 15, color: s.error, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        SizedBox(height: MediaQuery.of(sheetContext).padding.bottom),
      ],
    ),
  );

  if (result == null) return;
  switch (result) {
    case _AccountPopupAction.toggleTheme:
      onToggleTheme();
      break;
    case _AccountPopupAction.openSettings:
      onOpenSettings();
      break;
    case _AccountPopupAction.logout:
      onLogout();
      break;
  }
}

enum _AccountPopupAction { toggleTheme, openSettings, logout }

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
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionContainer.disabled(
            child: Text(
              'Eliminar "$title"?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: s.onSurface),
            ),
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
      onTap:       () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _p ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? s.error : s.hover,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectionContainer.disabled(
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
      ),
    );
  }
}

// ── Sheet de renomeação ───────────────────────────────────────

Future<void> showRenameSheet(
  BuildContext context,
  AppColorScheme s, {
  required String currentTitle,
  required ValueChanged<String> onConfirm,
  String title = 'Renomear conversa',
  String hint = 'Título da conversa',
}) {
  final ctrl = TextEditingController(text: currentTitle);
  return showFlatBottomSheet<void>(
    context: context,
    s: s,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectionContainer.disabled(
              child: Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
            ),
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
                HapticFeedback.lightImpact();
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
                child: SelectionContainer.disabled(
                  child: Text('Confirmar',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: s.onPrimary)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// BOTTOM FLOATING BAR
// ══════════════════════════════════════════════════════════════

class DrawerBottomFloatingBar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNewChatTap;

  const DrawerBottomFloatingBar({
    super.key,
    required this.s,
    this.onSearchTap,
    this.onNewChatTap,
  });

  static const double _barHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12, 8, 12, 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                onSearchTap?.call();
              },
              child: Container(
                height: _barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: s.cardBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(children: [
                  AppIcon('search', size: 20, color: s.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectionContainer.disabled(
                      child: Text(
                        'Pesquisar',
                        style: TextStyle(fontSize: 15, color: s.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _NewChatFab(s: s, onTap: onNewChatTap),
        ],
      ),
    );
  }
}

class _NewChatFab extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback? onTap;
  const _NewChatFab({required this.s, this.onTap});
  @override State<_NewChatFab> createState() => _NewChatFabState();
}

class _NewChatFabState extends State<_NewChatFab> {
  bool _p = false;

  static const double _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bg = s.isDark ? Colors.white : s.primary;
    final iconColor = s.isDark ? Colors.black : s.onPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: s.cardShadow,
          ),
          child: AppIcon('new_chat', size: 20, color: iconColor),
        ),
      ),
    );
  }
}