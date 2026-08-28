// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/registry/app_registry.dart
// ══════════════════════════════════════════════════════════════
//
// Registo central e genérico de apps. Nenhum nome de app (docs,
// sheets, slides, sound, ou qualquer futuro) aparece neste ficheiro.
// Cada app regista-se a si próprio chamando AppRegistry.register(...)
// a partir do seu próprio bootstrap(), invocado uma vez a partir de
// main.dart. Cada app também é responsável por passar os seus
// próprios triggers de IA (se tiver) dentro dessa mesma chamada —
// main.dart nunca sabe nomes de apps específicos.
//
// Fluxo:
//   1. main.dart chama <App>Screen.bootstrap() para cada app — essa
//      função interna do próprio app chama
//      AppRegistry.register(slug, builder, triggers: [...]).
//   2. main.dart chama AppRegistry.loadManifests(), que lê
//      AssetManifest.json à procura de todos os
//      assets/apps/*/manifest.json existentes e o .mcp.json irmão.
//   3. all / bySlug ficam disponíveis para o resto da app.
//
// Um app só aparece em `all` quando TEM manifest carregado E TEM
// builder registado. Ter só um dos dois não é suficiente — evita
// mostrar uma entrada sem ecrã real, ou tentar abrir um ecrã sem
// metadados de apresentação.
//
// enabledAppsController: estado global de "quais apps a IA pode
// usar", partilhado entre o sheet de opções da IA (dentro do chat)
// e o switch dentro do AppDetailScreen de cada app — os dois lêem e
// escrevem o mesmo controller, para que ativar/desativar num sítio
// se reflita imediatamente no outro. Segue o mesmo padrão do
// editTabController já existente em app_types.dart: um
// ChangeNotifier global, sem contexto, sem import circular.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Metadados de apresentação de um app — o equivalente ao que antes
/// vivia hard-coded nos mapas da extension AppKindX.
class AppManifest {
  final String slug;
  final String label;
  final String description;
  final String longDescription;
  final List<String> features;
  final String iconAsset;
  final bool isCircularIcon;
  final String aiName;
  final String aiToggleDescription;
  final String version;

  const AppManifest({
    required this.slug,
    required this.label,
    required this.description,
    required this.longDescription,
    required this.features,
    required this.iconAsset,
    required this.isCircularIcon,
    required this.aiName,
    required this.aiToggleDescription,
    required this.version,
  });

  factory AppManifest.fromJson(String slug, Map<String, dynamic> json) {
    return AppManifest(
      slug: slug,
      label: json['label'] as String? ?? slug,
      description: json['description'] as String? ?? '',
      longDescription: json['longDescription'] as String? ?? '',
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      iconAsset: json['iconAsset'] as String? ??
          'assets/apps/$slug/icon.png',
      isCircularIcon: json['isCircularIcon'] as bool? ?? false,
      aiName: json['aiName'] as String? ?? json['label'] as String? ?? slug,
      aiToggleDescription: json['aiToggleDescription'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
    );
  }
}

/// Um comando/trigger que a IA pode invocar em texto livre, e que o
/// registry deteta e despacha para o handler correto. Substitui o
/// parsing hard-coded que antes vivia em funções como
/// _checkSoundSearch dentro de aitab.dart.
///
/// [pattern] deve ter exatamente um grupo de captura — o "argumento"
/// do comando (ex.: o termo de pesquisa dentro de
/// [[sound_search:termo]]). Se o app não precisar de argumento,
/// usa-se um grupo vazio, ex.: r'\[\[algo\]\]()'.
class AppAiTrigger {
  final RegExp pattern;
  final void Function(BuildContext context, String argument) onMatch;

  const AppAiTrigger({
    required this.pattern,
    required this.onMatch,
  });
}

/// Configuração MCP de um app: as instruções que são injetadas no
/// system prompt da IA quando o app está ativo. Os triggers NÃO vêm
/// do JSON (não podem — precisam de uma função Dart real) — chegam
/// via register(), vindos do próprio bootstrap() do app.
class AppMcpConfig {
  final String aiInstructions;

  const AppMcpConfig({
    required this.aiInstructions,
  });

  factory AppMcpConfig.fromJson(Map<String, dynamic> json) {
    return AppMcpConfig(
      aiInstructions: json['aiInstructions'] as String? ?? '',
    );
  }
}

/// Entrada completa de um app no registry: metadados + config de IA +
/// construtor do ecrã real + triggers de IA (se tiver).
class AppEntry {
  final AppManifest manifest;
  final AppMcpConfig mcp;
  final WidgetBuilder builder;
  final List<AppAiTrigger> triggers;

  const AppEntry({
    required this.manifest,
    required this.mcp,
    required this.builder,
    this.triggers = const [],
  });
}

class AppRegistry {
  AppRegistry._();

  static final Map<String, AppManifest> _manifests = {};
  static final Map<String, AppMcpConfig> _mcpConfigs = {};
  static final Map<String, WidgetBuilder> _builders = {};
  static final Map<String, List<AppAiTrigger>> _triggers = {};

  static bool _manifestsLoaded = false;

