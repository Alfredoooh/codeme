═══════════════════════════════════════════════════════════════
PROMPT-ÍNDICE — CraftLab/Nexa — Continuação de sessão
Gerado a partir da inspeção real dos ficheiros do zip (lib__19_.zip
+ editor__1_.zip). Todos os pontos abaixo já foram confirmados
contra o código/HTML reais — nada aqui é hipotético.
Se esta mensagem for cortada por limite de tamanho, cola o resto
como próxima mensagem pedindo "continua o prompt-índice a partir da
PARTE X" — não resumas nem inventes o que falta.
═══════════════════════════════════════════════════════════════

REGRA DE ENTREGA (inegociável): todo código pedido vem SEMPRE
completo, do início ao fim do ficheiro, dentro de um único bloco de
código ```, nunca resumido, nunca com "resto igual", nunca com tools/
bash/str_replace/create_file/artifacts — só bloco de código markdown
na própria mensagem de chat.

═══════════════════════════════════════════════════════════════
PARTE 0 — lib/aitab.dart — CORREÇÃO OBRIGATÓRIA (erro de compilação)
═══════════════════════════════════════════════════════════════

0.1) `static` inválido a nível de topo do ficheiro.

Confirmado: entre a função top-level `_detectOpeningLabel` (linha
~1443) e a função top-level `_endsWithPartialMarker` (linha ~1464),
existe:

    static const List<String> _kPartialMarkerPrefixes = [
      '[[canvas:',
      ...
    ];

`static` fora de classe não compila. Aplicar:

ANTES:
    static const List<String> _kPartialMarkerPrefixes = [

DEPOIS:
    const List<String> _kPartialMarkerPrefixes = [

(resto do array mantém-se — só remover a palavra `static`)

0.2) VERIFICADO, sem ação necessária: `colors.dart` já tem
`previewBackdrop` e `downloadButtonBg`; `aitab.dart` já tem
`LocalCanvasKindX.shortLabel`. Consistentes entre si.

0.3) VERIFICADO, sem ação necessária: SDK do projeto é
`>=3.0.0 <4.0.0` (confirmado no pubspec.yaml colado). O pattern
matching com sealed classes em `_StreamingBubble`
(`switch (el) { case _StreamText(:final text): ... }`) compila
normalmente neste SDK. Não reescrever.

Entregar `lib/aitab.dart` completo já com 0.1 aplicado ANTES de
qualquer parte seguinte que também toque neste ficheiro (Parte 2 e
Parte 3 abaixo alteram aitab.dart de novo — aplicar tudo cumulativo
numa única entrega final do ficheiro, não três entregas separadas).

═══════════════════════════════════════════════════════════════
PARTE 1 — pubspec.yaml (diff a aplicar)
═══════════════════════════════════════════════════════════════

pubspec.yaml ATUAL (confirmado, colado pelo utilizador) já tem:
  flutter_inappwebview: ^6.1.5
  flutter_svg: ^2.0.10+1
  file_picker: ^11.0.3
  image_picker: ^1.2.3
  http: any
  shared_preferences: any
  clipboard: ^0.1.3
  math_expressions: ^2.6.0
  flutter_map: ^7.0.2
  latlong2: ^0.9.1

NÃO tem: pdf, html, archive, pdfx, share_plus, flutter_highlight,
highlight, path_provider.

ADICIONAR (versões estáveis mais recentes disponíveis no pub.dev no
momento da implementação — os números abaixo são ponto de partida):

    pdf: ^3.10.0
    html: ^0.15.0
    archive: ^3.4.0
    pdfx: ^2.6.0
    share_plus: ^7.2.0
    path_provider: ^2.1.0
    flutter_highlight: ^0.7.0
    highlight: ^0.7.0

Nota: `path_provider` NÃO existe no pubspec atual (confirmado) —
é dependência nova obrigatória para `getTemporaryDirectory()` em
`ExportService.shareBytes`, não reaproveitamento de nada existente.

Ícones de linguagem (LanguageIcon): pesquisar no pub.dev pacote
maduro tipo "devicon flutter"/"programming language icon". Se não
houver nenhum fiável, alternativa: SVGs de
https://github.com/devicons/devicon (MIT) ou https://simpleicons.org,
guardados em `assets/icons/lang/{nome}.svg`. Nota: `assets/icons/svg/`,
`assets/icons/svg_color/` e `assets/icons/png/` já existem no
pubspec — `assets/icons/lang/` é uma pasta NOVA a registar em
`flutter: assets:`. Documentar na resposta qual caminho foi seguido.

═══════════════════════════════════════════════════════════════
PARTE 2 — lib/exportservice.dart (ficheiro NOVO)
═══════════════════════════════════════════════════════════════

Criar `lib/exportservice.dart`, classe `ExportService` estática. API
pública EXATA (aitab.dart vai chamar por esta assinatura):

    class ExportService {
      static Future<Uint8List> export({
        required LocalCanvasItem item,
        required String format, // 'docx' | 'xlsx' | 'pptx' | 'pdf' | 'png'
      }) async { ... }

      static Future<void> shareBytes(Uint8List bytes, {required String filename}) async { ... }
    }

2.1) PDF (base também para PNG, ver 2.3):
- kind == doc: `package:html` faz parse do HTML em `item.content`;
  percorrer DOM → `pw.Document`/`pw.Page`/`pw.Column` com
  `pw.Text`/`pw.RichText` para `<p>`/`<h1-h6>`/`<strong>`/`<em>`;
  `<img>` → `pw.Image(pw.MemoryImage(...))` (download via
  `package:http` se URL remota; falha de rede/URL = ignorar essa
  imagem, não rebentar a exportação); `<table>` → `pw.Table`.
- kind == sheet: `item.content` é JSON `{"cells": {...}}` com chaves
  tipo "A1","B3" — iterar linha/coluna, desenhar `pw.Table`, aplicar
  bold/italic/cor do JSON.
- kind == slide: `item.content` é JSON `{"slides": [...]}` — uma
  `pw.Page` por slide, elementos text/image/shape na posição relativa
  correta (escalar coordenadas de 960x540 para o tamanho da página).
- devolver via `await doc.save()`.

2.2) .docx/.xlsx/.pptx nativos (sem `printing`):
Escolher e documentar:
  (a) dependência real madura no pub.dev ("docx generator flutter",
      "xlsx writer dart", "pptx generator dart" — nunca `printing`);
  (b) construir à mão via `package:archive` (ZIP) + XML literal OOXML
      (document.xml + [Content_Types].xml + _rels/.rels no mínimo
      para .docx válido; sheet1.xml para .xlsx; slide1.xml,
      slide2.xml... para .pptx). Texto formatado básico + imagens
      chega, não precisa de todas as features do formato.
Tem de abrir de verdade em Word/Excel/PowerPoint/LibreOffice — nunca
simulação nem .txt com extensão trocada.

2.3) PNG: gerar PDF primeiro (reaproveitar 2.1), rasterizar a
primeira página com `package:pdfx` (ou `pdf_render`, documentar
escolha) para bytes PNG. Nunca RepaintBoundary/screenshot de WebView.

2.4) `shareBytes`: `package:share_plus`, grava bytes em ficheiro
temporário via `getTemporaryDirectory()` (`path_provider`, nova
dependência confirmada na Parte 1) antes de abrir o painel nativo.

Depois de criar o ficheiro, editar `_DocumentWidgetCardState` em
`aitab.dart`:

ANTES (placeholder atual, só SnackBar):
    Future<void> _exportAs(BuildContext context, String format) async {
      // implementação placeholder existente — substituir por inteiro
    }

DEPOIS:
    Future<void> _exportAs(BuildContext context, String format) async {
      try {
        final bytes = await ExportService.export(item: widget.item, format: format);
        await ExportService.shareBytes(bytes, filename: '${widget.item.title}.$format');
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar: $e')),
        );
      }
    }

Adicionar `import 'exportservice.dart';` ao topo de `aitab.dart`.

═══════════════════════════════════════════════════════════════
PARTE 3 — Preview real no DocumentWidgetCard (aitab.dart)
═══════════════════════════════════════════════════════════════

Caminhos HTML CONFIRMADOS (via pubspec.yaml colado, secção
`flutter: assets:`):
    assets/editor/docs.html
    assets/editor/sheets.html
    assets/editor/slides.html
    assets/editor/whiteboard.html
(NÃO usar `file:///android_asset/flutter_assets/...` — usar
`InAppWebViewInitialData` ou `WebUri.asset(...)`/asset loader do
próprio flutter_inappwebview aproveitando estes caminhos já
registados no pubspec; escolher o mecanismo padrão do pacote para
carregar assets Flutter, documentar qual foi usado.)

