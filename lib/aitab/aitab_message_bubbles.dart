// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_message_bubbles.dart
// Bolhas de mensagem (utilizador, assistente, streaming), carrossel
// de imagens de pesquisa, fontes, e cards de resultado de tool
// (imagem visual e download de documento).
// ══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../colors.dart';
import '../widgets.dart';
import '../richtext.dart';
import '../app_sheet.dart';
import '../aiwidgets.dart';
import '../apps/app_types.dart';
import '../sheets.dart';
import 'aitab_models.dart';
import 'aitab_widgets_shared.dart';
import 'aitab_progress_cards.dart';

// ══════════════════════════════════════════════════════════════
// BOLHA DO UTILIZADOR
// ══════════════════════════════════════════════════════════════

class UserBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onSelectText;
  const UserBubble({
    super.key,
    required this.s,
    required this.text,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onSelectText,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = s.userBubbleBg;
    final textColor = s.userBubbleText;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () {
          final box = context.findRenderObject() as RenderBox;
          final off = box.localToGlobal(Offset.zero);
          final sz = box.size;
          showMessageActionsPopup(
            context,
            s,
            anchorOffset: off,
            anchorSize: sz,
            onEdit: onEdit,
            onCopy: onCopy,
            onDelete: onDelete,
            onSelectText: onSelectText,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: s.cardShadow,
          ),
          child: Text(text,
              style: TextStyle(color: textColor, fontSize: 14)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CARDS DE RESULTADO DE TOOL
// ══════════════════════════════════════════════════════════════

class ToolResultImageCard extends StatelessWidget {
  final AppColorScheme s;
  final String base64Png;
  final String label;

  const ToolResultImageCard({
    super.key,
    required this.s,
    required this.base64Png,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(base64Png);
    return GestureDetector(
      onTap: () => _openFullscreen(context, bytes, label),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.memory(bytes, fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ),
                  AppIcon('expand', size: 16, color: s.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, Uint8List bytes, String label) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullscreenImageScreen(bytes: bytes, label: label),
    ));
  }
}

class _FullscreenImageScreen extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  const _FullscreenImageScreen({required this.bytes, required this.label});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Scaffold(
      backgroundColor: s.pageBackground,
      appBar: AppBar(
        backgroundColor: s.pageBackground,
        elevation: 0,
        foregroundColor: s.onSurface,
        title: Text(label, style: TextStyle(fontSize: 15, color: s.onSurface)),
        actions: [
          IconButton(
            icon: AppIcon('share1', color: s.onSurface, size: 20),
            onPressed: () async {
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/imagem.png');
              await file.writeAsBytes(bytes);
              await Share.shareXFiles([XFile(file.path)]);
            },
          ),
        ],
      ),
      body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
    );
  }
}

class ToolResultDownloadCard extends StatelessWidget {
  final AppColorScheme s;
  final String base64Data;
  final String filename;
  final String mimeType;

  const ToolResultDownloadCard({
    super.key,
    required this.s,
    required this.base64Data,
    required this.filename,
    required this.mimeType,
  });

  String get _icon {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.docx')) return 'doc';
    if (lower.endsWith('.xlsx')) return 'table';
    if (lower.endsWith('.pptx')) return 'stacks';
    return 'doc';
  }

  String get _label {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'Documento PDF';
    if (lower.endsWith('.docx')) return 'Documento Word';
    if (lower.endsWith('.xlsx')) return 'Folha de cálculo';
    if (lower.endsWith('.pptx')) return 'Apresentação';
    return 'Documento';
  }

  Future<void> _download(BuildContext context) async {
    try {
      final bytes = base64Decode(base64Data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao preparar download: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _download(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 420),
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
                color: s.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppIcon(_icon, size: 22, color: s.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                  const SizedBox(height: 2),
                  Text(_label, style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppIcon('download', size: 20, color: s.primary),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CARROSSEL DE IMAGENS DE PESQUISA
// ══════════════════════════════════════════════════════════════

class ImageSearchCarousel extends StatelessWidget {
  final AppColorScheme s;
  final List<Map<String, dynamic>> images;
  const ImageSearchCarousel({super.key, required this.s, required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 160,
        child: ScrollConfiguration(
          behavior: const _ElasticScrollBehavior(),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final img = images[i];
              final url = img['imageUrl']?.toString() ?? '';
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _ImageSearchFullscreenScreen(
                    images: images,
                    initialIndex: i,
                  ),
                )),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    url,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 160,
                        height: 160,
                        color: s.hover,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant),
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: 160,
                      height: 160,
                      color: s.hover,
                      child: Icon(Icons.image_not_supported_outlined, color: s.onSurfaceVariant),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ElasticScrollBehavior extends ScrollBehavior {
  const _ElasticScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _ImageSearchFullscreenScreen extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  const _ImageSearchFullscreenScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageSearchFullscreenScreen> createState() => _ImageSearchFullscreenScreenState();
}

class _ImageSearchFullscreenScreenState extends State<_ImageSearchFullscreenScreen> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final currentTitle = widget.images[_current]['title']?.toString() ?? '';
    return Scaffold(
      backgroundColor: s.pageBackground,
      appBar: AppBar(
        backgroundColor: s.pageBackground,
        elevation: 0,
        foregroundColor: s.onSurface,
        title: Text(
          currentTitle.isEmpty ? '${_current + 1}/${widget.images.length}' : currentTitle,
          style: TextStyle(fontSize: 15, color: s.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final url = widget.images[i]['imageUrl']?.toString() ?? '';
          return Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: s.onSurfaceVariant, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FONTES (web_search)
// ══════════════════════════════════════════════════════════════

class SourcesRow extends StatelessWidget {
  final AppColorScheme s;
  final List<String> urls;
  const SourcesRow({super.key, required this.s, required this.urls});

  String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String _faviconUrl(String url) => 'https://www.google.com/s2/favicons?sz=64&domain=${_domain(url)}';

  void _openSourcesModal(BuildContext context) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      title: 'Fontes',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SheetOptionsGroup(
          s: s,
          options: urls.map((url) {
            return _SourceRow(s: s, url: url, domain: _domain(url), faviconUrl: _faviconUrl(url));
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _openSourcesModal(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20,
              width: 20.0 + (urls.length - 1).clamp(0, 3) * 12.0,
              child: Stack(
                children: [
                  for (int i = 0; i < urls.length.clamp(0, 4); i++)
                    Positioned(
                      left: i * 12.0,
                      child: ClipOval(
                        child: Container(
                          width: 20,
                          height: 20,
                          color: s.cardBackground,
                          child: Image.network(
                            _faviconUrl(urls[i]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: s.hover),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('Fontes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: s.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final AppColorScheme s;
  final String url;
  final String domain;
  final String faviconUrl;
  const _SourceRow({required this.s, required this.url, required this.domain, required this.faviconUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ClipOval(
              child: Container(
                width: 28,
                height: 28,
                color: s.hover,
                child: Image.network(
                  faviconUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.public, size: 14, color: s.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(domain, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                  Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOLHA DO ASSISTENTE (já finalizada)
// ══════════════════════════════════════════════════════════════

class AssistantBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final String? thinking;
  final List<LocalCanvasItem> canvases;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  const AssistantBubble({
    super.key,
    required this.s,
    required this.text,
    this.thinking,
    required this.canvases,
    required this.onOpenCanvas,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final v in extractVisualResults(text))
                ToolResultImageCard(s: s, base64Png: v.base64Png, label: v.label),
              for (final d in extractDocumentResults(text))
                ToolResultDownloadCard(s: s, base64Data: d.base64Data, filename: d.filename, mimeType: d.mimeType),
              ImageSearchCarousel(s: s, images: extractImages(text)),
              if (thinking != null && thinking!.isNotEmpty)
                _ThinkingHistoryCollapsible(
                  s: s,
                  thinking: thinking!,
                  widgetsEnabled: widgetsEnabled,
                ),
              if (text.isNotEmpty)
                RichAiText(
                  text: text
                      .replaceAll(kVisualResultRe, '')
                      .replaceAll(kDocumentResultRe, '')
                      .replaceAll(kSourcesRe, '')
                      .replaceAll(kImagesRe, '')
                      .trim(),
                  s: s,
                  widgetsEnabled: widgetsEnabled,
                  onEnableWidgets: onEnableWidgets,
                  onSuggestionTap: onSuggestionTap,
                ),
              for (final item in canvases) ...[
                const SizedBox(height: 8),
                SimpleCanvasCard(s: s, item: item, onTap: () => onOpenCanvas(item)),
              ],
              const SizedBox(height: 6),
              _AssistantActionBar(
                s: s,
                onThumbUp: onThumbUp,
                onThumbDown: onThumbDown,
                onCopy: onCopy,
                onRefresh: onRefresh,
                sources: extractSources(text),
              ),
            ],
          ),
        ),
      );
}

class _ThinkingHistoryCollapsible extends StatelessWidget {
  final AppColorScheme s;
  final String thinking;
  final bool widgetsEnabled;

  const _ThinkingHistoryCollapsible({
    required this.s,
    required this.thinking,
    required this.widgetsEnabled,
  });

  void _openThinkingModal(BuildContext context) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon('brain', size: 22, color: s.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Pensamento',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: SingleChildScrollView(
                child: RichAiText(
                  text: thinking,
                  s: s,
                  widgetsEnabled: widgetsEnabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openThinkingModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AppIcon('brain', size: 16, color: s.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pensamento',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
              ),
            ),
            AppIcon('arrow_right', size: 14, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _AssistantActionBar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final List<String> sources;
  const _AssistantActionBar({
    required this.s,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
    this.sources = const [],
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _AssistantActionIcon(s: s, assetName: 'thumbs_up', onTap: onThumbUp),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'thumbs_down', onTap: onThumbDown),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'copy', onTap: onCopy),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'refresh', onTap: onRefresh),
          if (sources.isNotEmpty) ...[
            const Spacer(),
            SourcesRow(s: s, urls: sources),
          ],
        ],
      );
}

class _AssistantActionIcon extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  const _AssistantActionIcon({
    required this.s,
    required this.assetName,
    required this.onTap,
  });
  @override
  State<_AssistantActionIcon> createState() => _AssistantActionIconState();
}

class _AssistantActionIconState extends State<_AssistantActionIcon> {
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
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _h ? s.hover : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: AppIcon(
          widget.assetName,
          color: s.onSurfaceVariant,
          size: 16,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOLHA DE STREAMING (em construção)
// ══════════════════════════════════════════════════════════════

class StreamingBubble extends StatefulWidget {
  final AppColorScheme s;
  final List<StreamElement> elements;
  final String? thinking;
  final bool showLogoLoader;
  final String? activeToolCallLabel;
  final String? activeToolCallName;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  final ValueNotifier<String> openCanvasContentNotifier;
  final ValueNotifier<bool> openCanvasDoneNotifier;
  final LocalCanvasItem? Function() openCanvasFinalItem;
  final ValueNotifier<String> openWidgetContentNotifier;
  final ValueNotifier<bool> openWidgetDoneNotifier;
  const StreamingBubble({
    super.key,
    required this.s,
    required this.elements,
    this.thinking,
    this.showLogoLoader = false,
    this.activeToolCallLabel,
    this.activeToolCallName,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
    required this.onOpenCanvas,
    required this.openCanvasContentNotifier,
    required this.openCanvasDoneNotifier,
    required this.openCanvasFinalItem,
    required this.openWidgetContentNotifier,
    required this.openWidgetDoneNotifier,
  });

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final thinking = widget.thinking;
    final children = <Widget>[];

    if (thinking != null && thinking.isNotEmpty) {
      children.add(_ThinkingCollapsible(
        s: s,
        thinking: thinking,
        widgetsEnabled: widget.widgetsEnabled,
      ));
    }

    bool anyContent = false;
    for (final el in widget.elements) {
      switch (el) {
        case StreamText(:final text):
          final cleaned = cleanAiText(text);
          if (cleaned.trim().isEmpty) continue;
          anyContent = true;
          children.add(
            RichAiText(
              text: cleaned,
              s: s,
              widgetsEnabled: widget.widgetsEnabled,
              onEnableWidgets: widget.onEnableWidgets,
              onSuggestionTap: widget.onSuggestionTap,
            ),
          );
        case StreamCanvasBlock(:final label, :final item):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CanvasProgressCard(
              s: s,
              title: label,
              item: item,
              contentNotifier: widget.openCanvasContentNotifier,
              doneNotifier: widget.openCanvasDoneNotifier,
              finalItem: widget.openCanvasFinalItem,
              onOpenCanvas: widget.onOpenCanvas,
            ),
          ));
        case StreamWidgetBlock(:final label, :final block):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: WidgetProgressCard(
              s: s,
              label: label,
              block: block,
              contentNotifier: widget.openWidgetContentNotifier,
              doneNotifier: widget.openWidgetDoneNotifier,
            ),
          ));
        case StreamGenericOpenBlock(:final label):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: StreamingMarkdownCard(s: s, label: label),
          ));
      }
    }

    if (widget.activeToolCallLabel != null) {
      anyContent = true;
      children.add(ToolCallProgressCard(
        s: s,
        label: widget.activeToolCallLabel!,
        toolName: widget.activeToolCallName ?? '',
      ));
    }

    if (!anyContent && thinking == null) {
      children.add(widget.showLogoLoader
          ? const NexaLoaderLogo(size: 28)
          : AiSmallDotsLoader(color: s.onSurfaceVariant));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _ThinkingCollapsible extends StatelessWidget {
  final AppColorScheme s;
  final String thinking;
  final bool widgetsEnabled;

  const _ThinkingCollapsible({
    required this.s,
    required this.thinking,
    required this.widgetsEnabled,
  });

  void _openThinkingModal(BuildContext context) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon('brain', size: 22, color: s.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Pensamento',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: SingleChildScrollView(
                child: RichAiText(
                  text: thinking,
                  s: s,
                  widgetsEnabled: widgetsEnabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openThinkingModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ShimmerBrainIcon(size: 16, color: s.onSurfaceVariant, active: true),
            const SizedBox(width: 8),
            Expanded(
              child: ShimmerText(
                text: 'Pensando...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
                active: true,
              ),
            ),
            AppIcon('arrow_right', size: 14, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ESTADOS ESPECIAIS DA LISTA
// ══════════════════════════════════════════════════════════════

class IncognitoState extends StatelessWidget {
  const IncognitoState({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Center(
      child: AppIcon(
        'incognito',
        color: s.onSurface,
        size: 72,
      ),
    );
  }
}

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'O DeepSeek é uma IA e pode cometer erros.',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 10.5,
            color: s.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class ScrollToBottomButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const ScrollToBottomButton({super.key, required this.s, required this.onTap});
  @override
  State<ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<ScrollToBottomButton> {
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
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 38, height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: s.floatingShadow,
          ),
          child: AppIcon('double_arrow_down', color: s.onSurface, size: 18),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final AppColorScheme s;
  final double topPadding;
  const EmptyState({super.key, required this.s, required this.topPadding});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NexaLoaderLogo(
                  size: 112,
                  tintColor: s.isDark ? null : s.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Olá, o que vamos criar hoje?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: s.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}