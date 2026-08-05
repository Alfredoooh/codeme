// lib/web_editor_frame.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';

void registerWebEditorFrame(String assetPath) {
  ui.platformViewRegistry.registerViewFactory(
    'editor-iframe-$assetPath',
    (int viewId) {
      final iframe = html.IFrameElement()
        ..src = assetPath
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';
      return iframe;
    },
  );
}

class WebEditorFrame extends StatelessWidget {
  final String assetPath;
  const WebEditorFrame({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: 'editor-iframe-$assetPath');
  }
}