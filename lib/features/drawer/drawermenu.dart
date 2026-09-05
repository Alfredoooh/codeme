// ══════════════════════════════════════════════════════════════
// FILE: lib/features/drawer/drawermenu.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../aitab/aitab_widgets_shared.dart
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
// DRAWER
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

  void _openSearch(BuildContext context) {
    HapticFeedback.lightImpact();
    _closeThenRun(() {
      Navigator.of(context).push(_FadePageRoute(
        builder: (_) => ChatSearchScreen(
          s: widget.s,
          onOpenConversation: (id) {
            widget.onOpenConversation?.call(id);
          },
        ),
      ));
    });
  }

  void _openConversation(ConversationItem item) {
    widget.onOpenConversation?.call(item.id);
    widget.onCloseAnimated();
  }

  void _openConvPopupAt(BuildContext context, Offset globalPos, ConversationItem item) {
    HapticFeedback.lightImpact();
    showConversationOptionsPopupAt(
      context,
      widget.s,
      position: globalPos,
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
    showCraftBottomSheet(
      context: context,
      s: widget.s,
      child: Builder(builder: (sheetContext) => _DeleteConversationSheet(
        s: widget.s,
        title: item.title,
        onConfirm: () {
          Navigator.pop(sheetContext);
          conversationsController.delete(item.id);
        },
      )),
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

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final pinned = conversationsController.items.where((c) => c.pinned && !c.archived).toList();
    final others = conversationsController.items.where((c) => !c.pinned && !c.archived).toList();
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.75,
      child: Material(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Expanded(
                  child: _buildConversationsPage(context, s, pinned, others),
                ),
                // Reduzido de 112 -> 88 para acompanhar a bottom bar mais baixa.
                const SizedBox(height: 88),
              ],
            ),

            // ── AppBar transparente com gradiente, mesmos valores do _SettingsAppBar ──
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Mesmos valores do _SettingsAppBar: nunca chega a 0,
                    // fica sempre com um mínimo de opacidade.
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectionContainer.disabled(
                        child: Text(
                          'Nexa',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ).copyWith(color: s.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CircleIconButton(
                      s: s,
                      assetName: 'search',
                      size: 40,
                      iconSize: 18,
                      onTap: () => _openSearch(context),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom bar transparente com gradiente, mesmos valores do _SettingsAppBar ──
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _NewChatPill(s: s, onTap: widget.onNewChat != null ? _handleNewChat : null),
                    const Spacer(),
                    _AvatarCircleButton(
                      s: s,
                      onTap: widget.onSettings,
                    ),
                  ],
                ),
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
    // ── Skeleton loader no lugar do CupertinoActivityIndicator ──
    if (conversationsController.loading && conversationsController.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 56, 12, 8),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int i = 0; i < 7; i++)
            _ConversationSkeletonRow(s: s, delayMs: i * 70),
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

    sections.add(_LooseRows(
      s: s,
      children: [
        _MenuOptionTile(
          s: s,
          assetName: 'plugins',
          label: 'Apps e plugins',
          onTap: () => _openAllApps(context),
        ),
        _MenuOptionTile(
          s: s,
          assetName: 'library',
          label: 'Biblioteca',
          onTap: () => _openLibrary(context),
        ),
        _MenuOptionTile(
          s: s,
          assetName: 'clock',
          label: 'Tarefas agendadas',
          onTap: () => _openScheduledTasks(context),
        ),
      ],
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
              onOptionsAt: (pos) => _openConvPopupAt(context, pos, item),
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
              onOptionsAt: (pos) => _openConvPopupAt(context, pos, item),
            ),
        ],
      ));
    }

    // ── Lista simples, sem pull-to-refresh (nem iOS nem Android) ──
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 56, 4, 8),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: sections,
    );
  }
}

// ── Skeleton loader (linha fantasma com shimmer suave) ─────────

class _ConversationSkeletonRow extends StatefulWidget {
  final AppColorScheme s;
  final int delayMs;
  const _ConversationSkeletonRow({required this.s, required this.delayMs});
  @override State<_ConversationSkeletonRow> createState() => _ConversationSkeletonRowState();
}

class _ConversationSkeletonRowState extends State<_ConversationSkeletonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) {
          final t = _shimmer.value;
          return Row(
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color.lerp(base, highlight, t),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color.lerp(base, highlight, 1 - t),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Grupo com revelação progressiva (stagger) ao expandir/carregar ──

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

// ── Opção de menu (Apps e plugins / Biblioteca / Tarefas agendadas) ──

class _MenuOptionTile extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final VoidCallback onTap;
  const _MenuOptionTile({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
  });
  @override State<_MenuOptionTile> createState() => _MenuOptionTileState();
}

class _MenuOptionTileState extends State<_MenuOptionTile> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _h ? s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(children: [
          AppIcon(widget.assetName, size: 20, color: s.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: SelectionContainer.disabled(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: s.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ]),
      ),
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
          mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 8),
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

// ── Avatar circular com anel ────────────────────────────────

class _AvatarCircleButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _AvatarCircleButton({required this.s, required this.onTap});
  @override State<_AvatarCircleButton> createState() => _AvatarCircleButtonState();
}

