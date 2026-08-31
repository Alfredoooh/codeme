// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_progress_cards.dart
// Cards de progresso mostrados durante o streaming (canvas, widget,
// tool call genérico) e os modais que os expandem.
//
// CORREÇÃO: _ToolCallProgressCard agora usa ToolIcon (SVG por-tool
// com fallback) em vez do ícone fixo 'tools', e o texto está
// explicitamente alinhado à esquerda dentro do Expanded.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../colors.dart';
import '../widgets.dart';
import '../widgets/animated_canvas_icon.dart';
import '../apps/app_types.dart';
import '../apps/docs.dart';
import '../apps/sheets_app.dart';
import '../apps/slides_app.dart';
import '../app_sheet.dart';
import 'aitab_models.dart';
import 'aitab_widgets_shared.dart';
import 'aitab_tools.dart';

class StreamingMarkdownCard extends StatelessWidget {
  final AppColorScheme s;
  final String label;

  const StreamingMarkdownCard({
    super.key,
    required this.s,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: s.pageBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NexaLoaderLogo(size: 28, tintColor: s.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShimmerText(
                  text: label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: s.onSurfaceVariant,
                  ),
                  active: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CanvasProgressCard extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final LocalCanvasItem? item;
  final ValueNotifier<String> contentNotifier;
  final ValueNotifier<bool> doneNotifier;
  final LocalCanvasItem? Function() finalItem;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;

  const CanvasProgressCard({
    super.key,
    required this.s,
    required this.title,
    required this.item,
    required this.contentNotifier,
    required this.doneNotifier,
    required this.finalItem,
    required this.onOpenCanvas,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: doneNotifier,
      builder: (_, done, __) {
        if (done && item != null) {
          return GestureDetector(
            onTap: () => showCanvasPreviewModal(
              context,
              s,
              title: item!.title,
              content: item!.content,
              onOpen: () => onOpenCanvas(item!),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: s.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.cardShadow,
              ),
              child: Row(
                children: [
                  AnimatedCanvasIcon(
                    editorType: item!.kind.editorType,
                    s: s,
                    size: 44,
                    animated: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item!.title,
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
                          item!.kind.shortLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: s.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => showCanvasStreamingModal(
            context, s,
            title: title,
            contentNotifier: contentNotifier,
            doneNotifier: doneNotifier,
            finalItem: finalItem,
            onOpenCanvas: onOpenCanvas,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: s.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: s.cardShadow,
            ),
            child: Row(
              children: [
                AnimatedCanvasIcon(
                  editorType: editorTypeFromProgressTitle(title),
                  s: s,
                  size: 44,
                  animated: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerText(
                        text: title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface),
                        active: true,
                      ),
                      const SizedBox(height: 2),
                      ShimmerText(
                        text: 'A gerar...',
                        style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                        active: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WidgetProgressCard extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final AiWidgetBlock? block;
  final ValueNotifier<String> contentNotifier;
  final ValueNotifier<bool> doneNotifier;

  const WidgetProgressCard({
    super.key,
    required this.s,
    required this.label,
    required this.block,
    required this.contentNotifier,
    required this.doneNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: doneNotifier,
      builder: (_, done, __) {
        if (done && block != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: buildAiWidget(block!, s),
          );
        }
        return GestureDetector(
          onTap: () => showWidgetStreamingModal(
            context, s,
            title: label,
            contentNotifier: contentNotifier,
            doneNotifier: doneNotifier,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: s.pageBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NexaLoaderLogo(size: 32, tintColor: s.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ShimmerText(
                      text: label,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface),
                      active: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Card mostrado enquanto uma tool call está a ser executada
/// (antes do texto de resposta começar a chegar). Ícone específico
/// por tool (com fallback), texto sempre alinhado à esquerda.
class ToolCallProgressCard extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final String toolName;

  const ToolCallProgressCard({
    super.key,
    required this.s,
    required this.label,
    required this.toolName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.pageBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                s.primary.withOpacity(0.3),
                s.primary,
                s.primary.withOpacity(0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: ToolIcon(toolName: toolName, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShimmerText(
                text: label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface),
                active: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODAIS DE STREAMING / PREVIEW
// ══════════════════════════════════════════════════════════════

Future<void> showCanvasStreamingModal(
  BuildContext context,
  AppColorScheme s, {
  required String title,
  required ValueNotifier<String> contentNotifier,
  required ValueNotifier<bool> doneNotifier,
  required LocalCanvasItem? Function() finalItem,
  required ValueChanged<LocalCanvasItem> onOpenCanvas,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: _CanvasStreamingModalContent(
      s: s,
      title: title,
      contentNotifier: contentNotifier,
      doneNotifier: doneNotifier,
      finalItem: finalItem,
      onOpenCanvas: onOpenCanvas,
    ),
  );
}

class _CanvasStreamingModalContent extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final ValueNotifier<String> contentNotifier;
  final ValueNotifier<bool> doneNotifier;
  final LocalCanvasItem? Function() finalItem;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;

  const _CanvasStreamingModalContent({
    required this.s,
    required this.title,
    required this.contentNotifier,
    required this.doneNotifier,
    required this.finalItem,
    required this.onOpenCanvas,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: doneNotifier,
            builder: (_, done, __) => Row(
              children: [
                AnimatedCanvasIcon(
                  editorType: finalItem()?.kind.editorType ?? EditorType.docs,
                  s: s,
                  size: 32,
                  animated: !done,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: ValueListenableBuilder<String>(
                valueListenable: contentNotifier,
                builder: (_, content, __) => SelectableText(
                  content,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: s.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: doneNotifier,
            builder: (_, done, __) => GestureDetector(
              onTap: done
                  ? () {
                      final item = finalItem();
                      if (item != null) {
                        Navigator.pop(context);
                        onOpenCanvas(item);
                      }
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? s.primary : s.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  done ? 'Abrir' : 'A gerar...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: done ? s.onPrimary : s.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCanvasPreviewModal(
  BuildContext context,
  AppColorScheme s, {
  required String title,
  required String content,
  required VoidCallback onOpen,
}) {
  return showCraftBottomSheet<void>(
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
              Icon(
                Icons.description,
                size: 28,
                color: s.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: s.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onOpen();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Abrir',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showWidgetStreamingModal(
  BuildContext context,
  AppColorScheme s, {
  required String title,
  required ValueNotifier<String> contentNotifier,
  required ValueNotifier<bool> doneNotifier,
}) {
  return showCraftBottomSheet<void>(
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
              NexaLoaderLogo(size: 28, tintColor: s.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              child: ValueListenableBuilder<String>(
                valueListenable: contentNotifier,
                builder: (_, content, __) => SelectableText(
                  content,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: s.onSurfaceVariant, height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}