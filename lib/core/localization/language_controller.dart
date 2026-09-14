// ══════════════════════════════════════════════════════════════
// FILE: lib/core/language/language_controller.dart
// Controlador global de idioma. Junta todos os AppLocale
// disponíveis (um por ficheiro language_xx_yy.dart), guarda a
// escolha do utilizador em disco, e expõe `.strings` — o
// dicionário do idioma ativo — para qualquer ecrã consultar sem
// saber nada sobre como a tradução está organizada.
//
// Uso em qualquer tela:
//   final t = appLanguage.strings;
//   Text(t.settingsTitle)
//
// Ecrãs que reagem a troca de idioma em runtime devem ouvir este
// controller (ChangeNotifier) tal como já ouvem appTheme.
//
// IMPORTANTE: nenhum ficheiro language_xx_yy.dart concreto é
// escrito à mão aqui — todos os 25 são gerados externamente a
// partir do prompt de geração de idiomas, seguindo exatamente a
// estrutura de language_model.dart. Este ficheiro só os importa e
// regista na lista kAllLocales.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language_model.dart';
import 'language_pt_pt.dart';
import 'language_pt_br.dart';
import 'language_en_us.dart';
import 'language_en_gb.dart';
import 'language_es_es.dart';
import 'language_es_mx.dart';
import 'language_fr_fr.dart';
import 'language_de_de.dart';
import 'language_it_it.dart';
import 'language_nl_nl.dart';
import 'language_pl_pl.dart';
import 'language_sv_se.dart';
import 'language_ru_ru.dart';
import 'language_uk_ua.dart';
import 'language_ja_jp.dart';
import 'language_ko_kr.dart';
import 'language_zh_cn.dart';
import 'language_zh_tw.dart';
import 'language_ar_sa.dart';
import 'language_he_il.dart';
import 'language_hi_in.dart';
import 'language_tr_tr.dart';
import 'language_vi_vn.dart';
import 'language_th_th.dart';
import 'language_id_id.dart';
import 'language_sw_ke.dart';

/// Todos os idiomas disponíveis no app, na ordem em que aparecem
/// no seletor. Adicionar um idioma novo = criar o ficheiro
/// language_xx_yy.dart e acrescentar uma linha aqui.
final List<AppLocale> kAllLocales = [
  kLocalePtPt,
  kLocalePtBr,
  kLocaleEnUs,
  kLocaleEnGb,
  kLocaleEsEs,
  kLocaleEsMx,
  kLocaleFrFr,
  kLocaleDeDe,
  kLocaleItIt,
  kLocaleNlNl,
  kLocalePlPl,
  kLocaleSvSe,
  kLocaleRuRu,
  kLocaleUkUa,
  kLocaleJaJp,
  kLocaleKoKr,
  kLocaleZhCn,
  kLocaleZhTw,
  kLocaleArSa,
  kLocaleHeIl,
  kLocaleHiIn,
  kLocaleTrTr,
  kLocaleViVn,
  kLocaleThTh,
  kLocaleIdId,
  kLocaleSwKe,
];

class AppLanguageController extends ChangeNotifier {
  static const _kPrefKey = 'nexa_app_language_code';

  AppLocale _current = kLocalePtPt;
  bool _loaded = false;

  AppLanguageController() {
    _restore();
  }

  /// O locale ativo (idioma + o seu dicionário de strings).
  AppLocale get current => _current;

  /// Atalho direto para o dicionário de strings do idioma ativo —
  /// é isto que qualquer ecrã vai usar no dia a dia.
  AppStrings get strings => _current.strings;

  AppLanguage get language => _current.language;

  bool get loaded => _loaded;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_kPrefKey);
      if (savedCode != null) {
        final match = kAllLocales.where((l) => l.language.code == savedCode);
        if (match.isNotEmpty) {
          _current = match.first;
        }
      }
    } catch (_) {
      // Falha a ler prefs: mantém o default (pt-PT) em silêncio.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Troca o idioma ativo e persiste a escolha em disco.
  Future<void> setLanguage(AppLocale locale) async {
    if (_current.language.code == locale.language.code) return;
    _current = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, locale.language.code);
    } catch (_) {
      // Falha a persistir: a troca em memória já aconteceu,
      // simplesmente não sobrevive a um reinício da app.
    }
  }

  /// Filtra idiomas por texto de pesquisa (nome nativo, nome em
  /// inglês, ou código), usado pelo seletor de idioma.
  List<AppLocale> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return kAllLocales;
    return kAllLocales.where((l) {
      final lang = l.language;
      return lang.nativeName.toLowerCase().contains(q) ||
          lang.englishName.toLowerCase().contains(q) ||
          lang.code.toLowerCase().contains(q);
    }).toList();
  }
}

/// Instância global — o mesmo padrão de appTheme/authController já
/// usado no resto do app.
final AppLanguageController appLanguage = AppLanguageController();