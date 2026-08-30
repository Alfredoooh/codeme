// ══════════════════════════════════════════════════════════════
// FILE: lib/library_screen.dart
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'apps/app_types.dart';
import 'exportservice.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _loading = true;
  String? _error;
  List<LibraryDocument> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = authController.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Sessão expirada';
      });
      return;
    }

    try {
      final conversations = await ConversationsApiService.list(token);
      final docs = <LibraryDocument>[];

      for (final conv in conversations) {
        final convId = conv['id']?.toString();
        if (convId == null) continue;
        final detail = await ConversationsApiService.get(token, convId);
        if (detail == null) continue;
        final messages = detail['messages'];
        if (messages is! List) continue;

        for (final msg in messages) {
          if (msg is! Map<String, dynamic>) continue;
          final content = msg['content']?.toString() ?? '';
          if (content.isEmpty) continue;

          final parsed = CanvasParser.parse(
            content,
            idGen: () =>
                'lib_${DateTime.now().millisecondsSinceEpoch}_${docs.length}',
          );

          for (final item in parsed.items) {
            // Converte CanvasItem (api_service) → LocalCanvasItem (app_types)
            final localItem = _toLocalCanvasItem(item);
            if (localItem == null) continue;
            docs.add(LibraryDocument(
              id: localItem.id,
              item: localItem,
              conversationId: convId,
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _documents = docs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erro ao carregar documentos: $e';
        });
      }
    }
  }

  /// Converte um CanvasItem (vindo da API) para LocalCanvasItem (usado localmente).
  /// Devolve null se o kind não for reconhecido.
  LocalCanvasItem? _toLocalCanvasItem(CanvasItem item) {
    final LocalCanvasKind kind;
    switch (item.kind) {
      case CanvasKind.doc:
        kind = LocalCanvasKind.doc;
        break;
      case CanvasKind.sheet:
        kind = LocalCanvasKind.sheet;
        break;
      case CanvasKind.slide:
        kind = LocalCanvasKind.slide;
        break;
      default:
        return null;
    }
    return LocalCanvasItem(
      id: item.id,
      title: item.title,
      kind: kind,
      content: item.content,
    );
  }

  void _openDocumentActions(LibraryDocument doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final s = AppTheme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc.item.title,
                  style: TextStyle(
                    color: s.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatLabel(doc.item.kind),
                  style:
                      TextStyle(color: s.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _ActionTile(
                  s: s,
                  assetName: 'share',
                  label: 'Partilhar',
                  subtitle: 'Envia o documento para outra app',
                  onTap: () => _shareDocument(doc),
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  s: s,
                  assetName: 'download',
                  label: 'Baixar',
                  subtitle: 'Guarda o ficheiro no formato original',
                  onTap: () => _downloadDocument(doc),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareDocument(LibraryDocument doc) async {
    try {
      final bytes = await _exportDocument(doc);
      final filename = _buildFilename(doc);
      await ExportService.shareBytes(bytes, filename: filename);
    } catch (e) {
      _showError('Erro ao partilhar: $e');
    }
  }

  Future<void> _downloadDocument(LibraryDocument doc) async {
    try {
      final bytes = await _exportDocument(doc);
      final filename = _buildFilename(doc);
      await ExportService.shareBytes(bytes, filename: filename);
    } catch (e) {
      _showError('Erro ao baixar: $e');
    }
  }

  Future<Uint8List> _exportDocument(LibraryDocument doc) async {
    final format = _formatForKind(doc.item.kind);
    return await ExportService.export(item: doc.item, format: format);
  }

  String _formatForKind(LocalCanvasKind kind) {
    switch (kind) {
      case LocalCanvasKind.doc:
        return 'pdf';
      case LocalCanvasKind.sheet:
        return 'xlsx';
      case LocalCanvasKind.slide:
        return 'pptx';
      default:
        return 'pdf';
    }
  }

  String _buildFilename(LibraryDocument doc) {
    final ext = _formatForKind(doc.item.kind);
    final safeTitle =
        doc.item.title.replaceAll(RegExp(r'[^\w\s]+'), '_');
    return '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatLabel(LocalCanvasKind kind) {
    switch (kind) {
      case LocalCanvasKind.doc:
        return 'Documento';
      case LocalCanvasKind.sheet:
        return 'Folha de cálculo';
      case LocalCanvasKind.slide:
        return 'Apresentação';
      default:
        return 'Documento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      color: s.pageBackground,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  _BackCircleButton(
                      s: s, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text(
                    'Biblioteca',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: s.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme s) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: s.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: s.error)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _loadDocuments,
              child: Text(
                'Tentar novamente',
                style: TextStyle(
                    color: s.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    if (_documents.isEmpty) {
      return Center(
        child: Text(
          'Ainda não tens documentos.',
          style: TextStyle(color: s.onSurfaceVariant, fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _documents.length,
      itemBuilder: (_, i) {
        final doc = _documents[i];
        return _LibraryCard(
          s: s,
          doc: doc,
          onTap: () => _openDocumentActions(doc),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODELOS E COMPONENTES
// ══════════════════════════════════════════════════════════════

class LibraryDocument {
  final String id;
  final LocalCanvasItem item;
  final String conversationId;
  const LibraryDocument({
    required this.id,
    required this.item,
    required this.conversationId,
  });
}

class _LibraryCard extends StatelessWidget {
  final AppColorScheme s;
  final LibraryDocument doc;
  final VoidCallback onTap;

  const _LibraryCard({
    required this.s,
    required this.doc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kindLabel = switch (doc.item.kind) {
      LocalCanvasKind.doc => 'Documento',
      LocalCanvasKind.sheet => 'Folha de cálculo',
      LocalCanvasKind.slide => 'Apresentação',
      _ => 'Documento',
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: s.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AppIcon(
                _iconForKind(doc.item.kind),
                color: s.onSurface,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kindLabel,
                    style: TextStyle(
                        fontSize: 12, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AppIcon('more_vert', color: s.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }

  String _iconForKind(LocalCanvasKind kind) {
    switch (kind) {
      case LocalCanvasKind.doc:
        return 'doc';
      case LocalCanvasKind.sheet:
        return 'table';
      case LocalCanvasKind.slide:
        return 'stacks';
      default:
        return 'doc';
    }
  }
}

class _ActionTile extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.s,
    required this.assetName,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: s.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AppIcon(assetName, color: s.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AppIcon('chevron_forward',
                color: s.onSurfaceVariant, size: 14),
          ],
        ),
      ),
    );
  }
}

class _BackCircleButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _BackCircleButton({required this.s, required this.onTap});
  @override
  State<_BackCircleButton> createState() => _BackCircleButtonState();
}

class _BackCircleButtonState extends State<_BackCircleButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: widget.s.cardShadow,
          ),
          child: AppIcon('back', size: 18, color: widget.s.onSurface),
        ),
      ),
    );
  }
}