import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class OcrTool {
  /// ocr_extract_text
  /// input: { image_base64: String, language?: String — ignorado no ML Kit padrão latino,
  ///           reservado para scripts alternativos se necessário no futuro }
  static Future<ToolResult> extractText(Map<String, dynamic> input) {
    // OCR é uma das operações mais pesadas de RAM/CPU — sempre
    // enfileirada, nunca concorrente com outra tool pesada.
    return ToolsQueue.instance.enqueue(() => _extractImpl(input));
  }

  static Future<ToolResult> _extractImpl(Map<String, dynamic> input) async {
    final String? imageBase64 = input['image_base64'] as String?;
    if (imageBase64 == null || imageBase64.isEmpty) {
      return ToolResult.error('Parâmetro "image_base64" é obrigatório.',
          code: 'INVALID_INPUT');
    }

    File? tempFile;
    TextRecognizer? recognizer;
    try {
      final bytes = base64Decode(imageBase64);
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
          '${tempDir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);

      final inputImage = InputImage.fromFile(tempFile);
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognized =
          await recognizer.processImage(inputImage);

      // Além do texto corrido, devolve os blocos individuais — útil
      // para a IA saber a posição aproximada de cada trecho quando o
      // pedido for algo como "o que está escrito no canto superior".
      final blocks = recognized.blocks.map((block) {
        return {
          'text': block.text,
          'bounding_box': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          },
        };
      }).toList();

      return ToolResult.ok({
        'text': recognized.text,
        'blocks': blocks,
      });
    } catch (e) {
      return ToolResult.error('Erro ao processar OCR: $e', code: 'OCR_ERROR');
    } finally {
      await recognizer?.close();
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}