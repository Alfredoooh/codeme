// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_message_bubbles.dart
//
// MUDANÇAS NESTA VERSÃO:
// 1) Todo o Cupertino foi removido (import cupertino.dart eliminado;
//    o único uso — CupertinoActivityIndicator — não estava a ser
//    usado neste ficheiro de qualquer forma).
// 2) A fonte da resposta do assistente passa a ser Times New Roman
//    via fonte LOCAL registada no pubspec.yaml (família
//    'TimesNewRoman', assets em assets/fonts/Times New Roman/),
//    aplicada APENAS ao corpo de texto do RichAiText do assistente
//    — nunca às bolhas do utilizador, nunca a blocos de código,
//    nunca a labels/botões/ícones. Isto é feito passando um
//    `bodyTextStyle` (parâmetro já suportado por RichAiText em
//    richtext.dart) nas quatro chamadas de RichAiText deste
//    ficheiro (Assistant, Thinking histórico, Streaming, Thinking
//    em streaming).
//    NOTA: GoogleFonts.timesNewRoman() NÃO existe — Times New Roman
//    é fonte da Microsoft, não faz parte do catálogo do Google
//    Fonts. Por isso aiBodyTextStyle usa TextStyle(fontFamily:
//    'TimesNewRoman', ...) apontando para a fonte local, e não
//    GoogleFonts.*. O import de google_fonts mantém-se neste
//    ficheiro apenas porque outras partes do projeto (fora deste
//    ficheiro) continuam a usar GoogleFonts.xxx() — se este
//    ficheiro específico não usar mais nenhuma chamada GoogleFonts,
//    o import está tecnicamente por usar aqui, mas isso não quebra
//    a compilação.
// 3) Sheets substituídos por showModalBottomSheet Android nativo com
//    curva reduzida (mesma _kFlatModalRadius do drawer), onde antes
//    usavam showCraftBottomSheet local a este ficheiro para
//    pensamento/fontes (o showCraftBottomSheet em si é definido em
//    app_sheet.dart, que não me foi enviado — se ele já usar
//    showModalBottomSheet Android por baixo, nada muda; caso
//    contrário, precisa de ser ajustado lá).
// 4) ToolResultImageCard deixa de mostrar a imagem completa inline
//    (exceto imagens de pesquisa via ImageSearchCarousel). Agora é
//    um card "Visualizar gráfico" com miniatura, que abre um
//    visualizador fullscreen escuro com zoom livre.
// ══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/richtext.dart';
import '../../core/widgets/app_sheet.dart';
// TODO: depende de aiwidgets.dart (split futuro); manter este import para a etapa futura de split.
import '../ai_widgets/ai_widgets.dart';
import '../apps/app_types.dart';
import '../apps/sheets/sheets.dart';
import 'aitab_models.dart';
import 'aitab_widgets_shared.dart';
import 'aitab_progress_cards.dart';
import '../../core/navigation/app_page_route.dart';

// Estilo de corpo de texto usado SOMENTE na resposta da IA (fora de
// blocos de código). Times New Roman via fonte LOCAL registada no
// pubspec.yaml (família 'TimesNewRoman'). Nunca é aplicado às
// bolhas do utilizador, nem a ícones/labels/botões, nem a blocos de
// código (o RichAiText mantém a fonte monoespaçada nos blocos —
// este estilo só cobre o texto corrido/prosa).
TextStyle aiBodyTextStyle(AppColorScheme s) => TextStyle(
      fontFamily: 'TimesNewRoman',
      fontSize: 15,
      height: 1.45,
      color: s.onSurface,
    );

const double _kFlatModalRadius = 10.0;

// ──────────────────────────────────────────────────────────────
// BOLHA DO UTILIZADOR
// ──────────────────────────────────────────────────────────────

class UserBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final List<Map<String, dynamic>>? attachments;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onSelectText;
  const UserBubble({
    super.key,
    required this.s,
    required this.text,
    this.attachments,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachments != null && attachments!.isNotEmpty) ...[
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: attachments!
                      .map((a) => _UserAttachmentChip(s: s, attachment: a))
                      .toList(),
                ),
                if (text.isNotEmpty) const SizedBox(height: 8),
              ],
              // Bolha do utilizador: fonte normal da app, nunca Times
              // New Roman — isso é exclusivo da resposta da IA.
              if (text.isNotEmpty)
                Text(text,
                    style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAttachmentChip extends StatelessWidget {
  final AppColorScheme s;
  final Map<String, dynamic> attachment;
  const _UserAttachmentChip({required this.s, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final name = attachment['name']?.toString() ?? 'anexo';
    final mimeType = attachment['mimeType']?.toString() ?? '';
    final isImage = mimeType.startsWith('image/');
    final isPdf = mimeType == 'application/pdf';
    final isZip = mimeType == 'application/zip';
    final iconName = isImage
        ? 'image'
        : (isPdf
            ? 'pdf'
            : (isZip ? 'folder_upload' : 'paperclip'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(iconName, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CARDS DE RESULTADO DE TOOL
// ──────────────────────────────────────────────────────────────

class ToolResultImageCard extends StatefulWidget {
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
  State<ToolResultImageCard> createState() => _ToolResultImageCardState();
}

class _ToolResultImageCardState extends State<ToolResultImageCard> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant ToolResultImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Png != widget.base64Png) {
      _decode();
    }
  }

  void _decode() {
    try {
      _cachedBytes = base64Decode(widget.base64Png);
    } catch (_) {
      _cachedBytes = null;
    }
  }

  void _openFullscreen(BuildContext context) {
    final bytes = _cachedBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => _FullscreenImageScreen(
          bytes: bytes,
          label: widget.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bytes = _cachedBytes;
    // Card "Visualizar gráfico" — NÃO mostra a imagem completa
    // inline na conversa. Só imagens de pesquisa web (search_images,
    // via ImageSearchCarousel) aparecem diretamente. Gráficos,
    // mapas mentais, QR codes, tabelas visuais, clima, etc. ficam
    // atrás deste card e só se veem ao abrir o visualizador
    // fullscreen.
    return GestureDetector(
      onTap: () => _openFullscreen(context),
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
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.memory(bytes, fit: BoxFit.cover),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: s.hover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.image_not_supported_outlined, size: 18, color: s.onSurfaceVariant),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toque para visualizar',
                    style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AppIcon('expand', size: 18, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImageScreen extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  const _FullscreenImageScreen({required this.bytes, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              clipBehavior: Clip.none,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    _CircularBackButtonDark(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularBackButtonDark extends StatefulWidget {
  final VoidCallback onTap;
  const _CircularBackButtonDark({required this.onTap});
  @override
  State<_CircularBackButtonDark> createState() => _CircularBackButtonDarkState();
}

class _CircularBackButtonDarkState extends State<_CircularBackButtonDark> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? Colors.white24 : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
      ),
    );
  }
}

class _CircularBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _CircularBackButton({required this.s, required this.onTap});
  @override
  State<_CircularBackButton> createState() => _CircularBackButtonState();
}

class _CircularBackButtonState extends State<_CircularBackButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: AppIcon('back', color: s.onSurface, size: 18),
      ),
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
    if (lower.endsWith('.zip')) return 'folder_upload';
    return 'doc';
  }

  String get _label {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'Documento PDF';
    if (lower.endsWith('.docx')) return 'Documento Word';
    if (lower.endsWith('.xlsx')) return 'Folha de cálculo';
    if (lower.endsWith('.pptx')) return 'Apresentação';
    if (lower.endsWith('.zip')) return 'Projeto ZIP';
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

// ──────────────────────────────────────────────────────────────
// CARROSSEL DE IMAGENS DE PESQUISA
// ──────────────────────────────────────────────────────────────

class ImageSearchCarousel extends StatefulWidget {
  final AppColorScheme s;
  final List<Map<String, dynamic>> images;
  const ImageSearchCarousel({super.key, required this.s, required this.images});

  @override
  State<ImageSearchCarousel> createState() => _ImageSearchCarouselState();
}

class _ImageSearchCarouselState extends State<ImageSearchCarousel> {
  final Set<String> _failedUrls = {};

  void _markFailed(String url) {
    if (_failedUrls.contains(url)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failedUrls.add(url));
    });
  }

  void _openFullscreen(BuildContext context, int initialIndex) {
    final visibleImages = widget.images.where((img) {
      final url = img['imageUrl']?.toString() ?? '';
      return url.isNotEmpty && !_failedUrls.contains(url);
    }).toList();

    if (visibleImages.isEmpty) return;

    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => _ImageSearchFullscreenScreen(
          images: visibleImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final visibleImages = widget.images.where((img) {
      final url = img['imageUrl']?.toString() ?? '';
      return url.isNotEmpty && !_failedUrls.contains(url);
    }).toList();

    if (visibleImages.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 160,
        child: ScrollConfiguration(
          behavior: const _ElasticScrollBehavior(),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: visibleImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final img = visibleImages[i];
              final url = img['imageUrl']?.toString() ?? '';
              return GestureDetector(
                key: ValueKey(url),
                onTap: () => _openFullscreen(context, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    url,
                    key: ValueKey(url),
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                    errorBuilder: (_, __, ___) {
                      _markFailed(url);
                      return const SizedBox(width: 160, height: 160);
                    },
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
    final topInset = MediaQuery.of(context).padding.top;
    final currentTitle = widget.images[_current]['title']?.toString() ?? '${_current + 1}/${widget.images.length}';

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
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
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image_not_supported_outlined,
                            color: s.onSurfaceVariant,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
                      _CircularBackButton(
                        s: s,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: s.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// FONTES (web_search)
// ──────────────────────────────────────────────────────────────

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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: s.cardBackground,
      barrierColor: Colors.black.withOpacity(0.35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kFlatModalRadius)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fontes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
              const SizedBox(height: 8),
              SheetOptionsGroup(
                s: s,
                options: urls.map((url) {
                  return _SourceRow(s: s, url: url, domain: _domain(url), faviconUrl: _faviconUrl(url));
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
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
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => Icon(Icons.public, size: 11, color: s.onSurfaceVariant),
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
                  gaplessPlayback: true,
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

// ──────────────────────────────────────────────────────────────
// BOLHA DO ASSISTENTE
// ──────────────────────────────────────────────────────────────

class AssistantBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final String? thinking;
  final List<LocalCanvasItem> canvases;
  final List<ProcessStep> processSteps;
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
    this.processSteps = const [],
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
              // Sempre fechado por defeito ao reabrir histórico:
              if (processSteps.isNotEmpty)
                ProcessCollapsible(s: s, steps: processSteps, isActive: false, startExpanded: false),
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
                  bodyTextStyle: aiBodyTextStyle(s),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: s.cardBackground,
      barrierColor: Colors.black.withOpacity(0.35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kFlatModalRadius)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: SingleChildScrollView(
                  child: RichAiText(
                    text: thinking,
                    s: s,
                    widgetsEnabled: widgetsEnabled,
                    bodyTextStyle: aiBodyTextStyle(s),
                  ),
                ),
              ),
            ],
          ),
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

// ──────────────────────────────────────────────────────────────
// BOLHA DE STREAMING
// ──────────────────────────────────────────────────────────────

class StreamingBubble extends StatefulWidget {
  final AppColorScheme s;
  final List<StreamElement> elements;
  final String? thinking;
  final bool showLogoLoader;
  final String? activeToolCallLabel;
  final String? activeToolCallName;
  final List<ProcessStep> processSteps;
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
    this.processSteps = const [],
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

    // Processo de trabalho — sempre primeiro, ativo (shimmer) durante
    // o streaming, nunca perde passos já adicionados.
    if (widget.processSteps.isNotEmpty) {
      children.add(ProcessCollapsible(
        s: s,
        steps: widget.processSteps,
        isActive: true,
        startExpanded: true,
      ));
    }

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
              bodyTextStyle: aiBodyTextStyle(s),
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
        case StreamVisualResult(:final base64Png, :final label):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('visual_${base64Png.hashCode}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ToolResultImageCard(
                key: ValueKey('tool_image_${base64Png.hashCode}'),
                s: s,
                base64Png: base64Png,
                label: label,
              ),
            ),
          );
        case StreamDocumentResult(:final base64Data, :final filename, :final mimeType):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('doc_${base64Data.hashCode}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ToolResultDownloadCard(
                key: ValueKey('download_${base64Data.hashCode}'),
                s: s,
                base64Data: base64Data,
                filename: filename,
                mimeType: mimeType,
              ),
            ),
          );
        case StreamImagesResult(:final images):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('images_${images.map((e) => e['imageUrl']?.toString() ?? '').join('|')}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ImageSearchCarousel(s: s, images: images),
            ),
          );
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

    if (!anyContent && thinking == null && widget.processSteps.isEmpty) {
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: s.cardBackground,
      barrierColor: Colors.black.withOpacity(0.35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kFlatModalRadius)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: SingleChildScrollView(
                  child: RichAiText(
                    text: thinking,
                    s: s,
                    widgetsEnabled: widgetsEnabled,
                    bodyTextStyle: aiBodyTextStyle(s),
                  ),
                ),
              ),
            ],
          ),
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

// ──────────────────────────────────────────────────────────────
// ESTADOS ESPECIAIS DA LISTA
// ──────────────────────────────────────────────────────────────

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
          child: AppIcon('double_chevron_down', color: s.onSurface, size: 18),
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