class _AvatarCircleButtonState extends State<_AvatarCircleButton> {
  bool _p = false;

  static const double _buttonSize = 52;
  static const double _ringWidth = 3;
  static const double _fontSize = 17;

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

    if (avatar == null || avatar.isEmpty) {
      return Container(
        color: s.primary,
        alignment: Alignment.center,
        child: fallback,
      );
    }

    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return Image.network(
        avatar,
        width: size, height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Container(
          color: s.primary,
          alignment: Alignment.center,
          child: fallback,
        ),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(color: s.primary, alignment: Alignment.center, child: fallback),
      );
    }

    final bytes = _decodeAvatar(avatar);
    if (bytes == null) {
      return Container(
        color: s.primary,
        alignment: Alignment.center,
        child: fallback,
      );
    }
    return Image.memory(
      bytes,
      width: size, height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        color: s.primary,
        alignment: Alignment.center,
        child: fallback,
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

    final innerSize = _buttonSize - (_ringWidth * 2) - 2;

    // Anel neutro e discreto — baseado em onSurface com opacidade baixa
    // em vez de s.outline (que ficava com uma cor de superfície muito
    // marcada/feia). Se adapta bem a claro e escuro.
    final ringColor = s.isDark
        ? Colors.white.withOpacity(_p ? 0.22 : 0.14)
        : Colors.black.withOpacity(_p ? 0.16 : 0.09);

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
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _buttonSize, height: _buttonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor,
              width: _ringWidth,
            ),
            boxShadow: s.cardShadow,
          ),
          child: ClipOval(
            child: SizedBox(
              width: innerSize,
              height: innerSize,
              child: _buildAvatarContent(s, avatar, initial, size: innerSize, fontSize: _fontSize),
            ),
          ),
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

// ── Grupo de linhas soltas ────────────────────────────────────

