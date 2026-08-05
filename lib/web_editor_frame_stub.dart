// lib/web_editor_frame_stub.dart
// Usado em mobile — não importa dart:html, não quebra compilação Android/iOS.
import 'package:flutter/widgets.dart';

void registerWebEditorFrame(String assetPath) {
  // Não faz nada em mobile.
}

class WebEditorFrame extends StatelessWidget {
  final String assetPath;
  const WebEditorFrame({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}