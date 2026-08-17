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

class _ProjectsTabState extends State<ProjectsTab>
    with ThemeReactive<ProjectsTab> {
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

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _createProject() {
    showRenameSheet(
      context,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            kSpaceXL,
            kSpaceL,
            kSpaceXL,
            kSpaceL,
          ),
          child: Row(
            children: [
              Text(
                'Projetos',
                style: TextStyle(
                  fontSize: kTypeSubtitle,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface,
                ),
              ),
              const Spacer(),
              FluentButton(
                label: 'Novo',
                onTap: _createProject,
                style: FluentButtonStyle.primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildBody(s, roots),
        ),
        SizedBox(height: kSpaceXXXL + kSpaceXXXL + kSpaceXXL + kSpaceXS),
      ],
    );
  }

  Widget _buildBody(AppColorScheme s, List<ProjectNode> roots) {
    if (projectsController.loading && roots.isEmpty) {
      return Center(
        child: FluentShimmer(
          width: kSpaceXXL,
          height: kSpaceXXL,
          borderRadius: kRadiusSmall,
        ),
      );
    }
    if (projectsController.error != null && roots.isEmpty) {
      return Center(
        child: Text(
          projectsController.error!,
          style: TextStyle(fontSize: kTypeBody, color: s.onSurfaceVariant),
        ),
      );
    }
    if (roots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              'projects_tab.svg',
              color: s.onSurfaceTertiary,
              size: 52,
            ),
            SizedBox(height: kSpaceL - kSpaceXXS), // 14
            Text(
              'Sem projetos ainda',
              style: TextStyle(fontSize: kTypeBodyLarge, color: s.onSurfaceVariant),
            ),
            SizedBox(height: kSpaceXS),
            Text(
              'Cria o teu primeiro projeto',
              style: TextStyle(fontSize: kTypeBody, color: s.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        kSpaceL,
        kSpaceXS,
        kSpaceL,
        kSpaceM,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: kSpaceM,
        crossAxisSpacing: kSpaceM,
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
            context,
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
    showFluentBottomSheet(
      context: context,
      builder: (ctx) => _ConfirmDeleteSheet(
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
  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _h = false;

  void _openOptions() {
    showFluentBottomSheet(
      context: context,
      builder: (ctx) => _ProjectOptionsSheet(
        title: widget.node.name,
        onRename: () {
          Navigator.pop(ctx);
          widget.onRename();
        },
        onDelete: () {
          Navigator.pop(ctx);
          widget.onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final childCount = projectsController.childrenOf(widget.node.id).length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _h = true),
      onTapCancel: () => setState(() => _h = false),
      onTapUp: (_) => setState(() => _h = false),
      onTap: widget.onTap,
      onLongPress: _openOptions,
      child: AnimatedScale(
        scale: _h ? 0.97 : 1.0,
        duration: kDurationFast,
        child: Container(
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(kRadiusLarge),
            boxShadow: s.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    // withOpacity usado porque não existe token específico
                    // para esta variante translúcida do primaryContainer.
                    color: s.primaryContainer.withOpacity(0.25),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(kRadiusLarge),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    'folder.svg',
                    size: 40,
                    color: s.primary,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  kSpaceM,
                  kSpaceS + kSpaceXXS, // 10
                  kSpaceM,
                  kSpaceXS,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: kTypeBody,
                          fontWeight: FontWeight.w600,
                          color: s.onSurface,
                        ),
                      ),
                    ),
                    AppTap(
                      onTap: _openOptions,
                      s: s,
                      child: AppIcon(
                        'more_filled.svg',
                        size: 14,
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  kSpaceM,
                  0,
                  kSpaceM,
                  kSpaceM,
                ),
                child: Text(
                  childCount == 0
                      ? 'Vazio'
                      : '$childCount item${childCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: kTypeCaption,
                    color: s.onSurfaceVariant,
                  ),
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
  @override
  State<_ProjectContentsView> createState() => _ProjectContentsViewState();
}

class _ProjectContentsViewState extends State<_ProjectContentsView> {
  bool _uploading = false;

  void _createFolder() {
    showRenameSheet(
      context,
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
      context,
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
    final result =
        await FilePicker.pickFiles(allowMultiple: false, withData: true);
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
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      return ProjectFileKind.docx;
    }
    if (lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.csv')) {
      return ProjectFileKind.xlsx;
    }
    if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) {
      return ProjectFileKind.pptx;
    }
    return ProjectFileKind.other;
  }

  void _openAddMenu() {
    showFluentBottomSheet(
      context: context,
      builder: (ctx) => _AddItemSheet(
        onCreateFolder: () {
          Navigator.pop(ctx);
          _createFolder();
        },
        onCreateFile: () {
          Navigator.pop(ctx);
          _createFile();
        },
        onUpload: () {
          Navigator.pop(ctx);
          _uploadFile();
        },
      ),
    );
  }

  void _renameNode(ProjectNode node) {
    showRenameSheet(
      context,
      currentTitle: node.name,
      onConfirm: (name) {
        if (name.trim().isEmpty) return;
        projectsController.rename(node.id, name.trim());
      },
    );
  }

  void _confirmDeleteNode(ProjectNode node) {
    showFluentBottomSheet(
      context: context,
      builder: (ctx) => _ConfirmDeleteSheet(
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
      Navigator.of(context).push(
        MaterialPageRoute(
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
        ),
      );
      return;
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            kSpaceM,
            kSpaceL,
            kSpaceXL,
            kSpaceL,
          ),
          child: Row(
            children: [
              FluentIconButton(
                icon: AppIcon('back.svg', color: s.onSurface, size: 16),
                onTap: widget.onBack,
                s: s,
              ),
              SizedBox(width: kSpaceS + kSpaceXXS), // 10
              Expanded(
                child: Text(
                  widget.project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: kTypeBodyLarge,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface,
                  ),
                ),
              ),
              FluentButton(
                label: _uploading ? 'A enviar...' : 'Novo',
                onTap: _uploading ? null : _openAddMenu,
                style: FluentButtonStyle.primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        'folder.svg',
                        size: 44,
                        color: s.onSurfaceTertiary,
                      ),
                      SizedBox(height: kSpaceM),
                      Text(
                        'Pasta vazia',
                        style: TextStyle(
                          fontSize: kTypeBodyLarge,
                          color: s.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    kSpaceL,
                    kSpaceXS,
                    kSpaceL,
                    kSpaceXXL,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: kSpaceM,
                    crossAxisSpacing: kSpaceM,
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
      ],
    );
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
  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  bool _h = false;

  void _openOptions() {
    showFluentBottomSheet(
      context: context,
      builder: (ctx) => _ProjectOptionsSheet(
        title: widget.node.name,
        onRename: () {
          Navigator.pop(ctx);
          widget.onRename();
        },
        onDelete: () {
          Navigator.pop(ctx);
          widget.onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final node = widget.node;
    final isFolder = node.isContainer;
    final iconAsset =
        isFolder ? 'folder.svg' : (node.fileKind?.svgAsset ?? 'file.svg');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _h = true),
      onTapCancel: () => setState(() => _h = false),
      onTapUp: (_) => setState(() => _h = false),
      onTap: widget.onTap,
      onLongPress: _openOptions,
      child: AnimatedScale(
        scale: _h ? 0.97 : 1.0,
        duration: kDurationFast,
        child: Container(
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(kRadiusLarge),
            boxShadow: s.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    // withOpacity usado porque não existe token específico
                    // para esta variante translúcida do primaryContainer.
                    color: s.primaryContainer.withOpacity(0.25),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(kRadiusLarge),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isFolder
                      ? AppIcon(
                          iconAsset,
                          size: 36,
                          color: s.primary,
                        )
                      : EditorTypeIcon(iconAsset, size: 36),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  kSpaceM,
                  kSpaceS + kSpaceXXS, // 10
                  kSpaceM,
                  kSpaceXS,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: kTypeBody,
                          fontWeight: FontWeight.w600,
                          color: s.onSurface,
                        ),
                      ),
                    ),
                    AppTap(
                      onTap: _openOptions,
                      s: s,
                      child: AppIcon(
                        'more_filled.svg',
                        size: 14,
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  kSpaceM,
                  0,
                  kSpaceM,
                  kSpaceM,
                ),
                child: Text(
                  isFolder ? 'Pasta' : (node.fileKind?.label ?? 'Ficheiro'),
                  style: TextStyle(
                    fontSize: kTypeCaption,
                    color: s.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheets auxiliares (agora usando FluentBottomSheet e FluentListGroup) ──

class _AddItemSheet extends StatelessWidget {
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateFile;
  final VoidCallback onUpload;
  const _AddItemSheet({
    required this.onCreateFolder,
    required this.onCreateFile,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return FluentBottomSheet(
      child: FluentListGroup(
        children: [
          FluentListCard(
            leading: AppIcon('folder.svg', color: s.primary, size: 18),
            title: 'Criar pasta',
            onTap: onCreateFolder,
          ),
          FluentListCard(
            leading: AppIcon('doc.png', color: s.primary, size: 18),
            title: 'Criar ficheiro',
            onTap: onCreateFile,
          ),
          FluentListCard(
            leading: AppIcon('file.svg', color: s.primary, size: 18),
            title: 'Upload de ficheiro',
            onTap: onUpload,
          ),
        ],
      ),
    );
  }
}

class _ProjectOptionsSheet extends StatelessWidget {
  final String title;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _ProjectOptionsSheet({
    required this.title,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return FluentBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              kSpaceM,
              0,
              kSpaceM,
              kSpaceS,
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: kTypeBody,
                fontWeight: FontWeight.w600,
                color: s.onSurfaceVariant,
              ),
            ),
          ),
          FluentListGroup(
            children: [
              FluentListCard(
                leading: AppIcon('edit.svg', color: s.onSurface, size: 18),
                title: 'Renomear',
                onTap: onRename,
              ),
              FluentListCard(
                leading: AppIcon('trash.svg', color: s.error, size: 18),
                title: 'Eliminar',
                titleColor: s.error,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmDeleteSheet extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;
  const _ConfirmDeleteSheet({
    required this.title,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return FluentBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Eliminar "$title"?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: kTypeBody,
              fontWeight: FontWeight.w500,
              color: s.onSurface,
            ),
          ),
          SizedBox(height: kSpaceXL),
          Row(
            children: [
              Expanded(
                child: FluentButton(
                  label: 'Cancelar',
                  onTap: () => Navigator.pop(context),
                  style: FluentButtonStyle.secondary,
                ),
              ),
              SizedBox(width: kSpaceS + kSpaceXXS), // 10
              Expanded(
                child: FluentButton(
                  label: 'Eliminar',
                  onTap: onConfirm,
                  style: FluentButtonStyle.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}