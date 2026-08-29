// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/registry/app_builder_registry.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:nexa/apps/docs.dart';
import 'package:nexa/apps/sheets_app.dart';
import 'package:nexa/apps/slides_app.dart';
import 'package:nexa/apps/sound.dart';
import 'package:nexa/apps/sound/sound_models.dart';
import 'package:nexa/apps/sound/sound_widgets.dart';
import 'app_registry.dart';

class AppBuilderRegistry {
  /// Devolve o construtor do ecrã para o slug indicado.
  /// Este é o único ponto do código onde os caminhos dos ecrãs são mapeados.
  static WidgetBuilder? get(String slug) {
    switch (slug) {
      case 'docs':
        return (_) => const DocsScreen();
      case 'sheets':
        return (_) => const SheetsScreen();
      case 'slides':
        return (_) => const SlidesScreen();
      case 'sound':
        return (_) => const SoundScreen();
      default:
        return null;
    }
  }

  /// Triggers de IA para apps que precisem deles.
  /// Opcional, apenas se o app tiver um comando especial (ex.: sound_search).
  static Map<String, List<AppAiTrigger>> get triggers {
    return {
      'sound': [
        AppAiTrigger(
          pattern: RegExp(r'\[\[sound_search:(.*?)\]\]'),
          onMatch: (context, query) {
            if (query.isEmpty) return;
            soundTabController.requestSearch(query);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SoundScreen()),
            );
          },
        ),
      ],
    };
  }
}