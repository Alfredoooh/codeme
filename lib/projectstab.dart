// ══════════════════════════════════════════════════════════════
// FILE: lib/projectstab.dart
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'colors.dart';
import 'widgets.dart';
import 'api_service.dart';
import 'projects_controller.dart';
import 'drawermenu.dart' show showRenameSheet;
import 'aitab.dart' show LocalCanvasItem, LocalCanvasKind;

// ══════════════════════════════════════════════════════════════
// PROJECTS TAB — grid de cards (galeria), em comunicação real com o
// worker através de projectsController/ProjectsApiService.
// ══════════════════════════════════════════════════════════════

class ProjectsTab extends StatefulWidget {
  final ValueChanged<LocalCanvasItem>? onOpenFile;
  const ProjectsTab({super.key, this.onOpenFile});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  String? _openProjectId;

  @override
  void initState() {
    super.initState();
    projectsController.addListener(_onChanged);
    if (projectsController.nodes.isEmpty && !projectsController.loading) {
      projectsController.load();
    }
  }

  @override
  void dispose() {
    projectsController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() { if (mounted) setState(() {}); }

  void _createProject() {
    showRenameSheet(
      context,
      AppTheme.of(context),
      currentTitle: '',
      title: 'Novo projeto',
      hint: 'Nome do projeto',
      onConfirm: (name) {
        if (name.trim().isEmpty) return;
        projectsController.createProject(name.trim());
      },
    );
  }

  void _openProject(String id) {
    setState(() => _openProjectId = id);
  }

  void _closeProject() {
    setState(() => _openProjectId = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final openId = _openProjectId;

    if (openId != null) {
      final node = projectsController.byId(openId);
      if (node == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _closeProject());
        return const SizedBox.shrink();
      }
      return _ProjectContentsView(
        s: s,
        project: node,
        onBack: _closeProject,
        onOpenFile: widget.onOpenFile,
      );
    }

    final roots = projectsController.roots;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Text('Projetos',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const Spacer(),
          GestureDetector(
            onTap: _createProject,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AppIcon('add.svg', size: 14, color: s.onPrimary),
                const SizedBox(width: 4),
                Text('Novo',
                    style: TextStyle(
                        fontSize: 13,
                        color: s.onPrimary,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _buildBody(s, roots),
      ),
      const SizedBox(height: 92),
    ]);
  }

  Widget _buildBody(AppColorScheme s, List<ProjectNode> roots) {
    if (projectsController.loading && roots.isEmpty) {
      return Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant),
          ),
        ),
      );
    }
    if (projectsController.error != null && roots.isEmpty) {
      return Center(
        child: Text(
          projectsController.error!,
          style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
        ),
      );
    }
    if (roots.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppIcon('projects_tab.svg',
              color: s.onSurfaceVariant.withOpacity(0.35), size: 52),
          const SizedBox(height: 14),
          Text('Sem projetos ainda',
              style: TextStyle(fontSize: 16, color: s.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('Cria o teu primeiro projeto',
              style: TextStyle(
                  fontSize: 13,
                  color: s.onSurfaceVariant.withOpacity(0.55))),
        ]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: roots.length,
      itemBuilder: (_, i) {
        final root = roots[i];
        return _ProjectCard(
          s: s,
          node: root,
          onTap: () => _openProject(root.id),
          onRename: () => showRenameSheet(
            context, s,
            currentTitle: root.name,
            onConfirm: (name) {
              if (name.trim().isEmpty) return;
              projectsController.rename(root.id, name.trim());
            },
          ),
          onDelete: () => _confirmDelete(root),
        );
      },
    );
  }

  void _confirmDelete(ProjectNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConfirmDeleteSheet(
        s: AppTheme.of(context),
        title: node.name,
        onConfirm: () {
          Navigator.pop(ctx);
          projectsController.delete(node.id);
        },
      ),
    );
  }
}

// ── Cartão de projeto (grid da raiz) — ícone grande, contagem de itens ──

