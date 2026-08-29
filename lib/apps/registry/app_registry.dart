// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/registry/app_registry.dart
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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

class AppAiTrigger {
  final RegExp pattern;
  final void Function(BuildContext context, String argument) onMatch;

  const AppAiTrigger({
    required this.pattern,
    required this.onMatch,
  });
}

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

  static Future<void> loadManifests() async {
    if (_manifestsLoaded) return;

    try {
      final manifestJsonRaw = await rootBundle.loadString('AssetManifest.json');
      final manifestJson = json.decode(manifestJsonRaw) as Map<String, dynamic>;
      final allAssetPaths = manifestJson.keys.toList();

      final manifestPaths = allAssetPaths.where(
        (p) => p.startsWith('assets/apps/') && p.endsWith('/manifest.json'),
      );

      for (final path in manifestPaths) {
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
    } catch (e) {
      debugPrint('AppRegistry: falha ao ler AssetManifest.json: $e');
    } finally {
      _manifestsLoaded = true;
    }
  }

  static void register(
    String slug,
    WidgetBuilder builder, {
    List<AppAiTrigger> triggers = const [],
  }) {
    _builders[slug] = builder;
    _triggers[slug] = triggers;
  }

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

  static String instructionsForEnabled(Set<String> enabledSlugs) {
    final buffer = StringBuffer();
    for (final entry in all) {
      if (!enabledSlugs.contains(entry.manifest.slug)) continue;
      if (entry.mcp.aiInstructions.isEmpty) continue;
      buffer.write(entry.mcp.aiInstructions);
    }
    return buffer.toString();
  }

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

class EnabledAppsController extends ChangeNotifier {
  final Map<String, bool> _enabled = {};

  bool isEnabled(String slug) => _enabled[slug] ?? false;

  Map<String, bool> get all => Map.unmodifiable(_enabled);

  void setEnabled(String slug, bool value) {
    if (_enabled[slug] == value) return;
    _enabled[slug] = value;
    notifyListeners();
  }

  void setDefaultIfAbsent(String slug, bool defaultValue) {
    if (_enabled.containsKey(slug)) return;
    _enabled[slug] = defaultValue;
  }
}

final EnabledAppsController enabledAppsController = EnabledAppsController();