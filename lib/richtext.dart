// ══════════════════════════════════════════════════════════════
// FILE: lib/richtext.dart
//
// _AiTable deixou de ser privada: agora é a ÚNICA implementação de
// tabela usada em toda a app — tanto para tabelas markdown normais
// (| col | col |) como para blocos ```widget_table``` vindos da IA.
// buildAiTableFromWidgetJson() é o adaptador que aiwidgets.dart usa
// para construir _AiTable a partir do JSON {headers, rows}.
//
// Tabela: colunas usam IntrinsicColumnWidth() e vivem dentro de um
// SingleChildScrollView horizontal — a tabela cresce ao tamanho real
// do conteúdo e desliza lateralmente quando ultrapassa a largura do
// ecrã, em vez de forçar o texto a partir/juntar-se (bug anterior
// causado por FlexColumnWidth()).
//
// Admonitions (> [!NOTE] título / [!TIP] / [!IMPORTANT] / [!WARNING]
// / [!CAUTION]): bloco de nota/aviso ao estilo GitHub, com barra
// lateral colorida por tipo, ícone e título a negrito. Fundo depende
// do tema (nunca fixo), bordas retas (raio pequeno, nunca 100%
// arredondadas). A cor da barra lateral/ícone é categorização
// estrutural do próprio bloco — não é "texto colorido"; o texto e os
// links continuam sempre neutros (cinza), sem exceção.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'colors.dart';
import 'aiwidgets.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// SÍMBOLOS MATEMÁTICOS — tabelas de tradução LaTeX → unicode
// ══════════════════════════════════════════════════════════════

const Map<String, String> kGreekLetters = {
  r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
  r'\epsilon': 'ε', r'\varepsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η',
  r'\theta': 'θ', r'\vartheta': 'ϑ', r'\iota': 'ι', r'\kappa': 'κ',
  r'\lambda': 'λ', r'\mu': 'μ', r'\nu': 'ν', r'\xi': 'ξ',
  r'\omicron': 'ο', r'\pi': 'π', r'\varpi': 'ϖ', r'\rho': 'ρ',
  r'\varrho': 'ϱ', r'\sigma': 'σ', r'\varsigma': 'ς', r'\tau': 'τ',
  r'\upsilon': 'υ', r'\phi': 'φ', r'\varphi': 'φ', r'\chi': 'χ',
  r'\psi': 'ψ', r'\omega': 'ω',
  r'\Alpha': 'Α', r'\Beta': 'Β', r'\Gamma': 'Γ', r'\Delta': 'Δ',
  r'\Epsilon': 'Ε', r'\Zeta': 'Ζ', r'\Eta': 'Η', r'\Theta': 'Θ',
  r'\Iota': 'Ι', r'\Kappa': 'Κ', r'\Lambda': 'Λ', r'\Mu': 'Μ',
  r'\Nu': 'Ν', r'\Xi': 'Ξ', r'\Omicron': 'Ο', r'\Pi': 'Π',
  r'\Rho': 'Ρ', r'\Sigma': 'Σ', r'\Tau': 'Τ', r'\Upsilon': 'Υ',
  r'\Phi': 'Φ', r'\Chi': 'Χ', r'\Psi': 'Ψ', r'\Omega': 'Ω',
};

