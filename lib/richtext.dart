// ══════════════════════════════════════════════════════════════
// FILE: lib/richtext.dart
//
// Motor de formatação para respostas da IA. Cobre:
// - Markdown estrutural: headers, bullets/numbered (com indentação
//   aninhada), checkboxes, blockquotes, linhas horizontais, tabelas
//   com formatação inline dentro das células, blocos de código.
// - Markdown inline: **bold**, ***bold itálico***, *itálico*/_itálico_,
//   `code`, [texto](url), ~~riscado~~.
// - Matemática: blocos $$...$$ e inline $...$, frações \frac{a}{b},
//   raízes \sqrt{x} e \sqrt[n]{x}, potências x^2 / x^{10}, subscritos
//   x_1 / x_{ij}, símbolos gregos (\alpha, \beta, \pi, \Delta, ...),
//   operadores e relações (\leq, \geq, \neq, \approx, \times, \div,
//   \pm, \cdot, ...), setas (\rightarrow, \Rightarrow, \leftrightarrow),
//   conjuntos (\in, \notin, \subset, \cup, \cap, \emptyset, \forall,
//   \exists), cálculo (\int, \sum, \prod, \lim, \partial, \nabla,
//   \infty), superscript/subscript unicode direto (², ³, ₁, ₂, ...).
// - Emoji shortcodes :smile: → 😄 (subconjunto comum).
// - Integração com widget_* (gráficos, tabelas interativas, etc.)
//   através de markers, mantendo compatibilidade com aitab.dart.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'colors.dart';
import 'aiwidgets.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// SÍMBOLOS MATEMÁTICOS — tabelas de tradução LaTeX → unicode
// ══════════════════════════════════════════════════════════════

/// Letras gregas minúsculas e maiúsculas.
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

/// Operadores, relações, setas, conjuntos, cálculo — tudo que não
/// precisa de estrutura especial (fração, raiz, potência), apenas
/// substituição direta de token por símbolo.
const Map<String, String> kMathSymbols = {
  // Operadores aritméticos
  r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\cdot': '·', r'\ast': '∗', r'\star': '⋆',
  // Relações
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\sim': '∼', r'\simeq': '≃', r'\cong': '≅', r'\propto': '∝',
  r'\ll': '≪', r'\gg': '≫',
  // Setas
  r'\rightarrow': '→', r'\to': '→', r'\leftarrow': '←',
  r'\leftrightarrow': '↔', r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
  r'\Leftrightarrow': '⇔', r'\mapsto': '↦', r'\uparrow': '↑',
  r'\downarrow': '↓', r'\nearrow': '↗', r'\searrow': '↘',
  // Conjuntos e lógica
  r'\in': '∈', r'\notin': '∉', r'\ni': '∋', r'\subset': '⊂',
  r'\subseteq': '⊆', r'\supset': '⊃', r'\supseteq': '⊇',
  r'\cup': '∪', r'\cap': '∩', r'\setminus': '∖',
  r'\emptyset': '∅', r'\varnothing': '∅',
  r'\forall': '∀', r'\exists': '∃', r'\nexists': '∄',
  r'\neg': '¬', r'\lnot': '¬', r'\land': '∧', r'\wedge': '∧',
  r'\lor': '∨', r'\vee': '∨', r'\oplus': '⊕', r'\otimes': '⊗',
  // Cálculo e análise
  r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇',
  r'\int': '∫', r'\iint': '∬', r'\iiint': '∭', r'\oint': '∮',
  r'\sum': '∑', r'\prod': '∏', r'\coprod': '∐',
  r'\lim': 'lim', r'\limsup': 'lim sup', r'\liminf': 'lim inf',
  r'\sqrt': '√',
  // Números e conjuntos especiais
  r'\mathbb{R}': 'ℝ', r'\mathbb{N}': 'ℕ', r'\mathbb{Z}': 'ℤ',
  r'\mathbb{Q}': 'ℚ', r'\mathbb{C}': 'ℂ',
  // Pontuação matemática
  r'\ldots': '…', r'\cdots': '⋯', r'\vdots': '⋮', r'\ddots': '⋱',
  r'\angle': '∠', r'\perp': '⊥', r'\parallel': '∥',
  r'\degree': '°', r'\prime': '′',
  // Setas de implicação lógica usadas em provas
  r'\implies': '⟹', r'\iff': '⟺',
  // Vários usados em física/química
  r'\hbar': 'ℏ', r'\ell': 'ℓ',
};

/// Mapas de superscript/subscript unicode para dígitos e sinais,
/// usados na conversão de x^2, x_1, etc. quando o expoente/índice
/// é curto (1 caractere ou dígitos simples) — produz um resultado
/// muito mais legível do que uma caixa de Transform.translate.
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

/// Converte uma sequência de caracteres simples (dígitos, sinais,
/// e algumas letras) para o seu equivalente superscript unicode.
/// Retorna null se algum caractere não tiver equivalente — nesse
/// caso o chamador deve cair para o widget de fração/expoente com
/// Transform.translate em vez de unicode puro.
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
// EMOJI SHORTCODES — subconjunto comum usado em respostas de chat
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