class _ProjectCard extends StatefulWidget {
  final AppColorScheme s;
  final ProjectNode node;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _ProjectCard({
    required this.s,
    required this.node,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  @override State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _h = false;

  void _openOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProjectOptionsSheet(
        s: widget.s,
        title: widget.node.name,
        onRename: () { Navigator.pop(ctx); widget.onRename(); },
        onDelete: () { Navigator.pop(ctx); widget.onDelete(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final childCount = projectsController.childrenOf(widget.node.id).length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      onLongPress: _openOptions,
      child: AnimatedScale(
        scale: _h ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: s.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: s.primaryContainer.withOpacity(0.25),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon('folder.svg', size: 40, color: s.primary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.node.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: s.onSurface)),
                    ),
                    GestureDetector(
                      onTap: _openOptions,
                      child: AppIcon('more_filled.svg', size: 14, color: s.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  childCount == 0 ? 'Vazio' : '$childCount item${childCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Conteúdos de um projeto (pastas + ficheiros), também em grid ──

class _ProjectContentsView extends StatefulWidget {
  final AppColorScheme s;
  final ProjectNode project;
  final VoidCallback onBack;
  final ValueChanged<LocalCanvasItem>? onOpenFile;
  const _ProjectContentsView({
    required this.s,
    required this.project,
    required this.onBack,
    this.onOpenFile,
  });
  @override State<_ProjectContentsView> createState() => _ProjectContentsViewState();
}

class _ProjectContentsViewState extends State<_ProjectContentsView> {
  bool _uploading = false;

  void _createFolder() {
    showRenameSheet(
      context, widget.s,
      currentTitle: '',
      title: 'Nova pasta',
      hint: 'Nome da pasta',
      onConfirm: (name) {
        if (name.trim().isEmpty) return;
        projectsController.createFolder(widget.project.id, name.trim());
      },
    );
  }

  void _createFile() {
    showRenameSheet(
      context, widget.s,
      currentTitle: '',
      title: 'Novo documento',
      hint: 'Nome do ficheiro',
      onConfirm: (name) {
        if (name.trim().isEmpty) return;
        projectsController.createGeneratedFile(
          widget.project.id,
          name: name.trim(),
          fileKind: ProjectFileKind.doc,
          content: '<p></p>',
        );
      },
    );
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.pickFiles(allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final kind = _inferFileKind(picked.name);
      await projectsController.uploadFile(
        widget.project.id,
        name: picked.name,
        fileKind: kind,
        fileDataBase64: base64Encode(picked.bytes!),
        mimeType: lookupMimeType(picked.name) ?? 'application/octet-stream',
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  ProjectFileKind _inferFileKind(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return ProjectFileKind.pdf;
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return ProjectFileKind.docx;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv')) return ProjectFileKind.xlsx;
    if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) return ProjectFileKind.pptx;
    return ProjectFileKind.other;
  }

  void _openAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddItemSheet(
        s: widget.s,
        onCreateFolder: () { Navigator.pop(ctx); _createFolder(); },
        onCreateFile: () { Navigator.pop(ctx); _createFile(); },
        onUpload: () { Navigator.pop(ctx); _uploadFile(); },
      ),
    );
  }

  void _renameNode(ProjectNode node) {
    showRenameSheet(
      context, widget.s,
      currentTitle: node.name,
      onConfirm: (name) {
        if (name.trim().isEmpty) return;
        projectsController.rename(node.id, name.trim());
      },
    );
  }

  void _confirmDeleteNode(ProjectNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConfirmDeleteSheet(
        s: widget.s,
        title: node.name,
        onConfirm: () {
          Navigator.pop(ctx);
          projectsController.delete(node.id);
        },
      ),
    );
  }

  void _openNode(ProjectNode node) {
    if (node.type == ProjectNodeType.folder) {
      // Navega para dentro da pasta usando o mesmo mecanismo — abrimos
      // uma nova _ProjectContentsView empilhada por cima.
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppTheme.of(context).surface,
          body: SafeArea(
            child: _ProjectContentsView(
              s: widget.s,
              project: node,
              onBack: () => Navigator.of(context).pop(),
              onOpenFile: widget.onOpenFile,
            ),
          ),
        ),
      ));
      return;
    }
    // Ficheiro: se tiver conteúdo local editável (doc/sheet/slide),
    // abre diretamente no editor via onOpenFile.
    final kind = node.fileKind;
    if (kind != null && node.content != null && widget.onOpenFile != null) {
      final canvasKind = switch (kind) {
        ProjectFileKind.sheet => LocalCanvasKind.sheet,
        ProjectFileKind.slide => LocalCanvasKind.slide,
        _ => LocalCanvasKind.doc,
      };
      widget.onOpenFile!(LocalCanvasItem(
        id: node.id,
        kind: canvasKind,
        title: node.name,
        content: node.content!,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final children = projectsController.childrenOf(widget.project.id);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
        child: Row(children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 34, height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.hover, shape: BoxShape.circle),
              child: AppIcon('back.svg', size: 16, color: s.onSurface),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.project.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: s.onSurface)),
          ),
          GestureDetector(
            onTap: _uploading ? null : _openAddMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: _uploading
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(s.onPrimary)),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      AppIcon('add.svg', size: 14, color: s.onPrimary),
                      const SizedBox(width: 4),
                      Text('Novo', style: TextStyle(fontSize: 13, color: s.onPrimary, fontWeight: FontWeight.w600)),
                    ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: children.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AppIcon('folder.svg', size: 44, color: s.onSurfaceVariant.withOpacity(0.35)),
                  const SizedBox(height: 12),
                  Text('Pasta vazia', style: TextStyle(fontSize: 15, color: s.onSurfaceVariant)),
                ]),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.88,
                ),
                itemCount: children.length,
                itemBuilder: (_, i) {
                  final node = children[i];
                  return _NodeCard(
                    s: s,
                    node: node,
                    onTap: () => _openNode(node),
                    onRename: () => _renameNode(node),
                    onDelete: () => _confirmDeleteNode(node),
                  );
                },
              ),
      ),
    ]);
  }
}