const Map<String, String> kMathSymbols = {
  r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\cdot': '·', r'\ast': '∗', r'\star': '⋆',
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\sim': '∼', r'\simeq': '≃', r'\cong': '≅', r'\propto': '∝',
  r'\ll': '≪', r'\gg': '≫',
  r'\rightarrow': '→', r'\to': '→', r'\leftarrow': '←',
  r'\leftrightarrow': '↔', r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
  r'\Leftrightarrow': '⇔', r'\mapsto': '↦', r'\uparrow': '↑',
  r'\downarrow': '↓', r'\nearrow': '↗', r'\searrow': '↘',
  r'\in': '∈', r'\notin': '∉', r'\ni': '∋', r'\subset': '⊂',
  r'\subseteq': '⊆', r'\supset': '⊃', r'\supseteq': '⊇',
  r'\cup': '∪', r'\cap': '∩', r'\setminus': '∖',
  r'\emptyset': '∅', r'\varnothing': '∅',
  r'\forall': '∀', r'\exists': '∃', r'\nexists': '∄',
  r'\neg': '¬', r'\lnot': '¬', r'\land': '∧', r'\wedge': '∧',
  r'\lor': '∨', r'\vee': '∨', r'\oplus': '⊕', r'\otimes': '⊗',
  r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇',
  r'\int': '∫', r'\iint': '∬', r'\iiint': '∭', r'\oint': '∮',
  r'\sum': '∑', r'\prod': '∏', r'\coprod': '∐',
  r'\lim': 'lim', r'\limsup': 'lim sup', r'\liminf': 'lim inf',
  r'\sqrt': '√',
  r'\mathbb{R}': 'ℝ', r'\mathbb{N}': 'ℕ', r'\mathbb{Z}': 'ℤ',
  r'\mathbb{Q}': 'ℚ', r'\mathbb{C}': 'ℂ',
  r'\ldots': '…', r'\cdots': '⋯', r'\vdots': '⋮', r'\ddots': '⋱',
  r'\angle': '∠', r'\perp': '⊥', r'\parallel': '∥',
  r'\degree': '°', r'\prime': '′',
  r'\implies': '⟹', r'\iff': '⟺',
  r'\hbar': 'ℏ', r'\ell': 'ℓ',
};

const Map<String, String> kSuperscriptDigits = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  'n': 'ⁿ', 'i': 'ⁱ',
};

const Map<String, String> kSubscriptDigits = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
  '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  'a': 'ₐ', 'e': 'ₑ', 'o': 'ₒ', 'x': 'ₓ',
};

String? _toSuperscriptUnicode(String s) {
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final mapped = kSuperscriptDigits[ch];
    if (mapped == null) return null;
    buf.write(mapped);
  }
  return buf.toString();
}

String? _toSubscriptUnicode(String s) {
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final mapped = kSubscriptDigits[ch];
    if (mapped == null) return null;
    buf.write(mapped);
  }
  return buf.toString();
}

// ══════════════════════════════════════════════════════════════
// EMOJI SHORTCODES
// ══════════════════════════════════════════════════════════════

const Map<String, String> kEmojiShortcodes = {
  ':smile:': '😄', ':grin:': '😁', ':joy:': '😂', ':wink:': '😉',
  ':blush:': '😊', ':heart:': '❤️', ':thumbsup:': '👍',
  ':thumbsdown:': '👎', ':fire:': '🔥', ':star:': '⭐',
  ':check:': '✅', ':x:': '❌', ':warning:': '⚠️',
  ':rocket:': '🚀', ':tada:': '🎉', ':eyes:': '👀',
  ':thinking:': '🤔', ':clap:': '👏', ':pray:': '🙏',
  ':100:': '💯', ':bulb:': '💡', ':lock:': '🔒', ':key:': '🔑',
  ':bell:': '🔔', ':gear:': '⚙️', ':wave:': '👋',
  ':point_right:': '👉', ':point_left:': '👈', ':muscle:': '💪',
  ':zap:': '⚡', ':sparkles:': '✨', ':package:': '📦',
  ':book:': '📖', ':memo:': '📝', ':chart:': '📊',
  ':calendar:': '📅', ':clock:': '🕐', ':mag:': '🔍',
  ':email:': '📧', ':phone:': '📱', ':computer:': '💻',
  ':link:': '🔗', ':pushpin:': '📌', ':white_check_mark:': '✅',
};

// ══════════════════════════════════════════════════════════════
// PARSER DE EXPRESSÕES MATEMÁTICAS (LaTeX-like)
// ══════════════════════════════════════════════════════════════

sealed class _MathAtom {}

class _MathText extends _MathAtom {
  final String text;
  final bool italic;
  _MathText(this.text, {this.italic = true});
}

class _MathFraction extends _MathAtom {
  final String numerator;
  final String denominator;
  _MathFraction(this.numerator, this.denominator);
}

class _MathSqrt extends _MathAtom {
  final String content;
  final String? index;
  _MathSqrt(this.content, {this.index});
}

String _substituteKnownTokens(String expr) {
  var result = expr;
  final allTokens = <String, String>{...kGreekLetters, ...kMathSymbols};
  final sortedKeys = allTokens.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final token in sortedKeys) {
    result = result.replaceAll(token, allTokens[token]!);
  }
  return result;
}

