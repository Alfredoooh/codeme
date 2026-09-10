import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../drawer/drawermenu.dart';

enum _SearchFilter { all, conversations, files, images, videos }

class ChatSearchScreen extends StatefulWidget {
  final AppColorScheme s;
  final ValueChanged<String> onOpenConversation;
  const ChatSearchScreen({
    super.key,
    required this.s,
    required this.onOpenConversation,
  });

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  _SearchFilter _activeFilter = _SearchFilter.all;

  @override
  void initState() {
    super.initState();
    conversationsController.addListener(_onConvsChanged);
    if (conversationsController.items.isEmpty && !conversationsController.loading) {
      conversationsController.load();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    conversationsController.removeListener(_onConvsChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onConvsChanged() {
    if (mounted) setState(() {});
  }

  bool get _filterHasDataSource =>
      _activeFilter == _SearchFilter.all || _activeFilter == _SearchFilter.conversations;

  List<ConversationItem> get _baseItems {
    if (!_filterHasDataSource) return const [];
    return conversationsController.items.where((c) => !c.archived).toList();
  }

  List<ConversationItem> get _results {
    final base = _baseItems;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.preview.toLowerCase().contains(q))
        .toList();
  }

  void _openConversation(String id) {
    widget.onOpenConversation(id);
    Navigator.of(context).maybePop();
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  void _selectFilter(_SearchFilter f) {
    setState(() => _activeFilter = f);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final results = _results;

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: s.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 54),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildBody(s, results),
                    ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(
                      bottom: keyboardInset > 0
                          ? keyboardInset + 8
                          : MediaQuery.of(context).padding.bottom + 12,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: s.cardBackground,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: s.cardShadow,
                            ),
                            child: Row(children: [
                              AppIcon('search', color: s.onSurfaceVariant, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  focusNode: _focus,
                                  onChanged: (v) => setState(() => _query = v),
                                  style: TextStyle(fontSize: 15, color: s.onSurface),
                                  cursorColor: s.primary,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'Pesquisar conversas...',
                                    hintStyle: TextStyle(
                                        fontSize: 15, color: s.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 140),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: ScaleTransition(scale: anim, child: child),
                                ),
                                child: _query.isNotEmpty
                                    ? GestureDetector(
                                        key: const ValueKey('clear'),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(() {
                                          _ctrl.clear();
                                          _query = '';
                                        }),
                                        child: AppIcon('close_circular',
                                            color: s.onSurfaceVariant, size: 18),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty')),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _close,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: s.cardBackground,
                              shape: BoxShape.circle,
                              boxShadow: s.cardShadow,
                            ),
                            child: AppIcon('return',
                                color: s.onSurfaceVariant, size: 18),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.4),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  top: false,
                  child: _ElasticFilterRow(
                    s: s,
                    active: _activeFilter,
                    onSelect: _selectFilter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme s, List<ConversationItem> results) {
    if (conversationsController.loading && conversationsController.items.isEmpty) {
      return Center(
        key: const ValueKey('loading'),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant),
          ),
        ),
      );
    }

    if (!_filterHasDataSource) {
      return Center(
        key: ValueKey('coming-soon-${_activeFilter.name}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _comingSoonLabel(_activeFilter),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
          ),
        ),
      );
    }

    if (results.isEmpty) {
      final query = _query.trim();
      return Center(
        key: const ValueKey('no-results'),
        child: SelectionContainer.disabled(
          child: Text(
            query.isEmpty
                ? 'Sem conversas por aqui.'
                : 'Sem resultados para "$query"',
            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
          ),
        ),
      );
    }

    return Scrollbar(
      key: const ValueKey('results'),
      thickness: 3,
      radius: const Radius.circular(3),
      thumbVisibility: false,
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: results.length,
        itemBuilder: (_, i) {
          final item = results[results.length - 1 - i];
          return _SearchResultTile(
            s: s,
            item: item,
            onTap: () => _openConversation(item.id),
          );
        },
      ),
    );
  }

  String _comingSoonLabel(_SearchFilter f) {
    switch (f) {
      case _SearchFilter.files:
        return 'A pesquisa de arquivos ainda não está disponível.';
      case _SearchFilter.images:
        return 'A pesquisa de imagens ainda não está disponível.';
      case _SearchFilter.videos:
        return 'A pesquisa de vídeos ainda não está disponível.';
      default:
        return '';
    }
  }
}

class _ElasticFilterRow extends StatelessWidget {
  final AppColorScheme s;
  final _SearchFilter active;
  final ValueChanged<_SearchFilter> onSelect;
  const _ElasticFilterRow({
    required this.s,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _FilterToggle(
            s: s,
            label: 'Tudo',
            active: active == _SearchFilter.all,
            onTap: () => onSelect(_SearchFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterToggle(
            s: s,
            label: 'Conversas',
            active: active == _SearchFilter.conversations,
            onTap: () => onSelect(_SearchFilter.conversations),
          ),
          const SizedBox(width: 8),
          _FilterToggle(
            s: s,
            label: 'Arquivos',
            active: active == _SearchFilter.files,
            onTap: () => onSelect(_SearchFilter.files),
          ),
          const SizedBox(width: 8),
          _FilterToggle(
            s: s,
            label: 'Imagens',
            active: active == _SearchFilter.images,
            onTap: () => onSelect(_SearchFilter.images),
          ),
          const SizedBox(width: 8),
          _FilterToggle(
            s: s,
            label: 'Vídeos',
            active: active == _SearchFilter.videos,
            onTap: () => onSelect(_SearchFilter.videos),
          ),
        ],
      ),
    );
  }
}

// ✅ ALTERAÇÃO: toggle com animação Material de pressão.
// - Repouso: pill completamente arredondado (BorderRadius 999).
// - Pressionado: cantos quase quadrados (BorderRadius 6).
// - Soltar: volta a pill.
// Mesmo comportamento dos chips do Material 3 (StadiumBorder ↔
// RoundedRectangleBorder). Duração curta, easeOut.
class _FilterToggle extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterToggle({
    required this.s,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_FilterToggle> createState() => _FilterToggleState();
}

class _FilterToggleState extends State<_FilterToggle> {
  bool _pressed = false;

  static const double _restRadius = 999;
  static const double _pressedRadius = 6;
  static const Duration _anim = Duration(milliseconds: 130);

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final Color activeBg = s.isDark ? Colors.white : s.primary;
    final Color activeText = s.isDark ? Colors.black : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: _anim,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: widget.active ? activeBg : s.cardBackground,
          borderRadius: BorderRadius.circular(
            _pressed ? _pressedRadius : _restRadius,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: _anim,
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: 13,
            fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
            color: widget.active ? activeText : s.onSurfaceVariant,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final AppColorScheme s;
  final ConversationItem item;
  final VoidCallback onTap;
  const _SearchResultTile({
    required this.s,
    required this.item,
    required this.onTap,
  });
  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _h = true),
      onTapCancel: () => setState(() => _h = false),
      onTapUp: (_) => setState(() => _h = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _h ? s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.hover,
              shape: BoxShape.circle,
            ),
            child: AppIcon('chat', color: s.onSurfaceVariant, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectionContainer.disabled(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.item.preview.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.item.preview,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: s.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.item.pinned) ...[
            const SizedBox(width: 8),
            AppIcon('pin', color: s.onSurfaceVariant, size: 13),
          ],
        ]),
      ),
    );
  }
}