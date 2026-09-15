import 'dart:async';

class ToolsQueue {
  ToolsQueue._();
  static final ToolsQueue instance = ToolsQueue._();

  Future<void> _tail = Future.value();

  /// Encadeia [task] na fila. A task só começa a executar quando
  /// todas as tasks enfileiradas antes dela já tiverem terminado
  /// (com sucesso ou erro).
  Future<T> enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();

    _tail = _tail.then((_) async {
      try {
        final result = await task();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}