// ══════════════════════════════════════════════════════════════
// FILE: lib/drawermenu.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;
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
import 'sheets.dart';
import 'library_screen.dart';
import 'scheduled_tasks_screen.dart';
import 'all_apps_screen.dart';
import 'apps/app_types.dart';
import 'apps/docs.dart';
import 'apps/sheets_app.dart';
import 'apps/slides_app.dart';
import 'apps/sound.dart';

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
// PULL-TO-REFRESH — anel cônico translúcido, replica o HTML de referência
// ══════════════════════════════════════════════════════════════

// Pinta o mesmo anel do CSS:
// conic-gradient(from 0deg, #111 0deg, #777 90deg, #ddd 180deg, transparent 260deg, #111 360deg)
// com um "buraco" no meio (equivalente ao ::after com inset:3px e fundo sólido).
class _ConicRingPainter extends CustomPainter {
  final double rotationTurns; // 0..1, gira continuamente
  final Color solidColor;     // #111 equivalente
  final Color midColor;       // #777 equivalente
  final Color lightColor;     // #ddd equivalente
  final double strokeWidth;

  _ConicRingPainter({
    required this.rotationTurns,
    required this.solidColor,
    required this.midColor,
    required this.lightColor,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 6.28318530718, // 2*pi
      transform: GradientRotation(rotationTurns * 6.28318530718),
      colors: [
        solidColor,
        midColor,
        lightColor,
        lightColor.withOpacity(0.0), // transparent em 260deg
        solidColor,
      ],
      stops: const [0.0, 0.25, 0.5, 0.7222, 1.0], // 0/90/180/260/360 sobre 360
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _ConicRingPainter oldDelegate) =>
      oldDelegate.rotationTurns != rotationTurns ||
      oldDelegate.solidColor != solidColor ||
      oldDelegate.midColor != midColor ||
      oldDelegate.lightColor != lightColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

class GradientRingLoader extends StatefulWidget {
  final double size;
  final double opacity;
  final double scale;
  final Color solidColor;
  final Color midColor;
  final Color lightColor;

  const GradientRingLoader({
    super.key,
    required this.size,
    required this.opacity,
    required this.scale,
    required this.solidColor,
    required this.midColor,
    required this.lightColor,
  });

  @override
  State<GradientRingLoader> createState() => _GradientRingLoaderState();
}

class _GradientRingLoaderState extends State<GradientRingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750), // .75s linear infinite, igual ao HTML
  )..repeat();

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: widget.scale,
        child: AnimatedBuilder(
          animation: _spinCtrl,
          builder: (_, __) => CustomPaint(
            size: Size.square(widget.size),
            painter: _ConicRingPainter(
              rotationTurns: _spinCtrl.value,
              solidColor: widget.solidColor,
              midColor: widget.midColor,
              lightColor: widget.lightColor,
              strokeWidth: widget.size * 0.11, // proporcional ao inset:3px de 27px
            ),
          ),
        ),
      ),
    );
  }
}

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

class _AppDrawerState extends State<AppDrawer> with SingleTickerProviderStateMixin {
  bool _pinnedExpanded = true;
  bool _allExpanded = true;

  // ── Pull-to-refresh: réplica 1:1 da física do HTML de referência ──
  static const double _trigger = 78.0;
  static const double _maxPull = 125.0;
  static const double _indicatorHeight = 82.0;

  double _pull = 0.0;       // posição atual do puxão em px (equivalente à var `pull` do JS)
  double _dragStartY = 0.0;
  bool _dragging = false;
  bool _refreshing = false;

