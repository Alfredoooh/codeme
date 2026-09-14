=====================================================================
lib/tools/shell/shell_tool.dart
=====================================================================

// run_shell_command
//
// Tool nova — permite à IA rodar comandos básicos de sistema que não
// têm tool dedicada, restrita a uma allowlist fixa de comandos leves
// e seguros. NÃO é um shell irrestrito: comandos fora da allowlist
// são recusados antes mesmo de tentar executar, e há timeout curto
// para nunca travar a fila por um processo pendurado.
//
// Comandos permitidos são propositalmente básicos e de baixo custo
// de RAM/CPU (consulta de informação, não processamento pesado).

import 'dart:async';
import 'dart:io';

import '../shared/tool_result.dart';
import '../shared/tool_exceptions.dart';

class ShellTool {
  // Allowlist fixa — cada entrada é o nome do "comando lógico" que a
  // IA pode pedir, mapeado para o binário/args reais no dispositivo.
  // Isso evita que a IA monte comandos arbitrários livremente.
  static final Map<String, List<String>> _allowedCommands = {
    'list_files': ['ls', '-la'],
    'current_directory': ['pwd'],
    'disk_usage': ['df', '-h'],
    'device_uptime': ['uptime'],
    'echo': ['echo'], // aceita argumento extra controlado (ver abaixo)
  };

  static const int _timeoutMs = 5000;

  /// run_shell_command
  /// input: { command: String — deve ser uma das chaves de _allowedCommands,
  ///           arg?: String — usado apenas por comandos que aceitam 1 argumento
  ///           simples (ex: "echo"), nunca concatenado livremente em shell. }
  static Future<ToolResult> run(Map<String, dynamic> input) async {
    final String? logicalCommand = input['command'] as String?;
    final String? arg = input['arg'] as String?;

    if (logicalCommand == null || !_allowedCommands.containsKey(logicalCommand)) {
      return ToolResult.error(
        'Comando não permitido. Comandos disponíveis: ${_allowedCommands.keys.join(', ')}',
        code: 'NOT_ALLOWED',
      );
    }

    try {
      final baseArgs = List<String>.from(_allowedCommands[logicalCommand]!);
      final executable = baseArgs.first;
      final args = baseArgs.skip(1).toList();

      // Apenas "echo" aceita argumento livre, e mesmo assim passado
      // como argumento de processo isolado (Process.run NÃO usa
      // shell de interpretação — sem risco de injeção via ; && | etc,
      // pois não há shell interpretando a string).
      if (logicalCommand == 'echo' && arg != null) {
        args.add(arg);
      }

      final result = await Process.run(executable, args)
          .timeout(const Duration(milliseconds: _timeoutMs));

      return ToolResult.ok({
        'stdout': result.stdout.toString(),
        'stderr': result.stderr.toString(),
        'exit_code': result.exitCode,
      });
    } on TimeoutException {
      return ToolResult.error('Comando excedeu o tempo limite.', code: 'TIMEOUT');
    } on ToolNotAllowedException catch (e) {
      return ToolResult.error(e.message, code: e.code);
    } catch (e) {
      return ToolResult.error('Erro ao executar comando: $e', code: 'EXEC_ERROR');
    }
  }
}