Mecanismo `?preview=1` CONFIRMADO nos 3 HTML: cada um lê
`params.get('preview') === '1'` → `isPreviewMode = true` → adiciona
classe `preview-mode` ao `<body>` → desativa `contenteditable` e
handlers de interação. Usar exatamente este mecanismo.

`window.editorApi` exposto, CONFIRMADO por ficheiro:
- `docs.html`: expõe `setContent` (NÃO expõe `setContentFromAi`).
- `sheets.html`: expõe `setContent` E `setContentFromAi` (linha 552
  define `setContentFromAi`, linha 576 regista no objeto).
- `slides.html`: expõe `setContent` E `setContentFromAi` (linha 739
  define, linha 763 regista).

Substituir o placeholder central (ícone + label) dentro do
`AspectRatio` de `_DocumentWidgetCardState.build()` por
`InAppWebView` não-interativa carregando o HTML certo para
`item.kind`, com `?preview=1`, e no `onLoadStop` injetar
`item.content` chamando `editorApi.setContent(...)` para doc, e
`editorApi.setContentFromAi(...)` para sheet/slide (ver Parte 6.1
abaixo — o mesmo bug de usar sempre `setContent` existe também em
`edittab.dart`, corrigir os dois consistentemente com a mesma regra:
doc → setContent(string), sheet/slide → setContentFromAi(json)).

