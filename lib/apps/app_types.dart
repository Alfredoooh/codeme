// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/app_types.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

enum EditorType { docs, sheets, slides }

extension EditorTypeX on EditorType {
  String get label => const {
        EditorType.docs:   'Documento',
        EditorType.sheets: 'Folha de cálculo',
        EditorType.slides: 'Apresentação',
      }[this]!;

  String get htmlAsset => const {
        EditorType.docs:   'assets/editor/docs.html',
        EditorType.sheets: 'assets/editor/sheets.html',
        EditorType.slides: 'assets/editor/slides.html',
      }[this]!;

  String get aiDocType => const {
        EditorType.docs:   'doc',
        EditorType.sheets: 'sheet',
        EditorType.slides: 'slide',
      }[this]!;

  AppKind get appKind => const {
        EditorType.docs:   AppKind.docs,
        EditorType.sheets: AppKind.sheets,
        EditorType.slides: AppKind.slides,
      }[this]!;

  static EditorType fromCanvasKind(LocalCanvasKind k) {
    switch (k) {
      case LocalCanvasKind.sheet: return EditorType.sheets;
      case LocalCanvasKind.slide: return EditorType.slides;
      case LocalCanvasKind.doc:   return EditorType.docs;
    }
  }
}

enum LocalCanvasKind { doc, sheet, slide }

extension LocalCanvasKindX on LocalCanvasKind {
  EditorType get editorType {
    switch (this) {
      case LocalCanvasKind.sheet: return EditorType.sheets;
      case LocalCanvasKind.slide: return EditorType.slides;
      case LocalCanvasKind.doc:   return EditorType.docs;
    }
  }

  String get shortLabel => const {
        LocalCanvasKind.doc:   'Documento',
        LocalCanvasKind.sheet: 'Folha de cálculo',
        LocalCanvasKind.slide: 'Apresentação',
      }[this]!;
}

class LocalCanvasItem {
  final String id;
  final LocalCanvasKind kind;
  final String title;
  final String content;
  const LocalCanvasItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
  });
}

enum AppKind { docs, sheets, slides, sound }

extension AppKindX on AppKind {
  static const List<AppKind> all = AppKind.values;

  String get label => const {
        AppKind.docs:   'Documento',
        AppKind.sheets: 'Folha de cálculo',
        AppKind.slides: 'Apresentação',
        AppKind.sound:  'Sound',
      }[this]!;

  /// Pequena descrição mostrada por baixo do nome no drawer,
  /// no mesmo estilo da referência (ex.: "Read and manage Slack").
  String get description => const {
        AppKind.docs:   'Criar e editar documentos de texto',
        AppKind.sheets: 'Criar e editar folhas de cálculo',
        AppKind.slides: 'Criar e editar apresentações',
        AppKind.sound:  'Pesquisar e reproduzir música',
      }[this]!;

  /// Texto mais longo, mostrado no ecrã de detalhes ("Para que serve").
  String get longDescription => const {
        AppKind.docs:
            'O Documento é o teu espaço para escrever e organizar texto — desde notas rápidas a documentos mais longos — tudo dentro da app, com a ajuda da IA sempre que precisares.',
        AppKind.sheets:
            'A Folha de cálculo permite-te organizar dados, fazer contas e criar tabelas, com o apoio da IA para te ajudar a montar tudo mais rápido.',
        AppKind.slides:
            'A Apresentação ajuda-te a construir slides de forma simples, com a IA a apoiar na criação do conteúdo e da estrutura.',
        AppKind.sound:
            'O Sound é o teu espaço para pesquisar e ouvir música diretamente na app, com a ajuda da IA para encontrares o que procuras.',
      }[this]!;

  /// Lista de funcionalidades mostrada no ecrã de detalhes.
  List<String> get features => const {
        AppKind.docs: [
          'Editor de texto completo, otimizado para telemóvel',
          'Assistente de IA para ajudar a criar e editar o conteúdo',
          'Suporta modo claro e escuro',
        ],
        AppKind.sheets: [
          'Editor de folhas de cálculo completo, otimizado para telemóvel',
          'Assistente de IA para ajudar a criar folhas de cálculo',
          'Suporta modo claro e escuro',
        ],
        AppKind.slides: [
          'Editor de apresentações completo, otimizado para telemóvel',
          'Assistente de IA para ajudar a criar apresentações',
          'Suporta modo claro e escuro',
        ],
        AppKind.sound: [
          'Pesquisa de música integrada',
          'Reprodução direta na app',
          'Assistente de IA para ajudar a encontrar música',
        ],
      }[this]!;

  String get iconAsset => const {
        AppKind.docs:   'assets/icons/apps/docs.png',
        AppKind.sheets: 'assets/icons/apps/sheets.png',
        AppKind.slides: 'assets/icons/apps/slides.png',
        AppKind.sound:  'assets/icons/apps/sound.png',
      }[this]!;

  String get aiName => const {
        AppKind.docs:   'Documentos',
        AppKind.sheets: 'Folhas de cálculo',
        AppKind.slides: 'Apresentações',
        AppKind.sound:  'Sound',
      }[this]!;

  String get aiToggleDescription => const {
        AppKind.docs:   'A IA pode criar e editar documentos',
        AppKind.sheets: 'A IA pode criar folhas de cálculo',
        AppKind.slides: 'A IA pode criar apresentações',
        AppKind.sound:  'A IA pode pesquisar música',
      }[this]!;

  bool get hasEditor => editorType != null;

  EditorType? get editorType => const {
        AppKind.docs:   EditorType.docs,
        AppKind.sheets: EditorType.sheets,
        AppKind.slides: EditorType.slides,
        AppKind.sound:  null,
      }[this];
}

class EditTabController extends ChangeNotifier {
  LocalCanvasItem? _pendingLocalLoad;
  LocalCanvasItem? get pendingLocalLoad => _pendingLocalLoad;

  void requestLoadLocal(LocalCanvasItem item) {
    _pendingLocalLoad = item;
    notifyListeners();
  }

  void consumePendingLocalLoad() {
    _pendingLocalLoad = null;
  }
}

final EditTabController editTabController = EditTabController();