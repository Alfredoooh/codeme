// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/app_shortcuts.dart
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller responsável por manter e persistir a lista de slugs
/// de apps escolhidos pelo utilizador como "atalhos" no drawer.
/// A ordem da lista é a ordem de exibição na secção de atalhos.
class AppShortcutsController extends ChangeNotifier {
  static const String _prefsKey = 'app_shortcuts_slugs_v1';

  List<String> _slugs = [];
  bool _loaded = false;

  List<String> get slugs => List.unmodifiable(_slugs);
  bool get loaded => _loaded;

  bool contains(String slug) => _slugs.contains(slug);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          _slugs = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {
      // Se a leitura falhar, seguimos com lista vazia em vez de rebentar.
      _slugs = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(_slugs));
    } catch (_) {
      // Falha silenciosa de persistência não deve derrubar a UI.
    }
  }

  /// Adiciona um conjunto de slugs aos atalhos existentes, sem
  /// duplicar e preservando a ordem relativa dos já existentes.
  Future<void> addAll(Iterable<String> newSlugs) async {
    var changed = false;
    for (final slug in newSlugs) {
      if (!_slugs.contains(slug)) {
        _slugs.add(slug);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  /// Substitui a lista de atalhos inteira pelo conjunto dado, na
  /// ordem fornecida. Usado pelo ecrã de seleção, que trata a
  /// seleção final como o estado completo dos atalhos (permite
  /// adicionar e remover na mesma operação).
  Future<void> replaceAll(Iterable<String> newSlugs) async {
    final next = newSlugs.toList();
    if (next.length == _slugs.length &&
        next.every((slug) => _slugs.contains(slug))) {
      return;
    }
    _slugs = next;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String slug) async {
    if (!_slugs.remove(slug)) return;
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    if (_slugs.isEmpty) return;
    _slugs = [];
    notifyListeners();
    await _persist();
  }
}

final AppShortcutsController appShortcutsController = AppShortcutsController();