Settings da WebView: `javaScriptEnabled: true`,
`transparentBackground: true`, scroll e zoom desativados
(`disableVerticalScroll`, `disableHorizontalScroll`, `supportZoom:
false` — usar os nomes de propriedade reais da versão 6.1.5 de
flutter_inappwebview, confirmar contra a API do pacote antes de
escrever, pode ter mudado nome entre versões).

Efeito STACK (só `kind == LocalCanvasKind.doc`, e só quando o
documento tiver mais de uma página): NÃO simular dentro da WebView.
No Flutter, cortar a `InAppWebView` para mostrar só a área da
primeira página (`ClipRect`/`SizedBox`) e colocar por cima de 1-2
`Container`s brancos com sombra, ligeiramente desalinhados atrás
(`Positioned`/`Transform` com pequeno offset x/y + leve rotação).
Para `sheet`/`slide`: sem stack, sem camadas atrás — só a
`InAppWebView` em preview.

Performance: avaliar `visibility_detector` (dependência auxiliar
NOVA, não está no pubspec atual) para só montar a `InAppWebView`
quando o card entra em viewport, com placeholder leve fora dela.
Decidir e documentar.

═══════════════════════════════════════════════════════════════
PARTE 4 — AiCodePreviewScreen real (aiwidgets.dart)
═══════════════════════════════════════════════════════════════

Substituir:

ANTES:
    body: Center(child: Text('InAppWebView renderiza aqui...')) // TODO

DEPOIS:
    body: InAppWebView(
      initialData: InAppWebViewInitialData(data: html),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
      ),
    ),

Adicionar `import 'package:flutter_inappwebview/flutter_inappwebview.dart';`
ao topo de `aiwidgets.dart`. Resto do ficheiro inalterado.

═══════════════════════════════════════════════════════════════
PARTE 5 — LanguageIcon real (aiwidgets.dart)
═══════════════════════════════════════════════════════════════

