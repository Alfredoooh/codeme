// ══════════════════════════════════════════════════════════════
// FILE: lib/features/drawer/drawermenu.dart
//
// MUDANÇAS NESTA VERSÃO:
// 1) Topbar do drawer: mesma altura de conteúdo do _AppHeader do
//    main.dart e o mesmo ShaderMask (dstIn) de dissolução
//    progressiva do blur, para consistência visual total.
// 2) Bottom floating bar: os botões de settings e nova conversa
//    passaram a _CircleIconButton (40x40, cardBackground,
//    cardShadow) — mesma linguagem visual dos botões do appbar do
//    main — em vez do botão pequeno "flat" anterior. Ícones subiram
//    para 20 (igual ao main).
// 3) O campo de pesquisa da bottom bar deixou de usar s.hover sobre
//    um fundo já translúcido (ficava quase invisível em certos
//    temas claros) — agora tem contorno próprio (outline) e um
//    fundo com opacidade fixa que não depende da opacidade do
//    container pai, mantendo bom contraste tanto no claro como no
//    escuro (que já estava bem).
// 4) A própria bottom bar ganhou um ShaderMask no topo (mais
//    transparente para cima, mantendo o blur), espelhando o efeito
//    do appbar.
// 5) Nome do utilizador: FontWeight subiu de w600 para w800.
// 6) Modal de opções da conversa: deixou de ser showModalBottomSheet
//    (sobe do fundo do ecrã) e passou a showAnchoredPopup, nascendo
//    a partir do próprio botão "⋮" de cada conversa — reorganizado
//    visualmente ao estilo dos cards do PersonalizationScreen
//    (grupo arredondado com linhas divisórias finas).
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
import '../../core/widgets/anchored_popup.dart';
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

  // Altura de conteúdo da topbar (mesma métrica do _AppHeader do
  // main.dart: 6 + 40 + 10 = altura visual do conteúdo, sem contar
  // o inset do topo do sistema, que é somado no SafeArea/padding).
  static const double _topBarContentHeight = 56.0;
  static const double _bottomBarReserve = 84.0;

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

  void _openConversation(ConversationItem item) {
    widget.onOpenConversation?.call(item.id);
    widget.onCloseAnimated();
  }

  void _openConvModal(BuildContext context, GlobalKey anchorKey, ConversationItem item) {
    HapticFeedback.lightImpact();
    showConversationOptionsModal(
      context,
      widget.s,
      anchorKey: anchorKey,
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

  Uint8List? _decodeAvatar(String? raw) {
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
    final avatarBytes = _decodeAvatar(user?.avatar);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final topInset = MediaQuery.of(context).padding.top;
    final fullTopBarHeight = topInset + _topBarContentHeight;

    return SizedBox(
      width: screenWidth,
      child: Material(
        color: s.pageBackground,
        child: Stack(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: fullTopBarHeight),
              Expanded(
                child: _buildConversationsPage(context, s, pinned, others),
              ),
              SizedBox(height: _bottomBarReserve + MediaQuery.of(context).padding.bottom),
            ],
          ),

          // ── Topbar: mesma linguagem visual e o mesmo ShaderMask de
          // dissolução progressiva do _AppHeader do main.dart. ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.62, 1.0],
                  ).createShader(Rect.fromLTWH(0, 0, bounds.width, fullTopBarHeight * 1.35));
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: fullTopBarHeight,
                    padding: EdgeInsets.only(top: topInset, left: 16, right: 16),
                    decoration: BoxDecoration(
                      color: s.pageBackground.withOpacity(0.82),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onSettings,
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s.primary,
                              boxShadow: s.cardShadow,
                            ),
                            child: ClipOval(
                              child: avatarBytes != null
                                  ? Image.memory(avatarBytes, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          color: s.onPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
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
                                // Nome do utilizador mais "bolder"
                                // (w600 -> w800), conforme pedido.
                                fontWeight: FontWeight.w800,
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
                          size: 40,
                          iconSize: 18,
                          onTap: widget.onCloseAnimated,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 0, right: 0, bottom: 0,
            child: DrawerBottomFloatingBar(
              s: s,
              onSearchTap: () {},
              onSettingsTap: widget.onSettings,
              onNewChatTap: widget.onNewChat != null ? _handleNewChat : null,
            ),
          ),
        ]),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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

    sections.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: DrawerSettingsGroup(s: s, rows: [
        DrawerSettingsRow(
          s: s,
          iconAsset: 'plugins',
          label: 'Apps e plugins',
          onTap: () => _openAllApps(context),
          trailing: AppIcon('chevron_forward', size: 16, color: s.onSurfaceVariant),
        ),
        DrawerSettingsRow(
          s: s,
          iconAsset: 'library',
          label: 'Biblioteca',
          onTap: () => _openLibrary(context),
          trailing: AppIcon('chevron_forward', size: 16, color: s.onSurfaceVariant),
        ),
        DrawerSettingsRow(
          s: s,
          iconAsset: 'clock',
          label: 'Tarefas agendadas',
          onTap: () => _openScheduledTasks(context),
          trailing: AppIcon('chevron_forward', size: 16, color: s.onSurfaceVariant),
        ),
      ]),
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
              onOptionsTap: (key) => _openConvModal(context, key, item),
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
              onOptionsTap: (key) => _openConvModal(context, key, item),
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
// Cards de lista das opções do drawer
// ══════════════════════════════════════════════════════════════

class DrawerSettingsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> rows;
  const DrawerSettingsGroup({super.key, required this.s, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 52,
                color: s.outline.withOpacity(0.12),
              ),
          ],
        ],
      ),
    );
  }
}