String _resolveSuperSubscripts(String expr) {
  var result = expr;

  result = result.replaceAllMapped(
    RegExp(r'\^\{([^{}]+)\}'),
    (m) {
      final sup = _toSuperscriptUnicode(m.group(1)!);
      return sup ?? '\u0001SUP{${m.group(1)}}\u0001';
    },
  );
  result = result.replaceAllMapped(
    RegExp(r'_\{([^{}]+)\}'),
    (m) {
      final sub = _toSubscriptUnicode(m.group(1)!);
      return sub ?? '\u0001SUB{${m.group(1)}}\u0001';
    },
  );

  result = result.replaceAllMapped(
    RegExp(r'\^([a-zA-Z0-9+\-=()])'),
    (m) {
      final sup = _toSuperscriptUnicode(m.group(1)!);
      return sup ?? '\u0001SUP{${m.group(1)}}\u0001';
    },
  );
  result = result.replaceAllMapped(
    RegExp(r'_([a-zA-Z0-9+\-=()])'),
    (m) {
      final sub = _toSubscriptUnicode(m.group(1)!);
      return sub ?? '\u0001SUB{${m.group(1)}}\u0001';
    },
  );

  return result;
}

List<_MathAtom> _parseMathExpression(String raw) {
  var expr = _substituteKnownTokens(raw);
  expr = _resolveSuperSubscripts(expr);

  final atoms = <_MathAtom>[];
  final combinedPattern = RegExp(
    r'\\frac\{([^{}]+)\}\{([^{}]+)\}|\\sqrt(\[([^\]]+)\])?\{([^{}]+)\}',
  );

  int last = 0;
  for (final m in combinedPattern.allMatches(expr)) {
    if (m.start > last) {
      atoms.add(_MathText(expr.substring(last, m.start)));
    }
    if (m.group(1) != null) {
      atoms.add(_MathFraction(m.group(1)!, m.group(2)!));
    } else {
      atoms.add(_MathSqrt(m.group(5)!, index: m.group(4)));
    }
    last = m.end;
  }
  if (last < expr.length) {
    atoms.add(_MathText(expr.substring(last)));
  }
  return atoms;
}

List<InlineSpan> _renderMathTextWithMarkers(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final markerPattern = RegExp(r'\u0001(SUP|SUB)\{([^}]*)\}\u0001');
  int last = 0;
  for (final m in markerPattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: baseStyle));
    }
    final isSup = m.group(1) == 'SUP';
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.top,
      baseline: TextBaseline.alphabetic,
      child: Transform.translate(
        offset: Offset(0, isSup ? -baseStyle.fontSize! * 0.35 : baseStyle.fontSize! * 0.15),
        child: Text(
          m.group(2)!,
          style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.68),
        ),
      ),
    ));
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: baseStyle));
  }
  return spans;
}

class MathInline extends StatelessWidget {
  final String expression;
  final AppColorScheme s;
  final bool block;
  const MathInline({
    super.key,
    required this.expression,
    required this.s,
    this.block = false,
  });

  @override
  Widget build(BuildContext context) {
    final atoms = _parseMathExpression(expression);
    final baseFontSize = block ? 17.0 : 14.5;
    final baseStyle = TextStyle(
      color: s.onSurface,
      fontSize: baseFontSize,
      fontStyle: FontStyle.italic,
      height: 1.3,
    );

    final rowChildren = <Widget>[];
    for (final atom in atoms) {
      switch (atom) {
        case _MathText(:final text):
          if (text.isEmpty) continue;
          rowChildren.add(RichText(
            text: TextSpan(children: _renderMathTextWithMarkers(text, baseStyle)),
          ));
        case _MathFraction(:final numerator, :final denominator):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(numerator,
                    style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
                Container(
                  height: 1.2,
                  width: _estimateFracWidth(numerator, denominator, baseFontSize),
                  color: s.onSurface,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                ),
                Text(denominator,
                    style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
              ],
            ),
          ));
        case _MathSqrt(:final content, :final index):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index != null)
                  Transform.translate(
                    offset: const Offset(2, 4),
                    child: Text(index,
                        style: baseStyle.copyWith(fontSize: baseFontSize * 0.55)),
                  ),
                Text('√', style: baseStyle.copyWith(fontSize: baseFontSize * 1.05)),
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.only(top: 1, left: 1, right: 2),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: s.onSurface, width: 1)),
                  ),
                  child: Text(content, style: baseStyle),
                ),
              ],
            ),
          ));
      }
    }

    final content = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: rowChildren,
    );

    if (!block) return content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: s.hover,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(child: content),
      ),
    );
  }

  double _estimateFracWidth(String num, String den, double fontSize) {
    final longer = num.length > den.length ? num.length : den.length;
    return (longer * fontSize * 0.56).clamp(fontSize * 0.9, fontSize * 6);
  }
}

