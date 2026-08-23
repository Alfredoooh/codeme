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

// ══════════════════════════════════════════════════════════════
// TABS
// ══════════════════════════════════════════════════════════════

enum AppTab { ai, edit }

extension AppTabX on AppTab {
  String get svg => const {
        AppTab.ai:   'ai_tab.svg',
        AppTab.edit: 'edit_tab.svg',
      }[this]!;

  // Agora aponta para o mesmo asset sem sufixo filled
  String get svgFilled => svg;

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
  // 0 = Conversas, 1 = Fixadas
  int _selectedSection = 0;

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

  void _handleNewChat() {
    HapticFeedback.lightImpact();
    widget.onNewChat?.call();
    _closeDrawer();
  }

  void _openAccountOptions(BuildContext context, Offset globalPosition) {
    HapticFeedback.lightImpact();
    showAccountOptionsPopupAt(
      context,
      widget.s,
      position: globalPosition,
      onToggleTheme: () {
        appTheme.toggleDark();
      },
      onOpenSettings: widget.onSettings,
      onLogout: () {
        authController.logout();
      },
    );
  }

  void _openSearch(BuildContext context) {
    HapticFeedback.lightImpact();
    _closeDrawer();
    Navigator.of(context).push(_FadePageRoute(
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

  void _openConvPopupAt(BuildContext context, Offset globalPos, ConversationItem item) {
    HapticFeedback.lightImpact();
    showConversationOptionsPopupAt(
      context,
      widget.s,
      position: globalPos,
      item: item,
      onOpen: () => _openConversation(item),
      onTogglePin: () => conversationsController.togglePin(item.id, !item.pinned),
      onArchive: () => conversationsController.archive(item.id, !item.archived),
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
        child: Stack(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),
              Expanded(
                child: _buildConvBody(context, s, pinned, others),
              ),
              const SizedBox(height: 120),
            ],
          ),

          // Header — avatar à esquerda, segmented central e botão de
          // opções da conta à direita (ancorado corretamente).
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    s.pageBackground,
                    s.pageBackground.withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Avatar circular — substitui o texto "Menu"
                  _AvatarCircleButton(
                    s: s,
                    onTap: widget.onSettings,
                  ),
                  const SizedBox(width: 12),
                  // Segmented control no meio do header
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: _DrawerSegmentedControl(
                          s: s,
                          selectedIndex: _selectedSection,
                          onChanged: (i) {
                            if (i == _selectedSection) return;
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSection = i);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botão de opções da conta — com onTapDown para
                  // obter a posição exata e abrir o popup ancorado.
                  _CircleIconButton(
                    s: s,
                    assetName: 'more_vert',
                    size: 40,
                    iconSize: 20,
                    onTapDown: (pos) => _openAccountOptions(context, pos),
                  ),
                ],
              ),
            ),
          ),

          // Rodapé — apenas search pill e botão de nova conversa
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    s.pageBackground,
                    s.pageBackground.withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _SearchPill(s: s, onTap: () => _openSearch(context))),
                  const SizedBox(width: 10),
                  _CircleIconButton(
                    s: s,
                    assetName: 'new_chat',
                    size: 52,
                    iconSize: 22,
                    onTap: widget.onNewChat != null ? _handleNewChat : null,
                  ),
                ],
              ),
            ),
          ),
        ]),
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
    if (conversationsController.items.isEmpty) {
      return Center(
        child: Text(
          'Sem conversas ainda',
          style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
        ),
      );
    }

    final activeList = _selectedSection == 0 ? others : pinned;

    if (activeList.isEmpty) {
      return Center(
        child: Text(
          _selectedSection == 0 ? 'Sem conversas' : 'Sem conversas fixadas',
          style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
        ),
      );
    }

    return CupertinoScrollbar(
      thickness: 3,
      thicknessWhileDragging: 5.5,
      radius: const Radius.circular(3),
      radiusWhileDragging: const Radius.circular(3),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        children: [
          _LooseRows(
            s: s,
            children: [
              for (final item in activeList)
                _ConvTile(
                  s: s,
                  item: item,
                  active: item.id == widget.activeConversationId,
                  onTap: () => _openConversation(item),
                  onOptionsAt: (pos) => _openConvPopupAt(context, pos, item),
                  onArchive: () => conversationsController.archive(item.id, true),
                  onDelete: () => conversationsController.delete(item.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Avatar circular para o header ─────────────────────────────

class _AvatarCircleButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _AvatarCircleButton({required this.s, required this.onTap});
  @override State<_AvatarCircleButton> createState() => _AvatarCircleButtonState();
}

class _AvatarCircleButtonState extends State<_AvatarCircleButton> {
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
        gaplessPlayback: true,
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
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final user = authController.user;
    final name = user?.name ?? 'Utilizador';
    final avatar = user?.avatar;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

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
        curve: kCupertinoOut,
        child: Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _p ? s.hover : s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: s.cardShadow,
          ),
          child: _buildAvatarContent(s, avatar, initial, size: 38, fontSize: 16),
        ),
      ),
    );
  }
}