  /// Lê AssetManifest.json à procura de todos os
  /// assets/apps/<slug>/manifest.json existentes, carregando também
  /// o <slug>.mcp.json irmão de cada um.
  ///
  /// Deve ser chamado DEPOIS de todos os <App>Screen.bootstrap()
  /// terem corrido, para que builders/triggers já estejam
  /// registados quando os manifests ficarem disponíveis.
  ///
  /// Idempotente: chamar mais que uma vez não duplica trabalho.
  static Future<void> loadManifests() async {
    if (_manifestsLoaded) return;

    final manifestJsonRaw = await rootBundle.loadString('AssetManifest.json');
    final manifestJson = json.decode(manifestJsonRaw) as Map<String, dynamic>;
    final allAssetPaths = manifestJson.keys.toList();

    final manifestPaths = allAssetPaths.where(
      (p) => p.startsWith('assets/apps/') && p.endsWith('/manifest.json'),
    );

    for (final path in manifestPaths) {
      // assets/apps/<slug>/manifest.json  →  <slug>
      final parts = path.split('/');
      if (parts.length < 4) continue;
      final slug = parts[2];

      try {
        final manifestRaw = await rootBundle.loadString(path);
        final manifestData = json.decode(manifestRaw) as Map<String, dynamic>;
        final manifest = AppManifest.fromJson(slug, manifestData);
        _manifests[slug] = manifest;

        final mcpPath = 'assets/apps/$slug/$slug.mcp.json';
        if (allAssetPaths.contains(mcpPath)) {
          final mcpRaw = await rootBundle.loadString(mcpPath);
          final mcpData = json.decode(mcpRaw) as Map<String, dynamic>;
          _mcpConfigs[slug] = AppMcpConfig.fromJson(mcpData);
        } else {
          _mcpConfigs[slug] = const AppMcpConfig(aiInstructions: '');
        }
      } catch (e) {
        debugPrint('AppRegistry: falha ao carregar manifest de "$slug": $e');
      }
    }

    _manifestsLoaded = true;
  }

  /// Chamado pelo próprio app (dentro do seu bootstrap(), invocado a
  /// partir de main.dart) para ligar o [slug] ao Widget real do seu
  /// ecrã principal, e opcionalmente aos seus triggers de IA.
  /// main.dart nunca vê [triggers] nem sabe o que cada app faz — só
  /// chama bootstrap().
  static void register(
    String slug,
    WidgetBuilder builder, {
    List<AppAiTrigger> triggers = const [],
  }) {
    _builders[slug] = builder;
    _triggers[slug] = triggers;
  }

  /// Todas as entradas com manifest E builder disponíveis, na ordem
  /// em que os manifests foram encontrados.
  static List<AppEntry> get all {
    final entries = <AppEntry>[];
    for (final slug in _manifests.keys) {
      final builder = _builders[slug];
      final mcp = _mcpConfigs[slug];
      if (builder == null || mcp == null) continue;
      entries.add(AppEntry(
        manifest: _manifests[slug]!,
        mcp: mcp,
        builder: builder,
        triggers: _triggers[slug] ?? const [],
      ));
    }
    return entries;
  }

  static AppEntry? bySlug(String slug) {
    final manifest = _manifests[slug];
    final builder = _builders[slug];
    final mcp = _mcpConfigs[slug];
    if (manifest == null || builder == null || mcp == null) return null;
    return AppEntry(
      manifest: manifest,
      mcp: mcp,
      builder: builder,
      triggers: _triggers[slug] ?? const [],
    );
  }

  /// Concatena as aiInstructions de todos os apps ativos em
  /// [enabledSlugs]. Usado por _effectiveSystemPrompt em vez dos 4
  /// `if` hard-coded que existiam antes.
  static String instructionsForEnabled(Set<String> enabledSlugs) {
    final buffer = StringBuffer();
    for (final entry in all) {
      if (!enabledSlugs.contains(entry.manifest.slug)) continue;
      if (entry.mcp.aiInstructions.isEmpty) continue;
      buffer.write(entry.mcp.aiInstructions);
    }
    return buffer.toString();
  }

  /// Corre todos os triggers de todos os apps ATIVOS contra [text] e
  /// despacha os handlers correspondentes. Substitui funções
  /// hard-coded como o antigo _checkSoundSearch. Só apps em
  /// [enabledSlugs] têm os seus triggers avaliados — um app
  /// desativado não deve reagir a texto que a IA gerou sem essa
  /// instrução ter sido sequer injetada no prompt.
  static void checkAiTriggers(
    BuildContext context,
    String text,
    Set<String> enabledSlugs,
  ) {
    for (final entry in all) {
      if (!enabledSlugs.contains(entry.manifest.slug)) continue;
      for (final trigger in entry.triggers) {
        final match = trigger.pattern.firstMatch(text);
        if (match == null) continue;
        final argument = match.groupCount >= 1 ? (match.group(1)?.trim() ?? '') : '';
        trigger.onMatch(context, argument);
      }
    }
  }
}

/// Estado global de "quais apps a IA pode usar" — partilhado entre o
/// sheet de opções da IA (dentro do chat, aitab.dart) e o switch
/// dentro do AppDetailScreen de cada app. Os dois lêem e escrevem o
/// mesmo controller: ativar num sítio reflete-se imediatamente no
/// outro. Mesmo padrão do editTabController já existente.
class EnabledAppsController extends ChangeNotifier {
  final Map<String, bool> _enabled = {};

  bool isEnabled(String slug) => _enabled[slug] ?? false;

  Map<String, bool> get all => Map.unmodifiable(_enabled);

  void setEnabled(String slug, bool value) {
    if (_enabled[slug] == value) return;
    _enabled[slug] = value;
    notifyListeners();
  }

  /// Define os valores default na primeira utilização (ex.: docs,
  /// sheets, slides = true; sound = false, tal como os defaults
  /// originais em AiTabState). Não sobrescreve slugs já definidos.
  void setDefaultIfAbsent(String slug, bool defaultValue) {
    if (_enabled.containsKey(slug)) return;
    _enabled[slug] = defaultValue;
  }
}

final EnabledAppsController enabledAppsController = EnabledAppsController();