// ══════════════════════════════════════════════════════════════
// EXTRAÇÃO DE BLOCOS DE MATEMÁTICA ($$...$$) DO TEXTO CORRIDO
// ══════════════════════════════════════════════════════════════

class MathBlockParseResult {
  final String textWithMarkers;
  final List<String> blocks;
  const MathBlockParseResult({required this.textWithMarkers, required this.blocks});
}

MathBlockParseResult _extractMathBlocks(String raw) {
  final blocks = <String>[];
  final pattern = RegExp(r'\$\$([\s\S]+?)\$\$');
  int i = 0;
  final text = raw.replaceAllMapped(pattern, (m) {
    blocks.add(m.group(1)!.trim());
    return '\u0000MB${i++}\u0000';
  });
  return MathBlockParseResult(textWithMarkers: text, blocks: blocks);
}

// ══════════════════════════════════════════════════════════════
// ADMONITIONS — > [!NOTE] título / [!TIP] / [!IMPORTANT] /
// [!WARNING] / [!CAUTION], estilo GitHub. Extraídas do texto corrido
// antes do parser estrutural genérico de linhas '>', para que não
// caiam no tratamento normal de blockquote.
// ══════════════════════════════════════════════════════════════

enum _AdmonitionKind { note, tip, important, warning, caution }

class _AdmonitionData {
  final _AdmonitionKind kind;
  final String title;
  final String body;
  const _AdmonitionData({required this.kind, required this.title, required this.body});
}

_AdmonitionKind? _admonitionKindFromTag(String tag) {
  switch (tag.toUpperCase()) {
    case 'NOTE': return _AdmonitionKind.note;
    case 'TIP': return _AdmonitionKind.tip;
    case 'IMPORTANT': return _AdmonitionKind.important;
    case 'WARNING': return _AdmonitionKind.warning;
    case 'CAUTION': return _AdmonitionKind.caution;
    default: return null;
  }
}

({String icon, Color color, String defaultLabel}) _admonitionStyle(_AdmonitionKind kind) {
  switch (kind) {
    case _AdmonitionKind.note:
      return (icon: 'info.svg', color: const Color(0xFF3B82F6), defaultLabel: 'Nota');
    case _AdmonitionKind.tip:
      return (icon: 'bulb.svg', color: const Color(0xFF22C55E), defaultLabel: 'Dica');
    case _AdmonitionKind.important:
      return (icon: 'priority_high.svg', color: const Color(0xFF8B5CF6), defaultLabel: 'Importante');
    case _AdmonitionKind.warning:
      return (icon: 'warning.svg', color: const Color(0xFFF59E0B), defaultLabel: 'Aviso');
    case _AdmonitionKind.caution:
      return (icon: 'error_outline.svg', color: const Color(0xFFEF4444), defaultLabel: 'Cuidado');
  }
}

class _AdmonitionCard extends StatelessWidget {
  final _AdmonitionData data;
  final AppColorScheme s;
  const _AdmonitionCard({required this.data, required this.s});