class _LooseRows extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> children;
  const _LooseRows({required this.s, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

// ── Conversa individual ───────────────────────────────────────

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<Offset> onOptionsAt;
  const _ConvTile({
    required this.s,
    required this.item,
    required this.active,
    required this.onTap,
    required this.onOptionsAt,
  });
  @override State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> {
  bool _h = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _handleLongPressStart(LongPressStartDetails d) {
    HapticFeedback.lightImpact();
    widget.onOptionsAt(d.globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    final Color bg;
    if (widget.active) {
      bg = s.isDark ? s.hover : s.primary.withOpacity(0.1); // tema claro: primária fraca
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
      onLongPressStart: _handleLongPressStart,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(children: [
          Expanded(
            child: SelectionContainer.disabled(
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
          ),
        ]),
      ),
    );
  }
}

// ── Popup nativo com animação estilo iOS (spring suave) ────────
//
// showMenu() do Flutter usa, por omissão, uma curva bem seca
// (fastOutSlowIn instantânea, sem "settle"). Para dar a sensação
// de suavidade iOS mantendo o showMenu nativo (que já ancora
// corretamente na posição do toque via RelativeRect), envolvemos
// a apresentação numa PopupRoute customizada com curva
// Curves.easeOutBack suavizada — dá o leve "overshoot" e assentar
// suave típico do iOS, sem alterar nada do design dos itens.

Future<T?> _showAnchoredPopup<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<PopupMenuEntry<T>> items,
  required Color color,
  required ShapeBorder shape,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _SpringMenuRoute<T>(
      position: position,
      items: items,
      color: color,
      shape: shape,
    ),
  );
}

class _SpringMenuRoute<T> extends PopupRoute<T> {
  final RelativeRect position;
  final List<PopupMenuEntry<T>> items;
  final Color color;
  final ShapeBorder shape;

  _SpringMenuRoute({
    required this.position,
    required this.items,
    required this.color,
    required this.shape,
  });

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return CustomSingleChildLayout(
      delegate: _PopupMenuRouteLayout(position),
      child: Material(
        type: MaterialType.transparency,
        child: PopupMenu<T>(
          items: items,
          route: this,
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // Curva suave com leve overshoot no fim, tipo spring do iOS,
    // no lugar da curva seca padrão do showMenu.
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }
}

class _PopupMenuRouteLayout extends SingleChildLayoutDelegate {
  final RelativeRect position;
  _PopupMenuRouteLayout(this.position);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = position.left;
    double y = position.top;
    if (x + childSize.width > size.width) x = size.width - childSize.width - 8;
    if (x < 8) x = 8;
    if (y + childSize.height > size.height) y = size.height - childSize.height - 8;
    if (y < 8) y = 8;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopupMenuRouteLayout oldDelegate) => position != oldDelegate.position;
}

// ── Popup de opções da conversa (ancorado no ponto exato do toque) ──

void showConversationOptionsPopupAt(
  BuildContext context,
  AppColorScheme s, {
  required Offset position,
  required ConversationItem item,
  required VoidCallback onOpen,
  required VoidCallback onTogglePin,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) async {
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox;
  final screenSize = overlayBox.size;

  // Ancoragem exata no ponto onde o dedo tocou (position = globalPosition
  // do onTapDown/onLongPressStart, já capturado pelo chamador).
  final RelativeRect menuPosition = RelativeRect.fromLTRB(
    position.dx,
    position.dy,
    screenSize.width - position.dx,
    screenSize.height - position.dy,
  );

  final result = await _showAnchoredPopup<_ConversationPopupAction>(
    context: context,
    position: menuPosition,
    color: s.cardBackground, // cor do card de settings
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: s.outline.withOpacity(0.25),
        width: 1.0,
      ),
    ),
    items: [
      PopupMenuItem(
        value: _ConversationPopupAction.open,
        padding: EdgeInsets.zero,
        child: _buildPopupItem(s, 'open', 'Abrir conversa'),
      ),
      PopupMenuItem(
        value: _ConversationPopupAction.togglePin,
        padding: EdgeInsets.zero,
        child: _buildPopupItem(s, item.pinned ? 'pin_slash' : 'pin', item.pinned ? 'Desafixar' : 'Fixar'),
      ),
      PopupMenuItem(
        value: _ConversationPopupAction.rename,
        padding: EdgeInsets.zero,
        child: _buildPopupItem(s, 'pencil', 'Renomear'),
      ),
      PopupMenuItem(
        value: _ConversationPopupAction.delete,
        padding: EdgeInsets.zero,
        child: _buildPopupItem(s, 'trash', 'Eliminar', destructive: true),
      ),
    ],
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

Widget _buildPopupItem(AppColorScheme s, String iconAsset, String label, {bool destructive = false}) {
  final color = destructive ? s.error : s.onSurface;
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: Colors.transparent,
    ),
    child: Row(
      children: [
        AppIcon(iconAsset, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: SelectionContainer.disabled(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    ),
  );
}

enum _ConversationPopupAction { open, togglePin, rename, delete }

// ── Popup de opções da conta (ancorado no ponto exato do toque) ────

void showAccountOptionsPopupAt(
  BuildContext context,
  AppColorScheme s, {
  required Offset position,
  required VoidCallback onToggleTheme,
  required VoidCallback onOpenSettings,
  required VoidCallback onLogout,
}) async {
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox;
  final screenSize = overlayBox.size;

  final RelativeRect menuPosition = RelativeRect.fromLTRB(
    position.dx,
    position.dy,
    screenSize.width - position.dx,
    screenSize.height - position.dy,
  );

  final result = await _showAnchoredPopup<_AccountPopupAction>(
    context: context,
    position: menuPosition,
    color: s.cardBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: s.outline.withOpacity(0.25),
        width: 1.0,
      ),
    ),
    items: [
      PopupMenuItem(
        value: _AccountPopupAction.toggleTheme,
        padding: EdgeInsets.zero,
        child: _buildPopupItem(s, s.isDark ? 'sun' : 'moon', s.isDark ? 'Modo claro' : 'Modo escuro'),
      ),
      PopupMenuItem(
        value: _AccountPopupAction.openSettings,
        padding: EdgeInsets.zero,
        child: _buildPopupItem(s, 'settings', 'Definições'),
      ),
      PopupMenuItem(
        value: _AccountPopupAction.logout,
        padding: EdgeInsets.zero,
        child: _buildPopupItem(s, 'logout', 'Terminar sessão', destructive: true),
      ),
    ],
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            borderRadius: BorderRadius.circular(999),
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
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: Builder(builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
    )),
  );
}

// ── NEW CHAT PILL (compacto, cor primária, texto branco) ──────

class _NewChatPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback? onTap;
  const _NewChatPill({required this.s, required this.onTap});
  @override State<_NewChatPill> createState() => _NewChatPillState();
}

class _NewChatPillState extends State<_NewChatPill> {
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
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _p ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: IntrinsicWidth(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 52,
            decoration: BoxDecoration(
              color: s.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: s.cardShadow,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon('new_chat', color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const SelectionContainer.disabled(
                  child: Text(
                    'Conversar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
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