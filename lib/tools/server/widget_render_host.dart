=====================================================================
lib/tools/server/widget_render_host.dart  (NOVO)
=====================================================================

// Host de renderização off-screen — permite montar QUALQUER widget
// Flutter arbitrário (não só o que já está visível na tela do
// utilizador) e capturá-lo como PNG via um pipeline de renderização
// isolado (RenderView + PipelineOwner próprios), sem depender de
// nenhum Overlay ou BuildContext de uma tela específica estar
// montado no momento da chamada.
//
// Usado por chart_tool.dart (fl_chart) e por qualquer tool futura
// que precise desenhar um widget Flutter nativo (Material/Cupertino)
// em vez de Canvas puro ou WebView.
//
// Baseado na técnica padrão de "widget to image" fora da árvore de
// widgets do app (a mesma usada internamente por pacotes como
// `screenshot`), sem trazer dependência externa — só APIs do
// próprio framework Flutter (dart:ui + flutter/rendering.dart).

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class WidgetRenderHost {
  WidgetRenderHost._();
  static final WidgetRenderHost instance = WidgetRenderHost._();

  /// Renderiza [widget] fora da árvore visível, num pipeline isolado
  /// do tamanho [size], e devolve os bytes PNG resultantes.
  ///
  /// [pixelRatio] controla a resolução da captura (2.0 = retina).
  Future<Uint8List> renderToPng({
    required Widget widget,
    required Size size,
    double pixelRatio = 2.0,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();

    // Pipeline de renderização próprio, totalmente isolado do
    // pipeline principal do app — nada aqui interfere com a tela
    // real que o utilizador está a ver, e vice-versa.
    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: pixelRatio,
      ),
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());

    // RenderObjectToWidgetAdapter é o que permite "encaixar" uma
    // árvore de Widget normal (Material, fl_chart, etc) dentro de um
    // RenderObject que montamos manualmente — é a ponte entre o
    // mundo declarativo (Widget) e o pipeline isolado que criámos.
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: pixelRatio),
          child: widget,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    // Um único ciclo de build+layout+paint é suficiente para widgets
    // estáticos (gráficos, tabelas) — não há animação nem interação
    // a aguardar, então não precisamos de um loop de frames.
    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    // Aguarda o próximo frame do scheduler antes de capturar —
    // garante que o Skia já processou os comandos de paint
    // agendados no passo anterior antes de pedirmos a imagem.
    await SchedulerBinding.instance.endOfFrame;

    final ui.Image image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Falha ao converter o widget renderizado em PNG.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}