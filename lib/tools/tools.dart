=====================================================================
lib/tools/tools.dart  (ATUALIZADO — inclui datetime e shell)
=====================================================================

library nexa_tools;

export 'tool_registry.dart';
export 'tool_definitions.dart';

export 'shared/tool_result.dart';
export 'shared/tool_exceptions.dart';
export 'shared/fonts.dart';

export 'documents/pdf_tools.dart';
export 'documents/pdf_merge_split_tools.dart';
export 'documents/pdf_reader_tool.dart';
export 'documents/docx_tools.dart';
export 'documents/pptx_tools.dart';
export 'documents/xlsx_tools.dart';

export 'images/qrcode_tool.dart';
export 'images/barcode_tool.dart';
export 'images/image_format_tool.dart';
export 'images/image_resize_crop_tools.dart';
export 'images/image_watermark_tool.dart';
export 'images/ocr_tool.dart';
export 'images/table_image_tool.dart';
export 'images/html_to_image_tool.dart';

export 'charts/chart_tool.dart';
export 'charts/function_plot_tool.dart';
export 'charts/math_sheet_tool.dart';

export 'mindmap/mindmap_tool.dart';

export 'files/file_creation_tool.dart';
export 'files/zip_reader_tool.dart';

export 'text/str_replace_tool.dart';
export 'text/diff_text_tool.dart';
export 'text/url_extractor_tool.dart';
export 'text/token_estimate_tool.dart';
export 'text/text_stats_tool.dart';

export 'datetime/datetime_tool.dart';
export 'shell/shell_tool.dart';

export 'server/local_tools_server.dart';
export 'server/tools_queue.dart';