Depois de decidida a Parte 1 (dependência vs. assets locais),
substituir o corpo de `LanguageIcon.build()`. Se assets locais:

    class LanguageIcon extends StatelessWidget {
      final String language;
      final double size;
      const LanguageIcon({super.key, required this.language, this.size = 16});

      static const Map<String, String> _assetMap = {
        'dart': 'dart.svg', 'js': 'javascript.svg', 'javascript': 'javascript.svg',
        'ts': 'typescript.svg', 'typescript': 'typescript.svg', 'py': 'python.svg',
        'python': 'python.svg', 'html': 'html5.svg', 'htm': 'html5.svg',
        'css': 'css3.svg', 'json': 'json.svg', 'yaml': 'yaml.svg', 'yml': 'yaml.svg',
      };

      @override
      Widget build(BuildContext context) {
        final asset = _assetMap[language.toLowerCase()];
        if (asset == null) {
          return SizedBox(width: size + 2, height: size + 2,
            child: Center(child: Text('#', style: TextStyle(fontSize: size * 0.8))));
        }
        return SvgPicture.asset('assets/icons/lang/$asset', width: size, height: size);
      }
    }

`import 'package:flutter_svg/flutter_svg.dart';` já disponível
(confirmado no pubspec: `flutter_svg: ^2.0.10+1`).

═══════════════════════════════════════════════════════════════
PARTE 6 — lib/edittab.dart — CORREÇÃO CONFIRMADA (não é decisão,
é bug real já identificado no ficheiro real)
═══════════════════════════════════════════════════════════════

6.1) `_injectLocalCanvas` ignora `item.kind` e chama sempre
`_injectCanvas`, que chama sempre `editorApi.setContent('$escaped')`
com escaping de string (`\\`, `\\'`, `\\n`) — para QUALQUER kind,
incluindo sheet/slide, mesmo os HTML já expondo `setContentFromAi`
para eles (ver Parte 3). Confirmado nas linhas ~180-182:

ANTES:
    void _injectLocalCanvas(InAppWebViewController ctrl, LocalCanvasItem item) {
      _injectCanvas(ctrl, item.content);
    }

DEPOIS (doc usa setContent com string escapada como já fazia; sheet/
slide passam a usar setContentFromAi injetando o JSON diretamente,
sem o escaping de string pensado para HTML):

    void _injectLocalCanvas(InAppWebViewController ctrl, LocalCanvasItem item) {
      if (item.kind == LocalCanvasKind.doc) {
        _injectCanvas(ctrl, item.content);
      } else {
        // sheet/slide: item.content já é uma string JSON válida
        // ({"cells":...} ou {"slides":...}) — injetar diretamente,
        // sem escaping de string (setContentFromAi espera o JSON
        // parseado, não uma string escapada como HTML).
        ctrl.evaluateJavascript(source: "editorApi.setContentFromAi($\{item.content})");
      }
    }

(Rever a chamada acima: confirmar se `setContentFromAi` no JS espera
receber literalmente o objeto JS já parseado ou uma string JSON a
fazer `JSON.parse` — ver corpo de `setContentFromAi` em sheets.html
linha 552 e slides.html linha 739 antes de fechar esta função, para
garantir que o JSON é passado da forma que o JS realmente espera, e
não fica com aspas a mais/menos.)

6.2) VERIFICADO, sem ação necessária: `edittab.dart` já usa
`flutter_inappwebview` (`import` na linha 6) — NÃO usa
`webview_flutter`. Não há migração de motor a decidir, os dois
ficheiros (aitab.dart Parte 3, edittab.dart aqui) já usam o mesmo
motor de WebView.

═══════════════════════════════════════════════════════════════
ORDEM DE ENTREGA
═══════════════════════════════════════════════════════════════
1. Diff do pubspec.yaml (Parte 1) — só linhas novas/alteradas.
2. lib/exportservice.dart completo (Parte 2, ficheiro novo).
3. lib/aitab.dart completo (Partes 0+2+3 cumulativas).
4. lib/aiwidgets.dart completo (Partes 4+5 cumulativas).
5. lib/edittab.dart completo (Parte 6 aplicada).