  @override
  Widget build(BuildContext context) {
    final style = _admonitionStyle(data.kind);
    final bg = s.isDark ? s.hover : const Color(0xFFF2F2F2);
    final title = data.title.trim().isEmpty ? style.defaultLabel : data.title.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: style.color, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppIcon(style.icon, size: 16, color: style.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: s.onSurface)),
              ),
            ],
          ),
          if (data.body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText.rich(
              TextSpan(
                style: TextStyle(color: s.onSurface, fontSize: 14, height: 1.45),
                children: _RichTextBlockParser.inlineSpans(data.body.trim(), s, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RICH AI TEXT
// ══════════════════════════════════════════════════════════════

class RichAiText extends StatelessWidget {
  final String text;
  final AppColorScheme s;
  final bool widgetsEnabled;
  final VoidCallback? onEnableWidgets;
  final ValueChanged<String>? onSuggestionTap;
  const RichAiText({
    super.key,
    required this.text,
    required this.s,
    this.widgetsEnabled = true,
    this.onEnableWidgets,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!widgetsEnabled) {
      final widgetParse = parseAiWidgetBlocks(text);
      final strippedText = widgetParse.blocks.isEmpty
          ? text
          : widgetParse.textWithMarkers.replaceAll(
              RegExp(r'\u0000WB(\d+)\u0000'), '');

      final suggestionMessage = widgetParse.blocks.length == 1
          ? 'Mostra o widget desta resposta'
          : 'Mostra os ${widgetParse.blocks.length} widgets desta resposta';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._RichTextBlockParser.parse(strippedText, s),
          if (widgetParse.blocks.isNotEmpty) ...[
            const SizedBox(height: 6),
            _WidgetSuggestionPill(
              s: s,
              count: widgetParse.blocks.length,
              onTap: () {
                onEnableWidgets?.call();
                onSuggestionTap?.call(suggestionMessage);
              },
            ),
          ],
        ],
      );
    }

    final widgetParse = parseAiWidgetBlocks(text);
    if (widgetParse.blocks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _RichTextBlockParser.parse(text, s),
      );
    }

    final markerRe = RegExp(r'\u0000WB(\d+)\u0000');
    final children = <Widget>[];
    int last = 0;
    for (final m in markerRe.allMatches(widgetParse.textWithMarkers)) {
      if (m.start > last) {
        final segment = widgetParse.textWithMarkers.substring(last, m.start);
        if (segment.trim().isNotEmpty) children.addAll(_RichTextBlockParser.parse(segment, s));
      }
      final idx = int.parse(m.group(1)!);
      if (idx < widgetParse.blocks.length) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: buildAiWidget(widgetParse.blocks[idx], s),
        ));
      }
      last = m.end;
    }
    if (last < widgetParse.textWithMarkers.length) {
      final segment = widgetParse.textWithMarkers.substring(last);
      if (segment.trim().isNotEmpty) children.addAll(_RichTextBlockParser.parse(segment, s));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PARSER DE BLOCOS ESTRUTURAIS
// ══════════════════════════════════════════════════════════════

class _RichTextBlockParser {
  static List<Widget> parse(String raw, AppColorScheme s) {
    final mathExtract = _extractMathBlocks(raw);
    if (mathExtract.blocks.isEmpty) {
      return _parseStructural(raw, s);
    }

    final markerRe = RegExp(r'\u0000MB(\d+)\u0000');
    final widgets = <Widget>[];
    int last = 0;
    for (final m in markerRe.allMatches(mathExtract.textWithMarkers)) {
      if (m.start > last) {
        final segment = mathExtract.textWithMarkers.substring(last, m.start);
        if (segment.trim().isNotEmpty) widgets.addAll(_parseStructural(segment, s));
      }
      final idx = int.parse(m.group(1)!);
      if (idx < mathExtract.blocks.length) {
        widgets.add(MathInline(expression: mathExtract.blocks[idx], s: s, block: true));
      }
      last = m.end;
    }
    if (last < mathExtract.textWithMarkers.length) {
      final segment = mathExtract.textWithMarkers.substring(last);
      if (segment.trim().isNotEmpty) widgets.addAll(_parseStructural(segment, s));
    }
    return widgets;
  }

  static List<Widget> _parseStructural(String raw, AppColorScheme s) {
    final lines = raw.split('\n');
    final widgets = <Widget>[];
    int i = 0;
    List<List<String>>? tableRows;

    void flushTable() {
      if (tableRows != null && tableRows!.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _AiTable(rows: tableRows!, s: s),
        ));
      }
      tableRows = null;
    }

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        flushTable();
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, thickness: 1, color: s.outline.withOpacity(0.5)),
        ));
        i++;
        continue;
      }

      if (trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.contains('|', 1)) {
        final isSeparator = RegExp(r'^\|[\s\-:|]+\|$').hasMatch(trimmed);
        if (!isSeparator) {
          final cells = trimmed
              .substring(1, trimmed.length - 1)
              .split('|')
              .map((c) => c.trim())
              .toList();
          tableRows ??= [];
          tableRows!.add(cells);
        }
        i++;
        continue;
      } else if (tableRows != null) {
        flushTable();
      }

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        i++;
        continue;
      }

      final headerMatch = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(trimmed);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 4),
          child: _formattedText(
            content, s,
            fontSize: level == 1 ? 18 : level == 2 ? 16.5 : 15,
            fontWeight: FontWeight.w700,
          ),
        ));
        i++;
        continue;
      }

      // Admonition: "> [!TIPO] título" seguido, opcionalmente, de mais
      // linhas começadas por ">" que formam o corpo. Verificado ANTES
      // do blockquote genérico, para não cair no tratamento normal de
      // ">" simples.
      final admonitionHeaderMatch =
          RegExp(r'^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*(.*)$', caseSensitive: false)
              .firstMatch(trimmed);
      if (admonitionHeaderMatch != null) {
        final kind = _admonitionKindFromTag(admonitionHeaderMatch.group(1)!)!;
        final title = admonitionHeaderMatch.group(2)!.trim();
        final bodyLines = <String>[];
        i++;
        while (i < lines.length) {
          final nextTrimmed = lines[i].trim();
          if (!nextTrimmed.startsWith('>')) break;
          final content = nextTrimmed.replaceFirst(RegExp(r'^>\s?'), '');
          bodyLines.add(content);
          i++;
        }
        flushTable();
        widgets.add(_AdmonitionCard(
          data: _AdmonitionData(kind: kind, title: title, body: bodyLines.join('\n')),
          s: s,
        ));
        continue;
      }

      final quoteMatch = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
      if (quoteMatch != null) {
        flushTable();
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: s.outline, width: 3)),
          ),
          child: _formattedText(quoteMatch.group(1)!, s),
        ));
        i++;
        continue;
      }

      final indentMatch = RegExp(r'^(\s*)').firstMatch(line)!;
      final indentLevel = (indentMatch.group(1)!.length / 2).floor().clamp(0, 4);

      final checkMatch = RegExp(r'^([\-\*])\s+\[([ xX])\]\s+(.*)$').firstMatch(trimmed);
      if (checkMatch != null) {
        final done = checkMatch.group(2)!.toLowerCase() == 'x';
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4, left: indentLevel * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: AppIcon(
                  done ? 'check_box.svg' : 'check_box_outline_blank.svg',
                  size: 16,
                  color: done ? s.primary : s.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: _formattedText(
                  checkMatch.group(3)!, s,
                  fontWeight: done ? FontWeight.normal : null,
                ),
              ),
            ],
          ),
        ));
        i++;
        continue;
      }

      final bulletMatch = RegExp(r'^[\-\*]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4, left: indentLevel * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(color: s.onSurfaceVariant, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: _formattedText(bulletMatch.group(1)!, s)),
            ],
          ),
        ));
        i++;
        continue;
      }

      final numberedMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numberedMatch != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4, left: indentLevel * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text('${numberedMatch.group(1)}.',
                    style: TextStyle(
                        fontSize: 14.5, color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: _formattedText(numberedMatch.group(2)!, s)),
            ],
          ),
        ));
        i++;
        continue;
      }

      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++;
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: buildAiWidget(
            AiWidgetBlock(id: 'widget_code', json: {
              'language': lang.isEmpty ? 'text' : lang,
              'code': codeLines.join('\n'),
            }),
            s,
          ),
        ));
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _formattedText(trimmed, s),
      ));
      i++;
    }

    flushTable();
    return widgets;
  }

  static List<InlineSpan> inlineSpans(String raw, AppColorScheme s, {double fontSize = 14.5}) {
    // Cor de links/texto inline permanece SEMPRE neutra (cinza) —
    // nunca azul, nunca qualquer outra cor, independentemente do tema.
    final linkColor = s.isDark ? const Color(0xFFE0E0E0) : const Color(0xFF3A3A3A);

    var processed = raw;
    kEmojiShortcodes.forEach((code, emoji) {
      if (processed.contains(code)) {
        processed = processed.replaceAll(code, emoji);
      }
    });

    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\$[^$\n]+?\$)|(\*\*\*.+?\*\*\*)|(\*\*.+?\*\*)|(__.+?__)|(~~.+?~~)|(\*[^\*\n]+?\*)|(_[^_\n]+?_)|(`[^`\n]+?`)|(\[([^\]]+)\]\(([^)]+)\))',
    );
    int last = 0;
    for (final m in pattern.allMatches(processed)) {
      if (m.start > last) {
        spans.add(TextSpan(text: processed.substring(last, m.start)));
      }
      final token = m.group(0)!;

      if (token.startsWith(r'$')) {
        final expr = token.substring(1, token.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MathInline(expression: expr, s: s, block: false),
        ));
      } else if (token.startsWith('[')) {
        spans.add(TextSpan(
          text: m.group(10)!,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        ));
      } else if (token.startsWith('***')) {
        spans.add(TextSpan(
          text: token.substring(3, token.length - 3),
          style: const TextStyle(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
        ));
      } else if (token.startsWith('~~')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ));
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: s.hover,
            fontSize: fontSize - 1,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      last = m.end;
    }
    if (last < processed.length) spans.add(TextSpan(text: processed.substring(last)));
    return spans;
  }

  static Widget _formattedText(String raw, AppColorScheme s, {double fontSize = 14.5, FontWeight? fontWeight}) {
    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          color: s.onSurface,
          fontSize: fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          height: 1.45,
        ),
        children: inlineSpans(raw, s, fontSize: fontSize),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TABELA — implementação única, usada por tabelas markdown normais
// (via _parseStructural acima) e por blocos ```widget_table``` (via
// buildAiTableFromWidgetJson abaixo, chamada de aiwidgets.dart).
//
// Correção: colunas usam IntrinsicColumnWidth() em vez de
// FlexColumnWidth() — a tabela cresce para o tamanho real do
// conteúdo em vez de ser forçada a dividir a largura disponível
// (que causava o texto a "juntar-se"/quebrar mal). A Table inteira
// vive dentro de um SingleChildScrollView horizontal, para deslizar
// lateralmente quando a largura total ultrapassa o ecrã — o
// comportamento padrão esperado de uma tabela markdown.
// Bordas retas (BorderRadius.zero).
// ══════════════════════════════════════════════════════════════

class _AiTable extends StatelessWidget {
  final List<List<String>> rows;
  final AppColorScheme s;
  const _AiTable({required this.rows, required this.s});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final header = rows.first;
    final body = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: s.outline.withOpacity(0.4), width: 0.7),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: BoxDecoration(color: s.hover),
              children: header
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: s.onSurface),
                            children: _RichTextBlockParser.inlineSpans(c, s, fontSize: 12.5),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            for (final row in body)
              TableRow(
                children: row
                    .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 12.5, color: s.onSurface),
                              children: _RichTextBlockParser.inlineSpans(c, s, fontSize: 12.5),
                            ),
                          ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Adaptador: constrói _AiTable a partir do JSON cru de um bloco
/// ```widget_table``` ({ "headers": [...], "rows": [[...]] }).
/// Chamado por aiwidgets.dart em buildAiWidget() — é o único ponto
/// de contacto entre o dispatcher de widgets e a tabela real, que
/// vive aqui e não em aiwidgets.dart.
Widget buildAiTableFromWidgetJson(Map<String, dynamic> json, AppColorScheme s) {
  final headers = (json['headers'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
  final bodyRows = (json['rows'] as List?)
          ?.map((r) => (r as List).map((c) => c.toString()).toList())
          .toList() ??
      const <List<String>>[];
  if (headers.isEmpty && bodyRows.isEmpty) return const SizedBox.shrink();
  final allRows = <List<String>>[if (headers.isNotEmpty) headers, ...bodyRows];
  return Container(
    constraints: const BoxConstraints(maxWidth: 560),
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: _AiTable(rows: allRows, s: s),
  );
}

// ══════════════════════════════════════════════════════════════
// WIDGET SUGGESTION PILL
// ══════════════════════════════════════════════════════════════

class _WidgetSuggestionPill extends StatefulWidget {
  final AppColorScheme s;
  final int count;
  final VoidCallback? onTap;
  const _WidgetSuggestionPill({required this.s, required this.count, this.onTap});
  @override State<_WidgetSuggestionPill> createState() => _WidgetSuggestionPillState();
}

class _WidgetSuggestionPillState extends State<_WidgetSuggestionPill> {
  bool _h = false;

  String get _label => widget.count == 1
      ? 'mostrar também o widget desta resposta'
      : 'mostrar também os ${widget.count} widgets desta resposta';

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: Opacity(
        opacity: _h ? 0.65 : 1.0,
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('repaste.svg', color: s.onSurfaceVariant, size: 14),
              const SizedBox(width: 6),
              Text('↳', style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: s.onSurfaceVariant,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: s.onSurfaceVariant,
                    decorationThickness: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}