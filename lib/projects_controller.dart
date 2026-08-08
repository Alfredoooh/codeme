// ══════════════════════════════════════════════════════════════
// FILE: lib/projects_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_service.dart';

// ══════════════════════════════════════════════════════════════
// PROJECTS CONTROLLER — carrega a árvore achatada do worker e
// expõe helpers para navegar/mutar localmente com sync imediato
// para o backend (mesmo padrão do ConversationsController já
// existente em drawermenu.dart).
// ══════════════════════════════════════════════════════════════

class ProjectsController extends ChangeNotifier {
  List<ProjectNode> nodes = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    final token = authController.token;
    if (token == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      nodes = await ProjectsApiService.list(token);
    } catch (_) {
      error = 'Não foi possível carregar os projetos';
    }
    loading = false;
    notifyListeners();
  }

  /// Nós de topo — são os "projetos" propriamente ditos.
  List<ProjectNode> get roots => nodes.where((n) => n.parentId == null).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<ProjectNode> childrenOf(String parentId) =>
      nodes.where((n) => n.parentId == parentId).toList()
        ..sort((a, b) {
          // Pastas/subprojetos primeiro, depois ficheiros; dentro de
          // cada grupo, mais recente primeiro.
          if (a.isContainer != b.isContainer) return a.isContainer ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });

  ProjectNode? byId(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  void upsertLocal(ProjectNode node) {
    final idx = nodes.indexWhere((n) => n.id == node.id);
    if (idx == -1) {
      nodes.add(node);
    } else {
      nodes[idx] = node;
    }
    notifyListeners();
  }

  void removeLocalSubtree(String id) {
    final toRemove = <String>{id};
    bool changed = true;
    while (changed) {
      changed = false;
      for (final n in nodes) {
        if (n.parentId != null && toRemove.contains(n.parentId) && !toRemove.contains(n.id)) {
          toRemove.add(n.id);
          changed = true;
        }
      }
    }
    nodes.removeWhere((n) => toRemove.contains(n.id));
    notifyListeners();
  }

  Future<ProjectNode?> createProject(String name) async {
    final token = authController.token;
    if (token == null) return null;
    final node = await ProjectsApiService.create(
      token, type: ProjectNodeType.project, name: name, parentId: null,
    );
    if (node != null) upsertLocal(node);
    return node;
  }

  Future<ProjectNode?> createFolder(String parentId, String name) async {
    final token = authController.token;
    if (token == null) return null;
    final node = await ProjectsApiService.create(
      token, type: ProjectNodeType.folder, name: name, parentId: parentId,
    );
    if (node != null) upsertLocal(node);
    return node;
  }

  Future<ProjectNode?> linkConversation(
    String parentId, {
    required String conversationId,
    required String title,
  }) async {
    final token = authController.token;
    if (token == null) return null;
    final node = await ProjectsApiService.create(
      token,
      type: ProjectNodeType.file,
      name: title,
      parentId: parentId,
      fileKind: ProjectFileKind.chat,
      conversationId: conversationId,
    );
    if (node != null) upsertLocal(node);
    return node;
  }

  Future<ProjectNode?> createGeneratedFile(
    String parentId, {
    required String name,
    required ProjectFileKind fileKind,
    required String content,
  }) async {
    final token = authController.token;
    if (token == null) return null;
    final node = await ProjectsApiService.create(
      token,
      type: ProjectNodeType.file,
      name: name,
      parentId: parentId,
      fileKind: fileKind,
      content: content,
    );
    if (node != null) upsertLocal(node);
    return node;
  }

  Future<ProjectNode?> uploadFile(
    String parentId, {
    required String name,
    required ProjectFileKind fileKind,
    required String fileDataBase64,
    String? mimeType,
  }) async {
    final token = authController.token;
    if (token == null) return null;
    final node = await ProjectsApiService.create(
      token,
      type: ProjectNodeType.file,
      name: name,
      parentId: parentId,
      fileKind: fileKind,
      fileData: fileDataBase64,
      mimeType: mimeType,
    );
    if (node != null) upsertLocal(node);
    return node;
  }

  Future<void> rename(String id, String newName) async {
    final token = authController.token;
    if (token == null) return;
    final idx = nodes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    nodes[idx] = nodes[idx].copyWith(name: newName);
    notifyListeners();
    await ProjectsApiService.update(token, id, name: newName);
  }

  Future<void> delete(String id) async {
    final token = authController.token;
    if (token == null) return;
    removeLocalSubtree(id);
    await ProjectsApiService.delete(token, id);
  }
}

final ProjectsController projectsController = ProjectsController();