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