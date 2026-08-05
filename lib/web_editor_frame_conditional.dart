// lib/web_editor_frame_conditional.dart
// Import condicional — o compilador escolhe o ficheiro certo por plataforma.
export 'web_editor_frame_stub.dart'
    if (dart.library.html) 'web_editor_frame.dart';