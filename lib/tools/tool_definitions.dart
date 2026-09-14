=====================================================================
lib/tools/tool_definitions.dart
=====================================================================

// Schemas das tools locais — equivalente ao definitions.js do Node.
// Usado para: (1) documentação/introspecção, (2) validação de input
// antes de despachar, (3) expor via endpoint GET /tools caso um
// agente de IA precise descobrir dinamicamente o que está disponível.
//
// NÃO inclui as tools de rede externa (web_search, get_weather, etc.)
// — essas continuam definidas e servidas apenas pelo backend Node.

class ToolParamSchema {
  final String type; // "string", "number", "boolean", "object", "array"
  final String? description;
  final bool required;

  const ToolParamSchema({
    required this.type,
    this.description,
    this.required = false,
  });
}

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, ToolParamSchema> inputSchema;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });
}

const List<ToolDefinition> localToolDefinitions = [
  // ── Documentos ────────────────────────────────────────────
  ToolDefinition(
    name: 'create_pdf',
    description:
        'Gera um PDF a partir de HTML formatado (CSS suportado), '
        'renderizado via WebView para fidelidade visual completa.',
    inputSchema: {
      'html': ToolParamSchema(type: 'string', required: true),
      'page_format': ToolParamSchema(
        type: 'string',
        description: 'A4, Letter, etc. Default: A4.',
      ),
    },
  ),
  ToolDefinition(
    name: 'create_pdf_structured',
    description:
        'Gera um PDF estruturado (título, seções, tabelas) a partir '
        'de HTML formatado com layout mais controlado.',
    inputSchema: {
      'title': ToolParamSchema(type: 'string'),
      'html': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'merge_pdfs',
    description: 'Combina múltiplos PDFs (base64) em um único arquivo.',
    inputSchema: {
      'pdfs_base64': ToolParamSchema(type: 'array', required: true),
    },
  ),
  ToolDefinition(
    name: 'split_pdf_pages',
    description: 'Extrai páginas específicas de um PDF para um novo arquivo.',
    inputSchema: {
      'pdf_base64': ToolParamSchema(type: 'string', required: true),
      'page_numbers': ToolParamSchema(type: 'array', required: true),
    },
  ),
  ToolDefinition(
    name: 'read_pdf_contents',
    description: 'Extrai texto e estrutura de um PDF (base64).',
    inputSchema: {
      'pdf_base64': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'create_docx',
    description: 'Gera um documento Word (.docx) a partir de HTML formatado.',
    inputSchema: {
      'html': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'create_pptx',
    description: 'Gera uma apresentação PowerPoint a partir de slides estruturados.',
    inputSchema: {
      'title': ToolParamSchema(type: 'string'),
      'slides': ToolParamSchema(type: 'array', required: true),
    },
  ),
  ToolDefinition(
    name: 'create_xlsx',
    description: 'Gera uma planilha Excel a partir de cabeçalhos e linhas.',
    inputSchema: {
      'sheet_name': ToolParamSchema(type: 'string'),
      'headers': ToolParamSchema(type: 'array', required: true),
      'rows': ToolParamSchema(type: 'array', required: true),
    },
  ),
  ToolDefinition(
    name: 'csv_to_xlsx',
    description: 'Converte conteúdo CSV em arquivo .xlsx.',
    inputSchema: {
      'csv_content': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'xlsx_to_json',
    description: 'Converte um .xlsx (base64) em JSON.',
    inputSchema: {
      'xlsx_base64': ToolParamSchema(type: 'string', required: true),
    },
  ),

  // ── Imagens ───────────────────────────────────────────────
  ToolDefinition(
    name: 'generate_qrcode',
    description: 'Gera uma imagem de QR Code.',
    inputSchema: {
      'content': ToolParamSchema(type: 'string', required: true),
      'size': ToolParamSchema(type: 'number'),
    },
  ),
  ToolDefinition(
    name: 'generate_barcode',
    description: 'Gera uma imagem de código de barras.',
    inputSchema: {
      'content': ToolParamSchema(type: 'string', required: true),
      'format': ToolParamSchema(type: 'string'),
    },
  ),
  ToolDefinition(
    name: 'convert_image_format',
    description: 'Converte uma imagem entre formatos (PNG, JPEG, etc.).',
    inputSchema: {
      'image_base64': ToolParamSchema(type: 'string', required: true),
      'target_format': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'resize_image',
    description: 'Redimensiona uma imagem.',
    inputSchema: {
      'image_base64': ToolParamSchema(type: 'string', required: true),
      'width': ToolParamSchema(type: 'number', required: true),
      'height': ToolParamSchema(type: 'number', required: true),
    },
  ),
  ToolDefinition(
    name: 'crop_image',
    description: 'Recorta uma região retangular de uma imagem.',
    inputSchema: {
      'image_base64': ToolParamSchema(type: 'string', required: true),
      'left': ToolParamSchema(type: 'number', required: true),
      'top': ToolParamSchema(type: 'number', required: true),
      'width': ToolParamSchema(type: 'number', required: true),
      'height': ToolParamSchema(type: 'number', required: true),
    },
  ),
  ToolDefinition(
    name: 'watermark_image',
    description: 'Aplica marca d\'água de texto sobre uma imagem.',
    inputSchema: {
      'image_base64': ToolParamSchema(type: 'string', required: true),
      'watermark_text': ToolParamSchema(type: 'string', required: true),
      'position': ToolParamSchema(type: 'string'),
    },
  ),
  ToolDefinition(
    name: 'ocr_extract_text',
    description: 'Extrai texto de uma imagem via OCR on-device.',
    inputSchema: {
      'image_base64': ToolParamSchema(type: 'string', required: true),
      'language': ToolParamSchema(type: 'string'),
    },
  ),
  ToolDefinition(
    name: 'generate_table_image',
    description: 'Gera uma imagem representando uma tabela.',
    inputSchema: {
      'title': ToolParamSchema(type: 'string'),
      'headers': ToolParamSchema(type: 'array', required: true),
      'rows': ToolParamSchema(type: 'array', required: true),
    },
  ),
  ToolDefinition(
    name: 'render_html_to_image',
    description: 'Renderiza HTML formatado e captura como imagem PNG.',
    inputSchema: {
      'html': ToolParamSchema(type: 'string', required: true),
      'width': ToolParamSchema(type: 'number'),
      'height': ToolParamSchema(type: 'number'),
      'scale': ToolParamSchema(type: 'number'),
    },
  ),

  // ── Charts ────────────────────────────────────────────────
  ToolDefinition(
    name: 'generate_chart',
    description: 'Gera um gráfico (barra, linha, pizza) a partir de dados.',
    inputSchema: {
      'chart_type': ToolParamSchema(type: 'string', required: true),
      'title': ToolParamSchema(type: 'string'),
      'labels': ToolParamSchema(type: 'array', required: true),
      'datasets': ToolParamSchema(type: 'array', required: true),
    },
  ),
  ToolDefinition(
    name: 'generate_function_plot',
    description: 'Plota o gráfico de uma expressão matemática.',
    inputSchema: {
      'expression': ToolParamSchema(type: 'string', required: true),
      'x_min': ToolParamSchema(type: 'number'),
      'x_max': ToolParamSchema(type: 'number'),
      'title': ToolParamSchema(type: 'string'),
      'highlight_roots': ToolParamSchema(type: 'boolean'),
    },
  ),
  ToolDefinition(
    name: 'generate_math_sheet',
    description: 'Gera folha visual com resolução passo a passo de expressão matemática.',
    inputSchema: {
      'expression': ToolParamSchema(type: 'string', required: true),
      'show_graph': ToolParamSchema(type: 'boolean'),
    },
  ),

  // ── Mindmap ───────────────────────────────────────────────
  ToolDefinition(
    name: 'generate_mindmap',
    description: 'Gera imagem de mapa mental a partir de estrutura raiz com nós aninhados.',
    inputSchema: {
      'root': ToolParamSchema(type: 'object', required: true),
    },
  ),

  // ── Arquivos ──────────────────────────────────────────────
  ToolDefinition(
    name: 'create_file',
    description: 'Cria um arquivo genérico local a partir de conteúdo.',
    inputSchema: {
      'filename': ToolParamSchema(type: 'string', required: true),
      'content': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'read_zip_contents',
    description: 'Lê e lista o conteúdo de um arquivo .zip (base64).',
    inputSchema: {
      'zip_base64': ToolParamSchema(type: 'string', required: true),
    },
  ),

  // ── Texto ─────────────────────────────────────────────────
  ToolDefinition(
    name: 'str_replace_file',
    description: 'Substitui uma ocorrência de texto dentro de um conteúdo.',
    inputSchema: {
      'content': ToolParamSchema(type: 'string', required: true),
      'old_str': ToolParamSchema(type: 'string', required: true),
      'new_str': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'diff_text',
    description: 'Compara dois textos e retorna as diferenças.',
    inputSchema: {
      'text_before': ToolParamSchema(type: 'string', required: true),
      'text_after': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'extract_urls_from_text',
    description: 'Extrai todas as URLs encontradas em um texto.',
    inputSchema: {
      'text': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'count_tokens_estimate',
    description: 'Estima a quantidade de tokens de um texto.',
    inputSchema: {
      'text': ToolParamSchema(type: 'string', required: true),
    },
  ),
  ToolDefinition(
    name: 'text_summary_stats',
    description: 'Gera estatísticas de um texto (palavras, caracteres, parágrafos).',
    inputSchema: {
      'text': ToolParamSchema(type: 'string', required: true),
    },
  ),
  
  //Get current datetime
  
  ToolDefinition(
    name: 'get_current_datetime',
    description:
        'Retorna a data e hora ATUAIS do dispositivo (não confiar em '
        'conhecimento de treino para "que dia é hoje" — sempre chamar '
        'esta tool quando a data/hora corrente for relevante).',
    inputSchema: {
      'timezone_offset_hours': ToolParamSchema(
        type: 'number',
        description: 'Opcional. Se omitido, usa o timezone local do dispositivo.',
      ),
    },
  ),
  ToolDefinition(
    name: 'run_shell_command',
    description:
        'Executa um comando básico de sistema pré-aprovado (allowlist '
        'fixa: list_files, current_directory, disk_usage, device_uptime, '
        'echo). Não é um shell livre — apenas consultas leves e seguras.',
    inputSchema: {
      'command': ToolParamSchema(
        type: 'string',
        description: 'Um de: list_files, current_directory, disk_usage, device_uptime, echo.',
        required: true,
      ),
      'arg': ToolParamSchema(
        type: 'string',
        description: 'Usado apenas pelo comando "echo".',
      ),
    },
  ),
];