  // Controller que conduz as animações de settle/reset com o mesmo
  // easing cúbico do HTML: 1 - (1-t)^3
  late final AnimationController _settleCtrl = AnimationController(vsync: this);
  Animation<double>? _settleAnim;

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
    _settleCtrl.dispose();
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
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => const AllAppsScreen(),
      ));
    });
  }

  // ── Física do pull: idêntica ao touchmove do HTML ──────────

  void _renderPull(double value) {
    setState(() => _pull = value);
  }

  void _onDragStart(DragStartDetails d, ScrollController scrollCtrl) {
    if (_refreshing) return;
    if (scrollCtrl.hasClients && scrollCtrl.offset > 0) return;
    _dragging = true;
    _dragStartY = d.globalPosition.dy;
    _settleCtrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging || _refreshing) return;

    final distance = d.globalPosition.dy - _dragStartY;

    if (distance <= 0) {
      _renderPull(0);
      return;
    }

    // Curva de resistência exata do HTML:
    // distance < trigger ? distance*.72 : trigger*.72 + (distance-trigger)*.32
    final value = (distance < _trigger
            ? distance * 0.72
            : _trigger * 0.72 + (distance - _trigger) * 0.32)
        .clamp(0.0, _maxPull);

    _renderPull(value);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragging || _refreshing) return;
    _dragging = false;

    if (_pull >= _trigger) {
      _startRefresh();
    } else {
      _animateTo(0.0, duration: const Duration(milliseconds: 300));
    }
  }

  // Easing cúbico 1-(1-t)^3, igual ao animate()/reset() do HTML.
  void _animateTo(double target, {required Duration duration, VoidCallback? onDone}) {
    _settleCtrl.stop();
    _settleCtrl.duration = duration;
    _settleAnim = Tween<double>(begin: _pull, end: target).animate(
      CurvedAnimation(parent: _settleCtrl, curve: Curves.easeOutCubic),
    )..addListener(() {
        if (mounted) setState(() => _pull = _settleAnim!.value);
      });
    _settleCtrl.forward(from: 0).whenComplete(() => onDone?.call());
  }

  Future<void> _startRefresh() async {
    _refreshing = true;
    _animateTo(_trigger, duration: const Duration(milliseconds: 220));

    await conversationsController.load();
    if (!mounted) return;

    _animateTo(0.0, duration: const Duration(milliseconds: 400), onDone: () {
      _refreshing = false;
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
                const SizedBox(height: 112),
              ],
            ),

            // Progressão real da opacidade/escala igual ao render() do HTML:
            // loader.opacity = min(progress*1.4, 1); loader.scale = .5 + progress*.5
            Builder(builder: (_) {
              final progress = (_pull / _trigger).clamp(0.0, 1.0);
              return Positioned(
                top: 48, left: 0, right: 0,
                height: _indicatorHeight,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 17),
                      child: GradientRingLoader(
                        size: 27,
                        opacity: (progress * 1.4).clamp(0.0, 1.0),
                        scale: 0.5 + progress * 0.5,
                        solidColor: s.onSurface,
                        midColor: s.onSurfaceVariant,
                        lightColor: s.outline,
                      ),
                    ),
                  ),
                ),
              );
            }),

            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Curva não-linear (mais opaco perto da borda, dissolve rápido
                    // perto do fim) — padrão comum em headers iOS/Android, em vez
                    // de um degradê reto de dois pontos.
                    stops: const [0.0, 0.45, 0.75, 1.0],
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.92),
                      s.pageBackground.withOpacity(0.45),
                      s.pageBackground.withOpacity(0.0),
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

            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.45, 0.75, 1.0],
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.92),
                      s.pageBackground.withOpacity(0.45),
                      s.pageBackground.withOpacity(0.0),
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
    if (conversationsController.loading && conversationsController.items.isEmpty) {
      return Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            strokeCap: StrokeCap.round,
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
      if (_pinnedExpanded) {
        sections.add(_LooseRows(
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
    }

    if (others.isNotEmpty) {
      sections.add(_ConversationGroupHeader(
        s: s,
        label: 'Todas as conversas',
        expanded: _allExpanded,
        onTap: () => setState(() => _allExpanded = !_allExpanded),
      ));
      if (_allExpanded) {
        sections.add(_LooseRows(
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
    }

    // O ScrollController é criado aqui porque _onDragStart precisa
    // consultar scrollCtrl.offset (equivalente a scroll.scrollTop no HTML)
    // para só iniciar o pull quando já está no topo da lista.
    return _PullDetectorScope(
      onDragStart: _onDragStart,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      builder: (scrollCtrl) => Transform.translate(
        // content.style.transform = translate3d(0,value,0) — 1:1, sem
        // animação implícita própria; quem anima é o _settleCtrl.
        offset: Offset(0, _pull),
        child: ListView(
          controller: scrollCtrl,
          physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          children: sections,
        ),
      ),
    );
  }
}

// Isola o ScrollController + os três gestos de drag (start/update/end)
// num único widget para que _onDragStart consiga ler scrollCtrl.offset,
// exatamente como o HTML lê scroll.scrollTop antes de decidir se o pull
// deve começar.
class _PullDetectorScope extends StatefulWidget {
  final void Function(DragStartDetails, ScrollController) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final void Function(DragEndDetails) onDragEnd;
  final Widget Function(ScrollController) builder;

  const _PullDetectorScope({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.builder,
  });

  @override
  State<_PullDetectorScope> createState() => _PullDetectorScopeState();
}

class _PullDetectorScopeState extends State<_PullDetectorScope> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (d) => widget.onDragStart(d, _scrollCtrl),
      onVerticalDragUpdate: widget.onDragUpdate,
      onVerticalDragEnd: widget.onDragEnd,
      child: widget.builder(_scrollCtrl),
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
        child: Container(
          width: _buttonSize, height: _buttonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _p ? s.hover : s.outline,
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

// ── Popup de opções da conversa (nativo) ─────────────────────

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

  final RelativeRect menuPosition = RelativeRect.fromLTRB(
    position.dx,
    position.dy,
    screenSize.width - position.dx,
    screenSize.height - position.dy,
  );

  final result = await showMenu<_ConversationPopupAction>(
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

// ── Popup de opções da conta (nativo) ─────────────────────────

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

  final result = await showMenu<_AccountPopupAction>(
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