// ── Cartão de nó (pasta ou ficheiro) dentro de um projeto ──

class _NodeCard extends StatefulWidget {
  final AppColorScheme s;
  final ProjectNode node;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _NodeCard({
    required this.s,
    required this.node,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  @override State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  bool _h = false;

  void _openOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProjectOptionsSheet(
        s: widget.s,
        title: widget.node.name,
        onRename: () { Navigator.pop(ctx); widget.onRename(); },
        onDelete: () { Navigator.pop(ctx); widget.onDelete(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final node = widget.node;
    final isFolder = node.isContainer;
    final iconAsset = isFolder ? 'folder.svg' : (node.fileKind?.svgAsset ?? 'file.svg');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      onLongPress: _openOptions,
      child: AnimatedScale(
        scale: _h ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: s.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: s.primaryContainer.withOpacity(0.25),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  alignment: Alignment.center,
                  child: isFolder
                      ? AppIcon(iconAsset, size: 36, color: s.primary)
                      : EditorTypeIcon(iconAsset, size: 36),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(node.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: s.onSurface)),
                    ),
                    GestureDetector(
                      onTap: _openOptions,
                      child: AppIcon('more_filled.svg', size: 14, color: s.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  isFolder ? 'Pasta' : (node.fileKind?.label ?? 'Ficheiro'),
                  style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheets auxiliares (mantidos iguais) ─────────────────────────

class _AddItemSheet extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateFile;
  final VoidCallback onUpload;
  const _AddItemSheet({
    required this.s,
    required this.onCreateFolder,
    required this.onCreateFile,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: SheetGrabber(s: s)),
                _SheetOptionRow(s: s, icon: 'folder.svg', label: 'Criar pasta', onTap: onCreateFolder),
                _SheetOptionRow(s: s, icon: 'doc.png', useEditorIcon: true, label: 'Criar ficheiro', onTap: onCreateFile),
                _SheetOptionRow(s: s, icon: 'file.svg', label: 'Upload de ficheiro', onTap: onUpload),
              ],
            ),
          ),
        ),
      );
}

class _ProjectOptionsSheet extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _ProjectOptionsSheet({
    required this.s,
    required this.title,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: SheetGrabber(s: s)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: s.onSurfaceVariant)),
                ),
                _SheetOptionRow(s: s, icon: 'edit.svg', label: 'Renomear', onTap: onRename),
                _SheetOptionRow(s: s, icon: 'trash.svg', label: 'Eliminar', destructive: true, onTap: onDelete),
              ],
            ),
          ),
        ),
      );
}

class _ConfirmDeleteSheet extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onConfirm;
  const _ConfirmDeleteSheet({required this.s, required this.title, required this.onConfirm});

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: SheetGrabber(s: s)),
                Text('Eliminar "$title"?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: s.onSurface)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: _ConfirmButton(
                      s: s, label: 'Cancelar', filled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ConfirmButton(
                      s: s, label: 'Eliminar', filled: true, onTap: onConfirm,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}

class _ConfirmButton extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ConfirmButton({required this.s, required this.label, required this.filled, required this.onTap});
  @override State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? s.error : s.hover,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(widget.label,
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: widget.filled ? s.onError : s.onSurface,
              )),
        ),
      ),
    );
  }
}

class _SheetOptionRow extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool useEditorIcon;
  const _SheetOptionRow({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.useEditorIcon = false,
  });
  @override State<_SheetOptionRow> createState() => _SheetOptionRowState();
}

class _SheetOptionRowState extends State<_SheetOptionRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.destructive ? widget.s.error : widget.s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _h ? widget.s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          widget.useEditorIcon
              ? EditorTypeIcon(widget.icon, size: 18)
              : AppIcon(widget.icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(widget.label,
              style: TextStyle(fontSize: 14.5, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}