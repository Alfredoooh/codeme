// ══════════════════════════════════════════════════════════════
// FILE: lib/templatestab.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';
import 'aitab.dart' show LocalCanvasItem, LocalCanvasKind;

class TemplateDef {
  final String id;
  final String title;
  final String category;
  final LocalCanvasKind kind;
  final String iconAsset;
  final String content;
  const TemplateDef({
    required this.id,
    required this.title,
    required this.category,
    required this.kind,
    required this.iconAsset,
    required this.content,
  });
}

final List<TemplateDef> kTemplates = [
  TemplateDef(
    id: 'meeting-notes',
    title: 'Notas de reunião',
    category: 'Documentos',
    kind: LocalCanvasKind.doc,
    iconAsset: 'doc.png',
    content: '<h2>Notas de reunião</h2>'
        '<p><strong>Data:</strong> </p>'
        '<p><strong>Participantes:</strong> </p>'
        '<h3>Pontos discutidos</h3><p></p>'
        '<h3>Ações a seguir</h3><p></p>',
  ),
  TemplateDef(
    id: 'project-brief',
    title: 'Briefing de projeto',
    category: 'Documentos',
    kind: LocalCanvasKind.doc,
    iconAsset: 'doc.png',
    content: '<h2>Briefing de projeto</h2>'
        '<p><strong>Objetivo:</strong> </p>'
        '<p><strong>Prazo:</strong> </p>'
        '<h3>Contexto</h3><p></p>'
        '<h3>Entregáveis</h3><p></p>',
  ),
  TemplateDef(
    id: 'pitch-deck',
    title: 'Pitch deck',
    category: 'Apresentações',
    kind: LocalCanvasKind.slide,
    iconAsset: 'slide.png',
    content:
        '{"slides":[{"id":0,"elements":[{"id":0,"type":"text","x":80,"y":180,"w":800,"h":100,"fontSize":40,"color":"#1a1a1a","html":"Título da apresentação"},{"id":1,"type":"text","x":80,"y":300,"w":800,"h":60,"fontSize":18,"color":"#666666","html":"Subtítulo ou tagline"}]}],"currentSlideIndex":0}',
  ),
  TemplateDef(
    id: 'budget-tracker',
    title: 'Controlo de orçamento',
    category: 'Folhas',
    kind: LocalCanvasKind.sheet,
    iconAsset: 'sheet.png',
    content: '{"cells":{'
        '"A1":{"value":"Item","bold":true},'
        '"B1":{"value":"Categoria","bold":true},'
        '"C1":{"value":"Valor","bold":true},'
        '"A2":{"value":""},"B2":{"value":""},"C2":{"value":""}'
        '}}',
  ),
  TemplateDef(
    id: 'weekly-planner',
    title: 'Planeamento semanal',
    category: 'Folhas',
    kind: LocalCanvasKind.sheet,
    iconAsset: 'sheet.png',
    content: '{"cells":{'
        '"A1":{"value":"Dia","bold":true},'
        '"B1":{"value":"Tarefas","bold":true},'
        '"A2":{"value":"Segunda"},"A3":{"value":"Terça"},'
        '"A4":{"value":"Quarta"},"A5":{"value":"Quinta"},"A6":{"value":"Sexta"}'
        '}}',
  ),
  TemplateDef(
    id: 'brainstorm-board',
    title: 'Quadro de brainstorm',
    category: 'Quadros',
    kind: LocalCanvasKind.whiteboard,
    iconAsset: 'whiteboard.png',
    content: '{}',
  ),
];

class TemplatesTab extends StatefulWidget {
  final ValueChanged<LocalCanvasItem>? onOpenTemplate;
  const TemplatesTab({super.key, this.onOpenTemplate});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab>
    with ThemeReactive<TemplatesTab> {
  String _category = 'Todos';
  int _idSeq = 0;

  static const _categories = [
    'Todos', 'Documentos', 'Apresentações', 'Folhas', 'Quadros'
  ];

  List<TemplateDef> get _filtered => _category == 'Todos'
      ? kTemplates
      : kTemplates.where((t) => t.category == _category).toList();

  void _openTemplate(TemplateDef def) {
    final item = LocalCanvasItem(
      id: 'tpl_${DateTime.now().millisecondsSinceEpoch}_${_idSeq++}',
      kind: def.kind,
      title: def.title,
      content: def.content,
    );
    widget.onOpenTemplate?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final items = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            kSpaceXL,
            kSpaceL,
            kSpaceXL,
            kSpaceM,
          ),
          child: Text(
            'Templates',
            style: TextStyle(
              fontSize: kTypeSubtitle,
              fontWeight: FontWeight.w700,
              color: s.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: kSpaceXXXL + kSpaceXS,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: kSpaceXL),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => SizedBox(width: kSpaceS),
            itemBuilder: (_, i) => FluentChip(
              s: s,
              label: _categories[i],
              selected: _category == _categories[i],
              onTap: () => setState(() => _category = _categories[i]),
            ),
          ),
        ),
        SizedBox(height: kSpaceL),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        'doc_text.svg',
                        size: 48,
                        color: s.onSurfaceTertiary,
                      ),
                      SizedBox(height: kSpaceM),
                      Text(
                        'Sem templates nesta categoria',
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
                    0,
                    kSpaceL,
                    kSpaceXXXL + kSpaceXXXL + kSpaceXXL + kSpaceXS,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: kSpaceM,
                    crossAxisSpacing: kSpaceM,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _TemplateCard(
                    s: s,
                    def: items[i],
                    onTap: () => _openTemplate(items[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final AppColorScheme s;
  final TemplateDef def;
  final VoidCallback onTap;
  const _TemplateCard({
    required this.s,
    required this.def,
    required this.onTap,
  });
  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _h = true),
      onTapCancel: () => setState(() => _h = false),
      onTapUp: (_) => setState(() => _h = false),
      onTap: widget.onTap,
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
                    color: s.primaryContainer.withOpacity(0.25),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(kRadiusLarge),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: EditorTypeIcon(widget.def.iconAsset, size: 40),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  kSpaceM,
                  kSpaceS + kSpaceXXS,
                  kSpaceM,
                  kSpaceM,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.def.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: kTypeBody,
                        fontWeight: FontWeight.w600,
                        color: s.onSurface,
                      ),
                    ),
                    SizedBox(height: kSpaceXXS),
                    Text(
                      widget.def.category,
                      style: TextStyle(
                        fontSize: kTypeCaption,
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}