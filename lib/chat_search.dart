// ══════════════════════════════════════════════════════════════
// FILE: lib/chat_search.dart
// ══════════════════════════════════════════════════════════════
// ATUALIZAÇÃO: layout invertido — a barra de pesquisa (com ícone de
// lupa, campo de texto e botão X para fechar) fica fixa em baixo do
// ecrã, dentro de um container arredondado escuro (estilo da imagem
// de referência), e a lista de resultados cresce por cima dela,
// ocupando o espaço restante acima. Aberto via fade puro
// (PageRouteBuilder em drawermenu.dart), nunca em slide. CORRIGIDO:
// ícones exclusivamente CupertinoIcons — nenhum Icons (Material) e
// nenhum SVG neste ficheiro.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'colors.dart';
import 'widgets.dart';
import 'drawermenu.dart';

// ══════════════════════════════════════════════════════════════
// CHAT SEARCH SCREEN — ecrã dedicado à pesquisa de conversas.
// Aberto sempre a partir do botão de pesquisa ao lado do pill de
// utilizador no drawer, com transição de fade puro (sem slide). Não
// pertence a HomeScreen nem à bottom tab bar — é um ecrã solto de
// topo, independente, tal como SettingsScreen.
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

  void _close() {
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
                          child: SelectionContainer.disabled(
                            child: Text(
                              _query.isEmpty ? 'Sem conversas ainda' : 'Sem resultados para "$_query"',
                              style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                      Icon(CupertinoIcons.search, color: s.onSurfaceVariant, size: 20),
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
                            hintStyle: TextStyle(fontSize: 15, color: s.onSurfaceVariant),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            _ctrl.clear();
                            _query = '';
                          }),
                          child: Icon(CupertinoIcons.mic, color: s.onSurfaceVariant, size: 19),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Container(
                    width: 48, height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.cardBackground,
                      shape: BoxShape.circle,
                      boxShadow: s.cardShadow,
                    ),
                    child: Icon(CupertinoIcons.xmark, color: s.onSurfaceVariant, size: 19),
                  ),
                ),
              ]),
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
          color: _h ? s.hover : s.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: s.cardShadow,
        ),
        child: Row(children: [
          Expanded(
            child: SelectionContainer.disabled(
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
          ),
          if (widget.item.pinned) ...[
            const SizedBox(width: 8),
            Icon(CupertinoIcons.pin_fill, color: s.onSurfaceVariant, size: 13),
          ],
        ]),
      ),
    );
  }
}