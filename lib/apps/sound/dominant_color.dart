import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class DominantColorExtractor {
  static const String _html = '''
<!DOCTYPE html>
<html>
<head><style>body{margin:0;padding:0;}</style></head>
<body>
<canvas id="c" style="display:none;"></canvas>
<script>
function extract(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "Anonymous";
    img.onload = function () {
      try {
        const canvas = document.getElementById("c");
        const size = 48; // reduzido — só precisamos de uma amostra
        canvas.width = size;
        canvas.height = size;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, size, size);
        const data = ctx.getImageData(0, 0, size, size).data;

        let r = 0, g = 0, b = 0, count = 0;
        for (let i = 0; i < data.length; i += 4) {
          const alpha = data[i + 3];
          if (alpha < 125) continue;
          const rr = data[i], gg = data[i + 1], bb = data[i + 2];
          // ignora quase-branco e quase-preto puro (pouco informativos)
          const brightness = (rr + gg + bb) / 3;
          if (brightness > 245 || brightness < 12) continue;
          r += rr; g += gg; b += bb; count++;
        }
        if (count === 0) { r = 128; g = 128; b = 128; count = 1; }
        r = Math.round(r / count);
        g = Math.round(g / count);
        b = Math.round(b / count);
        resolve(r.toString(16).padStart(2,"0") + g.toString(16).padStart(2,"0") + b.toString(16).padStart(2,"0"));
      } catch (e) {
        reject(String(e));
      }
    };
    img.onerror = function () { reject("image_load_error"); };
    img.src = url;
  });
}
</script>
</body>
</html>
''';

  static InAppWebViewController? _controller;
  static Completer<void>? _readyCompleter;
  static OverlayEntry? _overlayEntry;

  /// Garante que existe uma WebView headless montada e pronta.
  /// Usa um OverlayEntry 1x1 fora do ecrã visível — não aparece
  /// ao utilizador mas continua "montada" para o WebView correr.
  static Future<void> _ensureReady(BuildContext context) async {
    if (_controller != null) return;
    if (_readyCompleter != null) {
      return _readyCompleter!.future;
    }
    _readyCompleter = Completer<void>();

    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10,
        top: -10,
        width: 1,
        height: 1,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.0,
            child: InAppWebView(
              initialData: InAppWebViewInitialData(data: _html),
              onWebViewCreated: (c) {
                _controller = c;
              },
              onLoadStop: (c, url) {
                if (!_readyCompleter!.isCompleted) {
                  _readyCompleter!.complete();
                }
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
    return _readyCompleter!.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {},
    );
  }

  /// Extrai a cor dominante de [imageUrl]. Devolve `fallback` se algo
  /// falhar (rede, WebView indisponível, imagem inválida, etc.) —
  /// nunca lança exceção para quem chama.
  static Future<Color> extract(
    BuildContext context,
    String imageUrl, {
    Color fallback = const Color(0xFF1C1C1E),
  }) async {
    try {
      await _ensureReady(context);
      if (_controller == null) return fallback;

      final result = await _controller!.callAsyncJavaScript(
        functionBody: 'return await extract(url);',
        arguments: {'url': imageUrl},
      ).timeout(const Duration(seconds: 8));

      final hex = result?.value as String?;
      if (hex == null || hex.length != 6) return fallback;
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      debugPrint('DominantColorExtractor falhou: $e');
      return fallback;
    }
  }
}