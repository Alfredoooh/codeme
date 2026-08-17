// ══════════════════════════════════════════════════════════════
// FILE: lib/chat_search.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';
import 'drawermenu.dart';

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

class _ChatSearchScreenState extends State<ChatSearchScreen>
    with ThemeReactive<ChatSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    conversationsController.addListener(_onConvsChanged);
    if (conversationsController.items.isEmpty &&
        !conversationsController.loading) {
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

  List<ConversationItem> get _results {
    final q = _query.trim().toLowerCase();
    final all = conversationsController.items.where((c) => !c.archived);
    if (q.isEmpty) return all.toList();
    return all
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.preview.toLowerCase().contains(q))
        .toList();
  }

  void _openConversation(String id) {
    widget.onOpenConversation(id);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final results = _results;

    return Material(
      color: s.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSpaceS,
                kSpaceS,
                kSpaceL,
                kSpaceS,
              ),
              child: Row(
                children: [
                  AppTap(
                    onTap: () => Navigator.of(context).maybePop(),
                    s: s,
                    size: kSpaceXXXL + kSpaceS,
                    child: AppIcon('back.svg', color: s.onSurface, size: 20),
                  ),
                  SizedBox(width: kSpaceXS),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: EdgeInsets.symmetric(horizontal: kSpaceM),
                      decoration: BoxDecoration(
                        color: s.controlDefault,
                        borderRadius: BorderRadius.circular(kRadiusCircle),
                      ),
                      child: Row(
                        children: [
                          AppIcon('search.svg',
                              color: s.onSurfaceVariant, size: 16),
                          SizedBox(width: kSpaceS),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              onChanged: (v) => setState(() => _query = v),
                              style: TextStyle(
                                fontSize: kTypeBody,
                                color: s.onSurface,
                              ),
                              cursorColor: s.primary,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Pesquisar conversas...',
                                hintStyle: TextStyle(
                                  fontSize: kTypeBody,
                                  color: s.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            AppTap(
                              onTap: () => setState(() {
                                _ctrl.clear();
                                _query = '';
                              }),
                              s: s,
                              size: 28,
                              child: AppIcon(
                                'close.svg',
                                color: s.onSurfaceVariant,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: conversationsController.loading &&
                      conversationsController.items.isEmpty
                  ? Center(
                      child: FluentShimmer(
                        s: s,
                        width: kSpaceXXXL,
                        height: kSpaceXXXL,
                      ),
                    )
                  : results.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty
                                ? 'Sem conversas ainda'
                                : 'Sem resultados para "$_query"',
                            style: TextStyle(
                              fontSize: kTypeBody,
                              color: s.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            kSpaceM,
                            kSpaceXS,
                            kSpaceM,
                            kSpaceXL,
                          ),
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final item = results[i];
                            return _SearchResultTile(
                              s: s,
                              item: item,
                              onTap: () => _openConversation(item.id),
                            );
                          },
                        ),
            ),
          ],
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
        duration: kDurationFast,
        margin: const EdgeInsets.symmetric(vertical: kSpaceXXS),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceM,
          vertical: kSpaceM,
        ),
        decoration: BoxDecoration(
          color: _h ? s.subtleFillHover : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusXLarge),
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
                      fontWeight: FontWeight.w600,
                      color: s.onSurface,
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
                        color: s.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.item.pinned) ...[
              SizedBox(width: kSpaceS),
              AppIcon('pin.svg', color: s.onSurfaceVariant, size: 13),
            ],
          ],
        ),
      ),
    );
  }
}