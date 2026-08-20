// ══════════════════════════════════════════════════════════════
// FILE: lib/drawermenu.dart
// ══════════════════════════════════════════════════════════════
// ATUALIZAÇÃO: cards de lista das conversas REMOVIDOS — passa a
// usar linhas soltas com divisor fino que NÃO chega até à borda da
// tela (estilo Grok), com padding lateral igual ao texto; botão de
// opções (⋮) por linha e long-press abrem o mesmo popup, ancorado
// SEMPRE na posição exata (x,y) do toque/gesto, nunca fixo; botão
// de pesquisa ao lado do pill de conta agora tem a mesma altura do
// pill (60); CupertinoScrollbar fino (estilo Apple) na lista;
// sombras reduzidas via colors.dart (cardShadow); menu de conta
// mantém a linha única "Modo claro/escuro" (sem toggle — o toggle
// de 3 estados vive exclusivamente em settings.dart/Aparência).
// Entrada para Settings (via onSettings) permanece delegada ao
// pai — quem decide a rota concreta (CupertinoPageRoute) é
// main.dart, que já foi atualizado para tal. CupertinoIcons requer
// cupertino_icons no pubspec.yaml.
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

  /// Abre o popup ancorado exatamente na posição global (x,y) onde
  /// o dedo tocou — seja vindo do TapDown do botão de opções (⋮) ou
  /// do LongPressStart na linha inteira. Já não depende de
  /// CompositedTransform/LayerLink porque a posição é sempre a do
  /// gesto, não a da linha.
  void _openConvPopupAt(BuildContext context, Offset globalPos, ConversationItem item) {
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
                    const SizedBox(width: 8),
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
              padding: const EdgeInsets.fromLTRB(24, 6, 12, 10),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _AccountPill(s: s, onOpenSettings: widget.onSettings)),
                  const SizedBox(width: 10),
                  _SearchSideButton(
                    s: s,
                    onTap: () => _openSearch(context),
                  ),
                ],
              ),
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

    // Lista solta com divisores — sem cards, sem fundo agrupado.
    // Envolvida num CupertinoScrollbar fino (estilo Apple).
    return CupertinoScrollbar(
      thickness: 3,
      thicknessWhileDragging: 5.5,
      radius: const Radius.circular(3),
      radiusWhileDragging: const Radius.circular(3),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        children: [
          if (pinned.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 6),
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
            _LooseRows(
              s: s,
              children: [
                for (final item in pinned)
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
            const SizedBox(height: 18),
          ],
          if (others.isNotEmpty)
            _LooseRows(
              s: s,
              children: [
                for (final item in others)
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

// ── Rota de transição por fade puro, sem slide, usada para abrir
// a tela de pesquisa a partir do drawer. ────────────────────────

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

// ── Ícone do header (nova conversa / fechar) — sempre dentro de
// um container circular visível, não só ao pressionar. ─────────

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
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: Icon(widget.icon, color: s.onSurfaceVariant, size: 18),
      ),
    );
  }
}

// ── Botão de pesquisa isolado, ao lado do pill de utilizador —
// agora com a MESMA altura do pill (60), não mais pequeno. ─────

class _SearchSideButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _SearchSideButton({required this.s, required this.onTap});
  @override State<_SearchSideButton> createState() => _SearchSideButtonState();
}

class _SearchSideButtonState extends State<_SearchSideButton> {
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
        width: 60, height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: Icon(CupertinoIcons.search, color: s.onSurfaceVariant, size: 22),
      ),
    );
  }
}

// ── Grupo de linhas soltas — sem card/fundo agrupado. Cada linha
// tem um Divider fino entre si, que NÃO chega até à borda da tela
// (padding lateral igual ao do texto da linha), estilo Grok. A
// última linha não tem divider abaixo. ──────────────────────────

class _LooseRows extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> children;
  const _LooseRows({required this.s, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, thickness: 1, color: s.outlineVariant),
        ));
      }
    }
    return Column(children: rows);
  }
}