// ── Segmented control do drawer — 36 de altura, estilo settings ─

class _DrawerSegmentedControl extends StatefulWidget {
  final AppColorScheme s;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _DrawerSegmentedControl({
    required this.s,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<_DrawerSegmentedControl> createState() => _DrawerSegmentedControlState();
}

class _DrawerSegmentedControlState extends State<_DrawerSegmentedControl> {
  static const _options = ['Conversas', 'Fixadas'];

  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: s.hover,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / _options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: segmentWidth * widget.selectedIndex.clamp(0, _options.length - 1),
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: s.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: s.cardShadow,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _options.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown:   (_) => setState(() => _pressedIndex = i),
                    onTapCancel: ()  => setState(() => _pressedIndex = null),
                    onTapUp:     (_) => setState(() => _pressedIndex = null),
                    onTap: () => widget.onChanged(i),
                    child: AnimatedScale(
                      scale: _pressedIndex == i ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: kCupertinoOut,
                      child: Center(
                        child: SelectionContainer.disabled(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: widget.selectedIndex == i
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: widget.selectedIndex == i
                                  ? s.onPrimary
                                  : s.onSurfaceVariant,
                            ),
                            child: Text(_options[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]);
      }),
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

// ── Botão circular genérico — agora com suporte a onTapDown para
// ancoragem de popups. ─────────────────────────────────────────

class _CircleIconButton extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onTapDown;
  final double size;
  final double iconSize;
  const _CircleIconButton({
    required this.s,
    required this.assetName,
    this.onTap,
    this.onTapDown,
    this.size = 40,
    this.iconSize = 20,
  });
  @override State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
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
        curve: kCupertinoOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: widget.size, height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _p ? s.pressed : s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: s.cardShadow,
          ),
          child: AppIcon(widget.assetName, color: s.onSurface, size: widget.iconSize),
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

// ── Conversa individual — sem ícone more_vert, apenas long press ──

class _ConvTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<Offset> onOptionsAt;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  const _ConvTile({
    required this.s,
    required this.item,
    required this.active,
    required this.onTap,
    required this.onOptionsAt,
    required this.onArchive,
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
      HapticFeedback.lightImpact();
      setState(() => _resolved = true);
      widget.onDelete();
    } else if (_dragDx >= _threshold) {
      HapticFeedback.lightImpact();
      setState(() => _resolved = true);
      widget.onArchive();
    } else {
      setState(() => _dragDx = 0);
    }
  }

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
    final swipeBg = _dragDx < 0
        ? s.error
        : _dragDx > 0
            ? s.primary
            : Colors.transparent;
    final iconAsset = _dragDx < 0 ? 'trash' : 'archive_solid';
    final iconColor = _dragDx < 0 ? s.onError : s.onPrimary;

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
              child: AppIcon(iconAsset, color: iconColor, size: 18),
            ),
          ),
        Transform.translate(
          offset: Offset(_dragDx, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:   (_) => setState(() => _h = true),
            onTapCancel: ()  => setState(() => _h = false),
            onTapUp:     (_) => setState(() => _h = false),
            onTap: _handleTap,
            onLongPressStart: _handleLongPressStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: Container(
              color: widget.active
                  ? s.navIndicatorBg
                  : (_h ? s.hover : Colors.transparent),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: SelectionContainer.disabled(
                    child: Text(widget.item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                          color: widget.active ? s.navLabelActive : s.onSurface,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Popup de opções da conversa ───────────────────────────────

void showConversationOptionsPopupAt(
  BuildContext context,
  AppColorScheme s, {
  required Offset position,
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
    duration: const Duration(milliseconds: 190),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  final screenSize = MediaQuery.of(context).size;
  const width = 232.0;
  const estimatedHeight = 230.0;

  final openLeft = position.dx + width > screenSize.width - 12;
  final openUp = position.dy + estimatedHeight > screenSize.height - 12;

  final left = openLeft ? (position.dx - width).clamp(8.0, screenSize.width - width - 8) : position.dx.clamp(8.0, screenSize.width - width - 8);
  final top = openUp ? (position.dy - estimatedHeight).clamp(8.0, screenSize.height - estimatedHeight - 8) : position.dy.clamp(8.0, screenSize.height - estimatedHeight - 8);

  final alignment = Alignment(
    openLeft ? 1.0 : -1.0,
    openUp ? 1.0 : -1.0,
  );

  entry = OverlayEntry(builder: (ctx) {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: close,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, child) => Opacity(
            opacity: CurvedAnimation(
                    parent: controller, curve: const Interval(0, 0.5, curve: Curves.easeOut))
                .value,
            child: Transform.scale(
              scale: Tween(begin: 0.9, end: 1.0)
                  .animate(CurvedAnimation(parent: controller, curve: kCupertinoOut))
                  .value,
              alignment: alignment,
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ConvPopupRow(
                    s: s, assetName: 'open', label: 'Abrir conversa',
                    onTap: () { close(); onOpen(); },
                  ),
                  _ConvPopupRow(
                    s: s, assetName: item.pinned ? 'pin_slash' : 'pin',
                    label: item.pinned ? 'Desafixar' : 'Fixar',
                    onTap: () { close(); onTogglePin(); },
                  ),
                  _ConvPopupRow(
                    s: s, assetName: 'archive',
                    label: item.archived ? 'Desarquivar' : 'Arquivar',
                    onTap: () { close(); onArchive(); },
                  ),
                  _ConvPopupRow(
                    s: s, assetName: 'pencil', label: 'Renomear',
                    onTap: () { close(); onRename(); },
                  ),
                  _ConvPopupRow(
                    s: s, assetName: 'trash', label: 'Eliminar',
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
  final String assetName;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _ConvPopupRow({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
    this.destructive = false,
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
      onTap:       () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _h ? widget.s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          AppIcon(widget.assetName, size: 18, color: color),
          const SizedBox(width: 10),
          SelectionContainer.disabled(
            child: Text(widget.label,
                style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
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
        curve: kCupertinoOut,
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
// SEARCH PILL — substitui o AccountPill
// ══════════════════════════════════════════════════════════════

class _SearchPill extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _SearchPill({required this.s, required this.onTap});
  @override State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
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
        scale: _p ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 52,
          decoration: BoxDecoration(
            color: _p ? s.hover : s.cardBackground,
            borderRadius: BorderRadius.circular(999),
            boxShadow: s.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            AppIcon('search', color: s.onSurfaceVariant, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: SelectionContainer.disabled(
                child: Text(
                  'Escreve aqui para pesquisar...',
                  style: TextStyle(fontSize: 15, color: s.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Popup de opções da conta ──────────────────────────────────

void showAccountOptionsPopupAt(
  BuildContext context,
  AppColorScheme s, {
  required Offset position,
  required VoidCallback onToggleTheme,
  required VoidCallback onOpenSettings,
  required VoidCallback onLogout,
}) {
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

  final screenSize = MediaQuery.of(context).size;
  const width = 240.0;
  const estimatedHeight = 170.0;

  final openLeft = position.dx + width > screenSize.width - 12;
  final openUp = position.dy + estimatedHeight > screenSize.height - 12;

  final left = openLeft ? (position.dx - width).clamp(8.0, screenSize.width - width - 8) : position.dx.clamp(8.0, screenSize.width - width - 8);
  final top = openUp ? (position.dy - estimatedHeight).clamp(8.0, screenSize.height - estimatedHeight - 8) : position.dy.clamp(8.0, screenSize.height - estimatedHeight - 8);

  final alignment = Alignment(
    openLeft ? 1.0 : -1.0,
    openUp ? 1.0 : -1.0,
  );

  entry = OverlayEntry(builder: (ctx) {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: close,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, child) => Opacity(
            opacity: CurvedAnimation(
                    parent: controller, curve: const Interval(0, 0.5, curve: Curves.easeOut))
                .value,
            child: Transform.scale(
              scale: Tween(begin: 0.9, end: 1.0)
                  .animate(CurvedAnimation(parent: controller, curve: kCupertinoOut))
                  .value,
              alignment: alignment,
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AccountPopupRow(
                    s: s,
                    assetName: s.isDark ? 'sun' : 'moon',
                    label: s.isDark ? 'Modo claro' : 'Modo escuro',
                    onTap: () { close(); onToggleTheme(); },
                  ),
                  _AccountPopupRow(
                    s: s,
                    assetName: 'settings',
                    label: 'Definições',
                    onTap: () { close(); onOpenSettings(); },
                  ),
                  _AccountPopupRow(
                    s: s,
                    assetName: 'logout',
                    label: 'Terminar sessão',
                    destructive: true,
                    onTap: () { close(); onLogout(); },
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

// ── Linha do popup da conta ──────────────────────────────────

class _AccountPopupRow extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _AccountPopupRow({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  @override State<_AccountPopupRow> createState() => _AccountPopupRowState();
}

class _AccountPopupRowState extends State<_AccountPopupRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.destructive ? widget.s.error : widget.s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _h ? widget.s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          AppIcon(widget.assetName, size: 18, color: color),
          const SizedBox(width: 10),
          SelectionContainer.disabled(
            child: Text(widget.label,
                style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}