/// Um "átomo" já processado de uma expressão matemática — pode ser
/// texto simples, uma fração (numerador/denominador empilhados), ou
/// uma raiz. Usado para construir a Row/Column final do MathInline.
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
  final String? index; // raiz de índice n, null = raiz quadrada
  _MathSqrt(this.content, {this.index});
}

/// Substitui todos os tokens \comando conhecidos (gregos + símbolos)
/// por unicode, numa única passagem, dos mais longos para os mais
/// curtos para evitar que \leq seja parcialmente apanhado por \le.
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

/// Resolve x^{...} e x_{...} (com chavetas) ou x^2 e x_1 (um único
/// caractere, forma comum sem chavetas) para unicode superscript ou
/// subscript quando possível. O que não tiver mapeamento unicode
/// direto (ex: expoente com mais de um caractere não numérico,
/// como x^{n+1}) fica marcado com um separador especial que o
/// widget builder interpreta para desenhar um Transform.translate
/// em vez de unicode.
String _resolveSuperSubscripts(String expr) {
  var result = expr;

  // Forma com chavetas: x^{conteudo} ou x_{conteudo}
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

  // Forma sem chavetas: x^2, x_n (um único caractere após o sinal)
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

/// Extrai \frac{a}{b} e \sqrt{x} / \sqrt[n]{x} como átomos especiais,
/// devolvendo a lista ordenada de átomos que compõem a expressão
/// completa (texto simples intercalado com frações/raízes).
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
      // \frac{num}{den}
      atoms.add(_MathFraction(m.group(1)!, m.group(2)!));
    } else {
      // \sqrt ou \sqrt[n]
      atoms.add(_MathSqrt(m.group(5)!, index: m.group(4)));
    }
    last = m.end;
  }
  if (last < expr.length) {
    atoms.add(_MathText(expr.substring(last)));
  }
  return atoms;
}

/// Renderiza \u0001SUP{...}\u0001 / \u0001SUB{...}\u0001 residuais
/// (expoentes/índices sem mapeamento unicode direto) como spans com
/// Transform via WidgetSpan, dentro de um texto simples já resolvido.
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

/// Widget que renderiza uma expressão matemática inline (dentro do
/// fluxo de texto normal) ou em bloco (centrada, maior, com scroll
/// horizontal se não couber).
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
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.zero,
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

/// Extrai blocos $$...$$ (matemática em bloco, linha própria) de um
/// segmento de texto, devolvendo o texto com marcadores e a lista de
/// expressões extraídas, no mesmo padrão usado por parseAiWidgetBlocks
/// em aiwidgets.dart — mantém tudo consistente com o resto do app.
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
// RICH AI TEXT — ponto de entrada principal, usado por aitab.dart
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
  /// Ponto de entrada: extrai primeiro blocos de matemática $$...$$
  /// (que ocupam a própria linha/parágrafo), depois faz o parsing
  /// estrutural normal (headers, listas, tabelas, etc.), reinserindo
  /// os blocos de matemática nos pontos corretos.
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

      // Linha horizontal: ---, ***, ___ (3+, isolada) → Divider real.
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        flushTable();
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, thickness: 1, color: s.outline.withOpacity(0.5)),
        ));
        i++;
        continue;
      }

      // Tabelas
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

      // Headers # a ####
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

      // Blockquote: > texto
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

      // Indentação (para bullets/numbered aninhados) — medida sobre
      // a linha original, não a trimmed, cada 2 espaços = 1 nível.
      final indentMatch = RegExp(r'^(\s*)').firstMatch(line)!;
      final indentLevel = (indentMatch.group(1)!.length / 2).floor().clamp(0, 4);

      // Checkbox: - [ ] tarefa  /  - [x] tarefa feita — verificado
      // ANTES de bulletMatch, pois a sintaxe também começa por "- ".
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

      // Bullet: - item ou * item, com indentação preservada.
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

      // Numerado: 1. item, com indentação preservada.
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

      // Blocos de código ```lang```
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // consome a fence de fecho
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

      // Parágrafo normal
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _formattedText(trimmed, s),
      ));
      i++;
    }

    flushTable();
    return widgets;
  }

  /// Converte **bold**, ***bold itálico***, *itálico*/_itálico_,
  /// `code`, [texto](url), ~~riscado~~, $matemática$ inline e
  /// :emoji: shortcodes em spans — usado tanto pelo texto normal
  /// como pelas células de tabela.
  static List<InlineSpan> inlineSpans(String raw, AppColorScheme s, {double fontSize = 14.5}) {
    // Cor neutra para links/texto formatado, em vez de s.primary
    // (azul) — branco levemente acinzentado no dark, cinza-escuro
    // no light. Ver Bloco C, item 1.
    final linkColor = s.isDark ? const Color(0xFFE0E0E0) : const Color(0xFF3A3A3A);

    // Substitui emoji shortcodes primeiro (não interfere com o resto).
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
        // Matemática inline: $expr$
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
        // *itálico* ou _itálico_
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
// TABELA
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

    // Bordas retas — sem raio (Bloco C, item 4).
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Table(
        border: TableBorder.all(color: s.outline.withOpacity(0.4), width: 0.7),
        columnWidths: {
          for (int i = 0; i < header.length; i++) i: const FlexColumnWidth(),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: s.hover),
            children: header
                .map((c) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    );
  }
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