// ── Conversa individual — sem card/fundo, apenas linha solta.
// Long-press E o botão de opções (⋮) abrem o popup ancorado
// exatamente na posição (x,y) do toque — para isso capturamos a
// posição global tanto do TapDown do botão como do
// LongPressStart do GestureDetector da linha inteira. Texto
// envolvido em SelectionContainer.disabled para impedir sublinhado
// amarelo de spellcheck. ─────────────────────────────────────────

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
    final swipeBg = _dragDx < 0
        ? s.error
        : _dragDx > 0
            ? s.primary
            : Colors.transparent;
    final icon = _dragDx < 0 ? CupertinoIcons.delete_solid : CupertinoIcons.archivebox_fill;
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
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ),
        Transform.translate(
          offset: Offset(_dragDx, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:   (_) => setState(() => _h = true),
            onTapCancel: ()  => setState(() => _h = false),
            onTapUp:     (_) => setState(() => _h = false),
            onTap: widget.onTap,
            onLongPressStart: (d) => widget.onOptionsAt(d.globalPosition),
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
                          fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                          color: widget.active ? s.navLabelActive : s.onSurface,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (widget.item.pinned) ...[
                  const SizedBox(width: 6),
                  Icon(CupertinoIcons.pin_fill, color: s.onSurfaceVariant, size: 13),
                  const SizedBox(width: 6),
                ],
                // Botão de opções — captura a posição global do
                // próprio toque (TapDown) para ancorar o popup ali,
                // não na linha inteira.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => widget.onOptionsAt(d.globalPosition),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(CupertinoIcons.ellipsis, color: s.onSurfaceVariant, size: 17),
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

// ── Popup de opções da conversa — OverlayEntry manual, ancorado
// exatamente na posição (x,y) global do toque que o disparou. O
// popup ajusta-se automaticamente para não sair da tela (flip para
// a esquerda/cima quando necessário). ───────────────────────────

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

  // Decide o quadrante de abertura consoante a posição do toque,
  // para o popup nunca sair da tela — mesma ideia de um
  // CupertinoContextMenu / long-press menu nativo.
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
                    s: s, icon: CupertinoIcons.arrow_up_right_square, label: 'Abrir conversa',
                    onTap: () { close(); onOpen(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: item.pinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                    label: item.pinned ? 'Desafixar' : 'Fixar',
                    onTap: () { close(); onTogglePin(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: CupertinoIcons.archivebox,
                    label: item.archived ? 'Desarquivar' : 'Arquivar',
                    onTap: () { close(); onArchive(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: CupertinoIcons.pencil, label: 'Renomear',
                    onTap: () { close(); onRename(); },
                  ),
                  _ConvPopupRow(
                    s: s, icon: CupertinoIcons.delete, label: 'Eliminar',
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _ConvPopupRow({
    required this.s,
    required this.icon,
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
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _h ? widget.s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          Icon(widget.icon, size: 18, color: color),
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
// ACCOUNT PILL — mantém a linha única "Modo claro/escuro" (sem
// toggle — isso vive exclusivamente na tela Aparência do
// settings.dart). Botão de opções abre um menu estilizado sólido,
// com escurecimento de fundo via s.barrier, cantos curvos e botão
// Cancelar 100% arredondado. Textos envolvidos em
// SelectionContainer.disabled para eliminar sublinhado amarelo de
// spellcheck do WebView/SO.
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
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'account-options',
      barrierColor: s.barrier,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secAnim) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SolidActionCard(
                        s: s,
                        rows: [
                          _SolidActionRow(
                            s: s,
                            icon: s.isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                            label: s.isDark ? 'Modo claro' : 'Modo escuro',
                            onTap: () {
                              Navigator.pop(ctx);
                              appTheme.toggleDark();
                            },
                          ),
                          _SolidActionRow(
                            s: s,
                            icon: CupertinoIcons.settings_solid,
                            label: 'Definições',
                            onTap: () {
                              Navigator.pop(ctx);
                              widget.onOpenSettings();
                            },
                          ),
                          _SolidActionRow(
                            s: s,
                            icon: CupertinoIcons.square_arrow_right,
                            label: 'Terminar sessão',
                            destructive: true,
                            onTap: () {
                              Navigator.pop(ctx);
                              authController.logout();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s.cardBackground,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: s.cardShadow,
                          ),
                          child: SelectionContainer.disabled(
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: s.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
      height: 60,
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(999),
        boxShadow: s.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: _p ? s.hover : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: s.primary, shape: BoxShape.circle),
                  child: _buildAvatarContent(s, avatar, initial, size: 40, fontSize: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectionContainer.disabled(
                    child: Text(name,
                        style: TextStyle(fontSize: 15, color: s.onSurface),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ]),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openOptions(context),
          child: Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.hover,
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.ellipsis, color: s.onSurfaceVariant, size: 19),
          ),
        ),
      ]),
    );
  }
}

// ── Card sólido de opções — cantos curvos, sombra reduzida via
// colors.dart, sem transparência/blur. ──────────────────────────

class _SolidActionCard extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> rows;
  const _SolidActionCard({required this.s, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: s.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(height: 1, thickness: 1, color: s.outline.withOpacity(0.5)),
          ],
        ],
      ),
    );
  }
}

class _SolidActionRow extends StatefulWidget {
  final AppColorScheme s;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _SolidActionRow({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  @override State<_SolidActionRow> createState() => _SolidActionRowState();
}

class _SolidActionRowState extends State<_SolidActionRow> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final color = widget.destructive ? s.error : s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _p ? s.hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 19, color: color),
            const SizedBox(width: 10),
            SelectionContainer.disabled(
              child: Text(
                widget.label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}