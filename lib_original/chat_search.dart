// ══════════════════════════════════════════════════════════════
// FILE: lib/chat_search.dart
// ══════════════════════════════════════════════════════════════
// ATUALIZAÇÃO: ecrã de pesquisa agora começa vazio (não lista as
// conversas automaticamente); mostra estado inicial "pesquise" e
// apenas apresenta cards quando o utilizador escreve algo.
// Ícones exclusivamente SVG via AppIcon (search, close, pin), como
// nos restantes ecrãs. Animações mais suaves com AnimatedSwitcher
// e curvas easeOutCubic. A barra de pesquisa continua a subir com
// o teclado.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  void _onConvsChanged() {
    if (mounted) setState(() {});
  }

  List<ConversationItem> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final all = conversationsController.items.where((c) => !c.archived);
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
    final query = _query.trim();

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: s.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildBody(s, query, results),
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
                        if (_query.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              _ctrl.clear();
                              _query = '';
                            }),
                            child: AppIcon('close',
                                color: s.onSurfaceVariant, size: 14),
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
                      child: AppIcon('close',
                          color: s.onSurfaceVariant, size: 16),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme s, String query, List<ConversationItem> results) {
    if (query.isEmpty) {
      return _InitialSearchPrompt(key: const ValueKey('initial'), s: s);
    }

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

    if (results.isEmpty) {
      return Center(
        key: const ValueKey('no-results'),
        child: SelectionContainer.disabled(
          child: Text(
            'Sem resultados para "$query"',
            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
          ),
        ),
      );
    }

    return CupertinoScrollbar(
      key: const ValueKey('results'),
      thickness: 3,
      thicknessWhileDragging: 5.5,
      radius: const Radius.circular(3),
      radiusWhileDragging: const Radius.circular(3),
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
}

class _InitialSearchPrompt extends StatelessWidget {
  final AppColorScheme s;
  const _InitialSearchPrompt({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.65,
              child: AppIcon('search', color: s.onSurfaceVariant, size: 52),
            ),
            const SizedBox(height: 18),
            Text(
              'Pesquise as suas conversas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Digite para encontrar títulos ou pré-visualizações.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: s.onSurfaceVariant,
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
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
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