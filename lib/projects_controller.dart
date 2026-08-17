// ══════════════════════════════════════════════════════════════
// FILE: lib/projects_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_service.dart';

// ══════════════════════════════════════════════════════════════
// PROJECTS CONTROLLER — fonte de verdade para os projetos/fiheiros
// da tab de Projetos. Liga a UI (ProjectsTab) à API real do worker.
// ══════════════════════════════════════════════════════════════

class ProjectsController extends ChangeNotifier {
  List<ProjectNode> nodes = [];
  bool loading = false;
  String? error;

  List<ProjectNode> get roots =>
      nodes.where((n) => n.parentId == null || n.parentId!.isEmpty).toList();

  ProjectNode? byId(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<ProjectNode> childrenOf(String parentId) =>
      nodes.where((n) => n.parentId == parentId).toList();

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

  Future<void> createProject(String name) async {
    final token = authController.token;
    if (token == null) return;
    final node = await ProjectsApiService.create(
      token,
      type: ProjectNodeType.project,
      name: name,
    );
    if (node != null) {
      nodes.add(node);
      notifyListeners();
    }
  }

  Future<void> createFolder(String parentId, String name) async {
    final token = authController.token;
    if (token == null) return;
    final node = await ProjectsApiService.create(
      token,
      type: ProjectNodeType.folder,
      name: name,
      parentId: parentId,
    );
    if (node != null) {
      nodes.add(node);
      notifyListeners();
    }
  }

  Future<void> createGeneratedFile(
    String parentId, {
    required String name,
    required ProjectFileKind fileKind,
    required String content,
  }) async {
    final token = authController.token;
    if (token == null) return;
    final node = await ProjectsApiService.create(
      token,
      type: ProjectNodeType.file,
      name: name,
      parentId: parentId,
      fileKind: fileKind,
      content: content,
    );
    if (node != null) {
      nodes.add(node);
      notifyListeners();
    }
  }

  Future<void> uploadFile(
    String parentId, {
    required String name,
    required ProjectFileKind fileKind,
    required String fileDataBase64,
    required String mimeType,
  }) async {
    final token = authController.token;
    if (token == null) return;
    final node = await ProjectsApiService.create(
      token,
      type: ProjectNodeType.file,
      name: name,
      parentId: parentId,
      fileKind: fileKind,
      fileData: fileDataBase64,
      mimeType: mimeType,
    );
    if (node != null) {
      nodes.add(node);
      notifyListeners();
    }
  }

  Future<void> rename(String id, String newName) async {
    final token = authController.token;
    if (token == null) return;
    final idx = nodes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final updated = await ProjectsApiService.update(token, id, name: newName);
    if (updated != null) {
      nodes[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    final token = authController.token;
    if (token == null) return;
    final ok = await ProjectsApiService.delete(token, id);
    if (ok) {
      nodes.removeWhere((n) => n.id == id || n.parentId == id);
      notifyListeners();
    }
  }
}

final ProjectsController projectsController = ProjectsController();