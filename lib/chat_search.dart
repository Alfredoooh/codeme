// ══════════════════════════════════════════════════════════════
// FILE: lib/chat_search.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';
import 'drawermenu.dart';

// ══════════════════════════════════════════════════════════════
// CHAT SEARCH SCREEN — ecrã dedicado à pesquisa de conversas.
// Aberto sempre a partir do ícone de pesquisar no drawer, com
// navegação Cupertino (CupertinoPageRoute, empurrado pelo próprio
// AppDrawer). Não pertence a HomeScreen nem à bottom tab bar — é um
// ecrã solto de topo, independente, tal como SettingsScreen.
// ══════════════════════════════════════════════════════════════

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

  void _onConvsChanged() { if (mounted) setState(() {}); }

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
    final s = widget.s;
    final results = _results;

    return Material(
      color: s.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
              child: Row(children: [
                AppTap(
                  onTap: () => Navigator.of(context).maybePop(),
                  s: s,
                  size: 40,
                  child: AppIcon('back.svg', color: s.onSurface, size: 20),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: s.hover,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(children: [
                      AppIcon('search.svg', color: s.onSurfaceVariant, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          onChanged: (v) => setState(() => _query = v),
                          style: TextStyle(fontSize: 14.5, color: s.onSurface),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Pesquisar conversas...',
                            hintStyle: TextStyle(fontSize: 14.5, color: s.onSurfaceVariant),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() {
                            _ctrl.clear();
                            _query = '';
                          }),
                          child: AppIcon('close.svg', color: s.onSurfaceVariant, size: 14),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: conversationsController.loading && conversationsController.items.isEmpty
                  ? Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant),
                        ),
                      ),
                    )
                  : results.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty ? 'Sem conversas ainda' : 'Sem resultados para "$_query"',
                            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
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
  const _SearchResultTile({required this.s, required this.item, required this.onTap});
  @override State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _h ? s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.item.title,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: s.onSurface),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (widget.item.preview.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(widget.item.preview,
                    style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          if (widget.item.pinned) ...[
            const SizedBox(width: 8),
            AppIcon('pin.svg', color: s.onSurfaceVariant, size: 13),
          ],
        ]),
      ),
    );
  }
}