class DrawerSettingsRow extends StatefulWidget {
  final AppColorScheme s;
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final Widget trailing;
  const DrawerSettingsRow({
    super.key,
    required this.s,
    required this.iconAsset,
    required this.label,
    required this.onTap,
    required this.trailing,
  });
  @override State<DrawerSettingsRow> createState() => _DrawerSettingsRowState();
}

class _DrawerSettingsRowState extends State<DrawerSettingsRow> {
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
      child: Container(
        color: _p ? s.hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: AppIcon(widget.iconAsset, size: 20, color: s.onSurface),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectionContainer.disabled(
              child: Text(
                widget.label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: s.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          widget.trailing,
        ]),
      ),
    );
  }
}

// ── Skeleton loader ─────────

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

// ── Conversa individual ──
// onOptionsTap agora recebe a própria GlobalKey do botão de opções,
// para que o popup ancorado saiba a partir de onde nascer.

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<GlobalKey> onOptionsTap;
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
  final GlobalKey _optionsKey = GlobalKey();

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _handleLongPress() {
    HapticFeedback.lightImpact();
    widget.onOptionsTap(_optionsKey);
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
      key: _optionsKey,
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
          if (widget.item.timeLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
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
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODAL de opções da conversa — AGORA ancorado ao botão que o
// abriu (long-press na própria linha), no estilo organizado dos
// cards do PersonalizationScreen: grupo arredondado, linhas
// divisórias finas, sem o "flat sheet" anterior que subia do fundo.
// ══════════════════════════════════════════════════════════════

void showConversationOptionsModal(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required ConversationItem item,
  required VoidCallback onOpen,
  required VoidCallback onTogglePin,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) async {
  final result = await showAnchoredPopup<_ConversationPopupAction>(
    context,
    anchorKey: anchorKey,
    s: s,
    menuWidth: 230,
    items: [
      AnchoredPopupItem(
        value: _ConversationPopupAction.open,
        label: 'Abrir conversa',
        assetName: 'open',
      ),
      AnchoredPopupItem(
        value: _ConversationPopupAction.togglePin,
        label: item.pinned ? 'Desafixar' : 'Fixar',
        assetName: item.pinned ? 'pin_slash' : 'pin',
      ),
      AnchoredPopupItem(
        value: _ConversationPopupAction.rename,
        label: 'Renomear',
        assetName: 'pencil',
      ),
      AnchoredPopupItem(
        value: _ConversationPopupAction.delete,
        label: 'Eliminar',
        assetName: 'trash',
        destructive: true,
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

enum _ConversationPopupAction { open, togglePin, rename, delete }

// ── Popup de opções da conta (mantido em showModalBottomSheet:
//    não fazia parte do pedido de mudança desta ronda) ────

void showAccountOptionsPopupAt(
  BuildContext context,
  AppColorScheme s, {
  required Offset position,
  required VoidCallback onToggleTheme,
  required VoidCallback onOpenSettings,
  required VoidCallback onLogout,
}) async {
  final result = await showModalBottomSheet<_AccountPopupAction>(
    context: context,
    backgroundColor: s.cardBackground,
    barrierColor: Colors.black.withOpacity(0.35),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
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
        ],
      ),
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
            borderRadius: BorderRadius.circular(10.0),
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

// ══════════════════════════════════════════════════════════════
// BOTTOM FLOATING BAR
//
// MUDANÇAS: botões de settings/nova conversa agora usam
// _CircleIconButton (40x40, cardBackground próprio, cardShadow) —
// mesma linguagem visual dos botões do appbar do main.dart — em
// vez do botão pequeno "flat" transparente anterior. O input de
// pesquisa ganhou contorno próprio (deixou de depender só de
// s.hover sobre um fundo já translúcido, que ficava quase
// invisível em certos temas claros). A barra inteira ganhou um
// ShaderMask no topo: mais transparente para cima, mantendo o
// blur, para fundir com o conteúdo por trás sem aresta.
// ══════════════════════════════════════════════════════════════

class DrawerBottomFloatingBar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback? onSearchTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onNewChatTap;

  const DrawerBottomFloatingBar({
    super.key,
    required this.s,
    this.onSearchTap,
    this.onSettingsTap,
    this.onNewChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12, 14, 12, 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            // Mais transparente em cima (perto do valor 0.35 do
            // alfa), opaco a partir de ~35% da altura para baixo —
            // mantém o blur em toda a barra, só a mistura final é
            // que fica mais clara/transparente perto do topo.
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x59FFFFFF), // ~35% alfa
                Colors.white,
              ],
              stops: [0.0, 0.4],
            ).createShader(bounds);
          },
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: s.cardBackground.withOpacity(0.88),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: s.outline.withOpacity(0.15), width: 1),
                boxShadow: s.cardShadow,
              ),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSearchTap?.call();
                    },
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        // Fundo com opacidade fixa própria (não
                        // depende do container-pai já translúcido)
                        // + contorno visível, para nunca ficar
                        // "quase invisível" no claro; no escuro o
                        // contraste já era bom e mantém-se.
                        color: s.isDark
                            ? s.hover
                            : (s.isDark ? Colors.black : Colors.white)
                                .withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: s.outline.withOpacity(s.isDark ? 0.18 : 0.30),
                          width: 1,
                        ),
                      ),
                      child: Row(children: [
                        AppIcon('search', size: 16, color: s.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectionContainer.disabled(
                            child: Text(
                              'Pesquisar',
                              style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CircleIconButton(
                  s: s,
                  assetName: 'settings',
                  size: 40,
                  iconSize: 20,
                  onTap: onSettingsTap,
                ),
                const SizedBox(width: 6),
                _CircleIconButton(
                  s: s,
                  assetName: 'new_chat',
                  size: 40,
                  iconSize: 20,
                  onTap: onNewChatTap,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}