// ══════════════════════════════════════════════════════════════
// FILE: lib/richtext.dart
// ══════════════════════════════════════════════════════════════
//
// Parser de rich text — suporta:
//   • Markdown (negrito, itálico, riscado, código inline, links)
//   • Tabelas markdown e widgets de tabela
//   • Blocos de código com card completo (MANTÉM cor — syntax
//     highlighting nunca foi removido, só o texto normal em prosa
//     deixou de usar cores no _RichTextBlockParser)
//   • Blocos de gráfico ```chart{...json...}``` — bar, line, point,
//     SEM CARD — o gráfico entra diretamente no fluxo da conversa,
//     como no Notion: sem fundo, sem borda, sem padding de caixa.
//     Enquanto a fence ainda não fechou (streaming), NADA aparece
//     no lugar — nem JSON cru, nem placeholder — exatamente como
//     já acontecia com blocos de código normais. Quando fecha, o
//     gráfico entra com fade + scale suave.
//   • Blocos de calendário ```calendar{...json...}``` — grelha
//     mensal estilo Notion: 7 colunas, linhas finas entre semanas,
//     dias fora do mês esmaecidos, dia atual com círculo vermelho.
//   • Matemática LaTeX-like: frações, raízes, super/subscritos,
//     símbolos, letras gregas, operadores, setas, etc.
//   • Comandos LaTeX adicionais: \text, \mathbf, \mathcal, etc.
//   • ZERO emojis — kEmojiShortcodes foi esvaziado por pedido
//     explícito do utilizador; a tabela fica vazia (não removida)
//     para não quebrar quem ainda chama _substituteEmojis noutro
//     ponto do código.
//   • Widgets inline (quando ativados)
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
  // Operadores binários
  r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\cdot': '·', r'\ast': '∗', r'\star': '⋆', r'\circ': '∘',
  r'\bullet': '•', r'\oplus': '⊕', r'\otimes': '⊗', r'\ominus': '⊖',
  r'\odot': '⊙', r'\oslash': '⊘', r'\uplus': '⊎',
  // Relações
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\sim': '∼', r'\simeq': '≃', r'\cong': '≅', r'\propto': '∝',
  r'\ll': '≪', r'\gg': '≫', r'\prec': '≺', r'\succ': '≻',
  r'\preceq': '≼', r'\succeq': '≽', r'\subset': '⊂', r'\subseteq': '⊆',
  r'\supset': '⊃', r'\supseteq': '⊇', r'\in': '∈', r'\notin': '∉',
  r'\ni': '∋', r'\not\ni': '∌', r'\mid': '∣', r'\nmid': '∤',
  r'\parallel': '∥', r'\nparallel': '∦', r'\perp': '⊥',
  // Setas
  r'\rightarrow': '→', r'\to': '→', r'\leftarrow': '←',
  r'\leftrightarrow': '↔', r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
  r'\Leftrightarrow': '⇔', r'\mapsto': '↦', r'\uparrow': '↑',
  r'\downarrow': '↓', r'\nearrow': '↗', r'\searrow': '↘',
  r'\swarrow': '↙', r'\nwarrow': '↖', r'\longrightarrow': '⟶',
  r'\longleftarrow': '⟵', r'\longleftrightarrow': '⟷',
  r'\Longrightarrow': '⟹', r'\Longleftarrow': '⟸',
  r'\Longleftrightarrow': '⟺', r'\hookrightarrow': '↪',
  r'\hookleftarrow': '↩', r'\rightharpoonup': '⇀',
  r'\rightharpoondown': '⇁', r'\leftharpoonup': '↼',
  r'\leftharpoondown': '↽',
  // Lógica
  r'\forall': '∀', r'\exists': '∃', r'\nexists': '∄',
  r'\neg': '¬', r'\lnot': '¬', r'\land': '∧', r'\wedge': '∧',
  r'\lor': '∨', r'\vee': '∨', r'\top': '⊤', r'\bot': '⊥',
  // Conjuntos
  r'\emptyset': '∅', r'\varnothing': '∅', r'\cup': '∪', r'\cap': '∩',
  r'\setminus': '∖', r'\complement': '∁',
  // Análise
  r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇', r'\hbar': 'ℏ',
  r'\ell': 'ℓ', r'\imath': 'ı', r'\jmath': 'ȷ',
  // Integrais e somatórios
  r'\int': '∫', r'\iint': '∬', r'\iiint': '∭', r'\oint': '∮',
  r'\sum': '∑', r'\prod': '∏', r'\coprod': '∐',
  // Misc
  r'\angle': '∠', r'\measuredangle': '∡', r'\sphericalangle': '∢',
  r'\degree': '°', r'\prime': '′', r'\backprime': '‵',
  r'\therefore': '∴', r'\because': '∵', r'\cdots': '⋯',
  r'\ldots': '…', r'\vdots': '⋮', r'\ddots': '⋱', r'\iddots': '⋰',
  r'\implies': '⟹', r'\impliedby': '⟸', r'\iff': '⟺',
  // Conjuntos numéricos
  r'\mathbb{R}': 'ℝ', r'\mathbb{N}': 'ℕ', r'\mathbb{Z}': 'ℤ',
  r'\mathbb{Q}': 'ℚ', r'\mathbb{C}': 'ℂ', r'\mathbb{H}': 'ℍ',
  r'\mathbb{O}': '𝕆',
  // Delimitadores
  r'\lvert': '|', r'\rvert': '|', r'\lVert': '‖', r'\rVert': '‖',
  r'\langle': '⟨', r'\rangle': '⟩', r'\lceil': '⌈', r'\rceil': '⌉',
  r'\lfloor': '⌊', r'\rfloor': '⌋', r'\lbrace': '{', r'\rbrace': '}',
  // Acentos e marcas
  r'\hat': '', r'\bar': '', r'\vec': '', r'\dot': '', r'\ddot': '',
  r'\tilde': '', r'\overline': '', r'\underline': '', r'\boxed': '',
  // Outros
  r'\square': '□', r'\blacksquare': '■', r'\triangle': '△',
  r'\bigtriangleup': '△', r'\bigtriangledown': '▽', r'\lozenge': '◊',
  r'\diamond': '◆', r'\clubsuit': '♣', r'\diamondsuit': '♦',
  r'\heartsuit': '♥', r'\spadesuit': '♠',
};

// Mapas para comandos LaTeX que envolvem formatação e não apenas substituição
const Set<String> kMathFormattingCommands = {
  r'\text', r'\mathrm', r'\mathbf', r'\mathit', r'\mathsf', r'\mathtt',
  r'\mathcal', r'\mathbb', r'\mathfrak', r'\mathscr', r'\operatorname',
  r'\overrightarrow', r'\overleftarrow', r'\overline', r'\underline',
  r'\boxed', r'\color', r'\textcolor',
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
  'a': 'ₐ', 'e': 'ₑ', 'o': 'ₒ', 'x': 'ₓ', 'h': 'ₕ',
  'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'p': 'ₚ',
  's': 'ₛ', 't': 'ₜ',
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
// EMOJI SHORTCODES — ESVAZIADO por pedido explícito do utilizador
// (odeia emojis). A tabela fica vazia em vez de removida para não
// quebrar nenhuma outra parte do código que ainda a referencie —
// o loop que a consome simplesmente não encontra nada para trocar.
// ══════════════════════════════════════════════════════════════

const Map<String, String> kEmojiShortcodes = {};

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

class _MathOverline extends _MathAtom {
  final String content;
  _MathOverline(this.content);
}

class _MathUnderline extends _MathAtom {
  final String content;
  _MathUnderline(this.content);
}

class _MathBoxed extends _MathAtom {
  final String content;
  _MathBoxed(this.content);
}

class _MathColor extends _MathAtom {
  final String color;
  final String content;
  _MathColor(this.color, this.content);
}

class _MathAccent extends _MathAtom {
  final String accent;
  final String content;
  _MathAccent(this.accent, this.content);
}

class _MathArrow extends _MathAtom {
  final String direction;
  final String content;
  _MathArrow(this.direction, this.content);
}

String _stripOuterBraces(String s) {
  s = s.trim();
  if (s.startsWith('{') && s.endsWith('}')) {
    return s.substring(1, s.length - 1).trim();
  }
  return s;
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

String _resolveFormattingCommands(String expr) {
  var result = expr;

  result = result.replaceAllMapped(
    RegExp(r'\\text\{([^{}]+)\}'),
    (m) => '\u0002TXT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathrm\{([^{}]+)\}'),
    (m) => '\u0002TXT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathbf\{([^{}]+)\}'),
    (m) => '\u0002BF{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathit\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathsf\{([^{}]+)\}'),
    (m) => '\u0002SF{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathtt\{([^{}]+)\}'),
    (m) => '\u0002TT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathcal\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathbb\{([^{}]+)\}'),
    (m) => '\u0002BF{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathfrak\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\mathscr\{([^{}]+)\}'),
    (m) => '\u0002IT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\operatorname\{([^{}]+)\}'),
    (m) => '\u0002TXT{${m.group(1)}}\u0002',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\overrightarrow\{([^{}]+)\}'),
    (m) => '\u0003OVER{${m.group(1)}}\u0003',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\overleftarrow\{([^{}]+)\}'),
    (m) => '\u0003UNDER{${m.group(1)}}\u0003',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\overline\{([^{}]+)\}'),
    (m) => '\u0004OVERLINE{${m.group(1)}}\u0004',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\underline\{([^{}]+)\}'),
    (m) => '\u0004UNDERLINE{${m.group(1)}}\u0004',
  );

  result = result.replaceAllMapped(
    RegExp(r'\\boxed\{([^{}]+)\}'),
    (m) => '\u0005BOXED{${m.group(1)}}\u0005',
  );

  result = result.replaceAllMapped(
  RegExp(r'\\color\{([^{}]+)\}\{([^{}]+)\}'),
  (m) => '\u0006COLOR{\$1}{\$2}\u0006',
);
result = result.replaceAllMapped(
  RegExp(r'\\textcolor\{([^{}]+)\}\{([^{}]+)\}'),
  (m) => '\u0006COLOR{\$1}{\$2}\u0006',
);

  for (final acc in ['hat', 'bar', 'vec', 'dot', 'ddot', 'tilde']) {
    result = result.replaceAllMapped(
      RegExp(r'\\' + acc + r'\{([^{}]+)\}'),
      (m) => '\u0007ACC{$acc}{${m.group(1)}}\u0007',
    );
  }

  return result;
}

List<_MathAtom> _parseMathExpression(String raw) {
  var expr = _substituteKnownTokens(raw);
  expr = _resolveSuperSubscripts(expr);
  expr = _resolveFormattingCommands(expr);

  final atoms = <_MathAtom>[];
  final combinedPattern = RegExp(
    r'\\frac\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\sqrt(\[([^\]]+)\])?\{([^{}]+)\}'
    r'|\u0004OVERLINE\{([^{}]+)\}\u0004'
    r'|\u0004UNDERLINE\{([^{}]+)\}\u0004'
    r'|\u0005BOXED\{([^{}]+)\}\u0005'
    r'|\u0006COLOR\{([^{}]+)\}\{([^{}]+)\}\u0006'
    r'|\u0007ACC\{([^{}]+)\}\{([^{}]+)\}\u0007'
    r'|\u0003OVER\{([^{}]+)\}\u0003'
    r'|\u0003UNDER\{([^{}]+)\}\u0003',
  );

  int last = 0;
  for (final m in combinedPattern.allMatches(expr)) {
    if (m.start > last) {
      atoms.addAll(_parsePlainMathText(expr.substring(last, m.start)));
    }
    final match = m.group(0)!;
    if (match.startsWith(r'\frac')) {
      atoms.add(_MathFraction(m.group(1)!, m.group(2)!));
    } else if (match.startsWith(r'\sqrt')) {
      atoms.add(_MathSqrt(m.group(5)!, index: m.group(4)));
    } else if (match.startsWith('\u0004OVERLINE')) {
      atoms.add(_MathOverline(m.group(6)!));
    } else if (match.startsWith('\u0004UNDERLINE')) {
      atoms.add(_MathUnderline(m.group(7)!));
    } else if (match.startsWith('\u0005BOXED')) {
      atoms.add(_MathBoxed(m.group(8)!));
    } else if (match.startsWith('\u0006COLOR')) {
      atoms.add(_MathColor(m.group(9)!, m.group(10)!));
    } else if (match.startsWith('\u0007ACC')) {
      atoms.add(_MathAccent(m.group(11)!, m.group(12)!));
    } else if (match.startsWith('\u0003OVER')) {
      atoms.add(_MathArrow('over', m.group(13)!));
    } else if (match.startsWith('\u0003UNDER')) {
      atoms.add(_MathArrow('under', m.group(14)!));
    }
    last = m.end;
  }
  if (last < expr.length) {
    atoms.addAll(_parsePlainMathText(expr.substring(last)));
  }
  return atoms;
}

List<_MathAtom> _parsePlainMathText(String text) {
  if (text.isEmpty) return const [];
  final atoms = <_MathAtom>[];

  final pattern = RegExp(
    r'\u0002(?:TXT|BF|IT|SF|TT)\{([^{}]+)\}\u0002'
  );
  int last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) {
      final plain = text.substring(last, m.start);
      if (plain.isNotEmpty) atoms.add(_MathText(plain));
    }
    final type = m.group(0)!.substring(1, m.group(0)!.indexOf('{') - 1);
    final content = m.group(1)!;
    switch (type) {
      case 'TXT':
        atoms.add(_MathText(content, italic: false));
        break;
      case 'BF':
        atoms.add(_MathText(content, italic: true));
        break;
      case 'IT':
        atoms.add(_MathText(content, italic: true));
        break;
      case 'SF':
        atoms.add(_MathText(content, italic: false));
        break;
      case 'TT':
        atoms.add(_MathText(content, italic: false));
        break;
      default:
        atoms.add(_MathText(content));
    }
    last = m.end;
  }
  if (last < text.length) {
    final remaining = text.substring(last);
    if (remaining.isNotEmpty) atoms.add(_MathText(remaining));
  }
  return atoms;
}

// ══════════════════════════════════════════════════════════════
// RENDERIZAÇÃO DE ÁTOMOS MATEMÁTICOS
// ══════════════════════════════════════════════════════════════

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
        case _MathText(:final text, :final italic):
          if (text.isEmpty) continue;
          final style = baseStyle.copyWith(
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          );
          rowChildren.add(RichText(
            text: TextSpan(children: _renderMathTextWithMarkers(text, style)),
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
        case _MathOverline(:final content):
          rowChildren.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(content, style: baseStyle),
                Container(height: 1.2, width: content.length * baseFontSize * 0.56, color: s.onSurface),
              ],
            ),
          ));
        case _MathUnderline(:final content):
          rowChildren.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(content, style: baseStyle.copyWith(decoration: TextDecoration.underline)),
          ));
        case _MathBoxed(:final content):
          rowChildren.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: s.onSurface, width: 1),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(content, style: baseStyle),
          ));
        case _MathColor(:final color, :final content):
          rowChildren.add(Text(
            content,
            style: baseStyle.copyWith(color: _parseColor(color, s)),
          ));
        case _MathAccent(:final accent, :final content):
          rowChildren.add(_buildAccent(accent, content, baseStyle));
        case _MathArrow(:final direction, :final content):
          rowChildren.add(_buildArrow(direction, content, baseStyle));
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

  Widget _buildAccent(String accent, String content, TextStyle baseStyle) {
    switch (accent) {
      case 'hat':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('^', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      case 'bar':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: content.length * baseStyle.fontSize! * 0.55, height: 1, color: baseStyle.color),
            Text(content, style: baseStyle),
          ],
        );
      case 'vec':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('→', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      case 'dot':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('˙', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.8)),
            Text(content, style: baseStyle),
          ],
        );
      case 'ddot':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¨', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      case 'tilde':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('~', style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.7)),
            Text(content, style: baseStyle),
          ],
        );
      default:
        return Text(content, style: baseStyle);
    }
  }

  Widget _buildArrow(String direction, String content, TextStyle baseStyle) {
    final arrow = direction == 'over' ? '⟶' : '⟵';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (direction == 'over') ...[
          Text(arrow, style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.8)),
          Text(content, style: baseStyle),
        ] else ...[
          Text(content, style: baseStyle),
          Text(arrow, style: baseStyle.copyWith(fontSize: baseStyle.fontSize! * 0.8)),
        ],
      ],
    );
  }

  Color _parseColor(String colorName, AppColorScheme s) {
    switch (colorName.toLowerCase()) {
      case 'red': return const Color(0xFFEF4444);
      case 'green': return const Color(0xFF22C55E);
      case 'blue': return const Color(0xFF3B82F6);
      case 'yellow': return const Color(0xFFF59E0B);
      case 'orange': return const Color(0xFFF97316);
      case 'purple': return const Color(0xFF8B5CF6);
      case 'pink': return const Color(0xFFEC4899);
      case 'cyan': return const Color(0xFF06B6D4);
      case 'white': return Colors.white;
      case 'black': return Colors.black;
      case 'gray': case 'grey': return const Color(0xFF9CA3AF);
      default: return s.onSurface;
    }
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
// GRÁFICOS MARKDOWN-NATIVOS — bloco ```chart{...json...}```
// ══════════════════════════════════════════════════════════════
// Formato esperado dentro da fence:
// {
//   "type": "bar" | "line" | "point",
//   "title": "Passos esta semana",       (opcional)
//   "subtitle": "Média: 1.577",          (opcional)
//   "color": "orange",                    (opcional — ver _chartColor)
//   "labels": ["Sat","Sun","Mon", ...],   (eixo X)
//   "values": [1500, 200, 180, ...]       (eixo Y — números)
// }
//
// Enquanto a fence ```chart ... ``` ainda não fechou (streaming em
// curso), o bloco inteiro fica invisível — o parser estrutural só
// reconhece um bloco de código depois de encontrar a fence de
// fecho, exatamente como já acontecia com blocos ``` normais. Não
// há JSON cru nem placeholder visível durante a escrita.
//
// SEM CARD: o gráfico NÃO é envolto em Container com fundo/borda —
// entra diretamente no fluxo da conversa, como no Notion. Só o
// título, subtítulo, área de desenho e labels do eixo X aparecem,
// sobre o fundo natural da página.
// ══════════════════════════════════════════════════════════════

class ChartSpec {
  final String type; // bar | line | point
  final String? title;
  final String? subtitle;
  final String colorName;
  final List<String> labels;
  final List<double> values;

  const ChartSpec({
    required this.type,
    required this.labels,
    required this.values,
    this.title,
    this.subtitle,
    this.colorName = 'blue',
  });

  static ChartSpec? tryParse(String rawJson) {
    try {
      // Parser tolerante manual — evita depender de dart:convert
      // falhar duro com vírgulas finais ou aspas simples que a IA
      // por vezes gera; tenta primeiro o caminho estrito e, se
      // falhar, normaliza vírgulas finais antes de tentar de novo.
      Map<String, dynamic>? decoded = _tryDecode(rawJson);
      if (decoded == null) {
        final cleaned = rawJson.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
        decoded = _tryDecode(cleaned);
      }
      if (decoded == null) return null;

      final type = (decoded['type']?.toString() ?? 'bar').toLowerCase();
      if (type != 'bar' && type != 'line' && type != 'point') return null;

      final rawLabels = decoded['labels'];
      final rawValues = decoded['values'];
      if (rawLabels is! List || rawValues is! List) return null;
      if (rawLabels.isEmpty || rawValues.isEmpty) return null;

      final labels = rawLabels.map((e) => e.toString()).toList();
      final values = <double>[];
      for (final v in rawValues) {
        if (v is num) {
          values.add(v.toDouble());
        } else {
          final parsed = double.tryParse(v.toString());
          if (parsed == null) return null;
          values.add(parsed);
        }
      }
      if (values.isEmpty) return null;

      return ChartSpec(
        type: type,
        title: decoded['title']?.toString(),
        subtitle: decoded['subtitle']?.toString(),
        colorName: decoded['color']?.toString() ?? 'blue',
        labels: labels,
        values: values,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final decoded = _jsonDecodeSafe(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}

// Pequeno wrapper para isolar dart:convert num único ponto — usa
// jsonDecode da própria dart:convert, já disponível via
// flutter/services indiretamente. Declarado aqui para clareza.
dynamic _jsonDecodeSafe(String raw) {
  return const JsonDecoderShim().convert(raw);
}

// Shim mínimo em vez de importar dart:convert inteiro só para um
// decode — mantém o ficheiro consistente com o resto do projeto,
// que já não importava dart:convert aqui anteriormente.
class JsonDecoderShim {
  const JsonDecoderShim();
  dynamic convert(String input) {
    return _JsonParser(input).parse();
  }
}

class _JsonParser {
  final String s;
  int i = 0;
  _JsonParser(this.s);

  dynamic parse() {
    _skipWs();
    final v = _parseValue();
    _skipWs();
    return v;
  }

  void _skipWs() {
    while (i < s.length && (s[i] == ' ' || s[i] == '\n' || s[i] == '\t' || s[i] == '\r')) {
      i++;
    }
  }

  dynamic _parseValue() {
    _skipWs();
    if (i >= s.length) throw const FormatException('unexpected end');
    final c = s[i];
    if (c == '{') return _parseObject();
    if (c == '[') return _parseArray();
    if (c == '"') return _parseString();
    if (c == 't' || c == 'f') return _parseBool();
    if (c == 'n') return _parseNull();
    return _parseNumber();
  }

  Map<String, dynamic> _parseObject() {
    final map = <String, dynamic>{};
    i++; // {
    _skipWs();
    if (i < s.length && s[i] == '}') { i++; return map; }
    while (true) {
      _skipWs();
      final key = _parseString();
      _skipWs();
      if (i >= s.length || s[i] != ':') throw const FormatException('expected :');
      i++;
      _skipWs();
      final value = _parseValue();
      map[key] = value;
      _skipWs();
      if (i < s.length && s[i] == ',') { i++; continue; }
      if (i < s.length && s[i] == '}') { i++; break; }
      throw const FormatException('expected , or }');
    }
    return map;
  }

  List<dynamic> _parseArray() {
    final list = <dynamic>[];
    i++; // [
    _skipWs();
    if (i < s.length && s[i] == ']') { i++; return list; }
    while (true) {
      _skipWs();
      list.add(_parseValue());
      _skipWs();
      if (i < s.length && s[i] == ',') { i++; continue; }
      if (i < s.length && s[i] == ']') { i++; break; }
      throw const FormatException('expected , or ]');
    }
    return list;
  }

  String _parseString() {
    if (s[i] != '"') throw const FormatException('expected string');
    i++;
    final buf = StringBuffer();
    while (i < s.length && s[i] != '"') {
      if (s[i] == '\\' && i + 1 < s.length) {
        i++;
        final esc = s[i];
        switch (esc) {
          case 'n': buf.write('\n'); break;
          case 't': buf.write('\t'); break;
          case 'r': buf.write('\r'); break;
          case '"': buf.write('"'); break;
          case '\\': buf.write('\\'); break;
          case '/': buf.write('/'); break;
          default: buf.write(esc);
        }
        i++;
      } else {
        buf.write(s[i]);
        i++;
      }
    }
    i++; // closing "
    return buf.toString();
  }

  bool _parseBool() {
    if (s.startsWith('true', i)) { i += 4; return true; }
    if (s.startsWith('false', i)) { i += 5; return false; }
    throw const FormatException('expected bool');
  }

  dynamic _parseNull() {
    if (s.startsWith('null', i)) { i += 4; return null; }
    throw const FormatException('expected null');
  }

  num _parseNumber() {
    final start = i;
    if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
    while (i < s.length && RegExp(r'[0-9]').hasMatch(s[i])) i++;
    if (i < s.length && s[i] == '.') {
      i++;
      while (i < s.length && RegExp(r'[0-9]').hasMatch(s[i])) i++;
    }
    if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
      i++;
      if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
      while (i < s.length && RegExp(r'[0-9]').hasMatch(s[i])) i++;
    }
    final token = s.substring(start, i);
    if (token.isEmpty) throw const FormatException('expected number');
    return num.parse(token);
  }
}

Color _chartColor(String name) {
  switch (name.toLowerCase()) {
    case 'orange': return const Color(0xFFFF9500);
    case 'blue':   return const Color(0xFF0A84FF);
    case 'green':  return const Color(0xFF30D158);
    case 'red':    return const Color(0xFFFF453A);
    case 'yellow': return const Color(0xFFFFD60A);
    case 'purple': return const Color(0xFFBF5AF2);
    case 'pink':   return const Color(0xFFFF375F);
    case 'teal':   return const Color(0xFF64D2FF);
    case 'indigo': return const Color(0xFF5E5CE6);
    default:       return const Color(0xFF0A84FF);
  }
}

// ── Widget de gráfico — estilo Apple Health / Apple Design HIG,
// SEM CARD: entra diretamente no fluxo da conversa, sem fundo,
// sem borda, sem padding de caixa envolvente — exatamente como no
// Notion, onde o gráfico "flutua" sobre o fundo da página. Eixo Y
// com labels leves, grelha pontilhada fina, barras/linha/pontos na
// cor escolhida, título+subtítulo no topo à esquerda. Entra com
// fade+scale suave quando montado. ──────────────────────────────

class AiChartCard extends StatefulWidget {
  final ChartSpec spec;
  final AppColorScheme s;
  const AiChartCard({super.key, required this.spec, required this.s});

  @override State<AiChartCard> createState() => _AiChartCardState();
}

class _AiChartCardState extends State<AiChartCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween(begin: 0.94, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    // Dispara a entrada assim que o widget é montado — como o
    // bloco só chega ao parser depois de a fence fechar, isto
    // acontece exatamente no momento em que o gráfico "aparece",
    // dando a sensação de entrada em tempo real sem nunca ter
    // mostrado dados incompletos.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final s = widget.s;
    final color = _chartColor(spec.colorName);
    final maxVal = spec.values.reduce((a, b) => a > b ? a : b);
    final niceMax = _niceCeiling(maxVal);

    // SEM CARD — removido o Container com cor de fundo, borda e
    // borderRadius que existia antes. O conteúdo (título, corpo,
    // labels do eixo X) entra diretamente no fluxo, apenas com
    // uma margem vertical mínima para respirar entre blocos.
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (spec.title != null) ...[
                Text(spec.title!,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: s.onSurfaceVariant,
                        letterSpacing: 0.2)),
                const SizedBox(height: 2),
              ],
              if (spec.subtitle != null) ...[
                Text(spec.subtitle!,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: s.onSurface)),
                const SizedBox(height: 10),
              ] else
                const SizedBox(height: 6),
              SizedBox(
                height: 170,
                child: _ChartBody(
                  spec: spec,
                  color: color,
                  niceMax: niceMax,
                  s: s,
                ),
              ),
              const SizedBox(height: 6),
              _ChartXLabels(labels: spec.labels, s: s),
            ],
          ),
        ),
      ),
    );
  }

  double _niceCeiling(double v) {
    if (v <= 0) return 1;
    final magnitude = _pow10Floor(v);
    final normalized = v / magnitude;
    double niceNormalized;
    if (normalized <= 1) niceNormalized = 1;
    else if (normalized <= 2) niceNormalized = 2;
    else if (normalized <= 5) niceNormalized = 5;
    else niceNormalized = 10;
    return niceNormalized * magnitude;
  }

  double _pow10Floor(double v) {
    double magnitude = 1;
    while (magnitude * 10 <= v) magnitude *= 10;
    return magnitude;
  }
}

class _ChartBody extends StatelessWidget {
  final ChartSpec spec;
  final Color color;
  final double niceMax;
  final AppColorScheme s;
  const _ChartBody({
    required this.spec,
    required this.color,
    required this.niceMax,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ChartPainter(
                type: spec.type,
                values: spec.values,
                niceMax: niceMax,
                color: color,
                gridColor: s.outlineVariant,
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        _ChartYAxis(niceMax: niceMax, s: s),
      ],
    );
  }
}

class _ChartYAxis extends StatelessWidget {
  final double niceMax;
  final AppColorScheme s;
  const _ChartYAxis({required this.niceMax, required this.s});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 10.5, color: s.onSurfaceVariant);
    String fmt(double v) {
      if (v >= 1000) {
        final k = v / 1000;
        return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
      }
      return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
    }
    return SizedBox(
      width: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmt(niceMax), style: style),
          Text(fmt(niceMax / 2), style: style),
          Text('0', style: style),
        ],
      ),
    );
  }
}

class _ChartXLabels extends StatelessWidget {
  final List<String> labels;
  final AppColorScheme s;
  const _ChartXLabels({required this.labels, required this.s});

  @override
  Widget build(BuildContext context) {
    // Evita amontoar labels quando há muitos pontos — mostra no
    // máximo ~7, distribuídos, tal como os gráficos de referência.
    final step = (labels.length / 7).ceil().clamp(1, labels.length);
    final visible = <int>[];
    for (int idx = 0; idx < labels.length; idx += step) {
      visible.add(idx);
    }
    if (visible.isNotEmpty && visible.last != labels.length - 1) {
      visible.add(labels.length - 1);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 42),
      child: Row(
        children: List.generate(labels.length, (idx) {
          final show = visible.contains(idx);
          return Expanded(
            child: Text(
              show ? labels[idx] : '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: s.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          );
        }),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final String type;
  final List<double> values;
  final double niceMax;
  final Color color;
  final Color gridColor;
  _ChartPainter({
    required this.type,
    required this.values,
    required this.niceMax,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    switch (type) {
      case 'bar':
        _paintBars(canvas, size);
        break;
      case 'line':
        _paintLine(canvas, size, filled: true);
        break;
      case 'point':
        _paintPoints(canvas, size);
        break;
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - frac);
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dashWidth = 3.0;
    const dashSpace = 3.0;
    final total = (to - from).distance;
    final direction = (to - from) / total;
    double covered = 0;
    while (covered < total) {
      final segStart = from + direction * covered;
      final segEnd = from + direction * (covered + dashWidth).clamp(0, total);
      canvas.drawLine(segStart, segEnd, paint);
      covered += dashWidth + dashSpace;
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final slot = size.width / n;
    final barWidth = (slot * 0.5).clamp(3.0, 28.0);
    final paint = Paint()..color = color;

    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0, niceMax);
      final h = niceMax == 0 ? 0.0 : (v / niceMax) * size.height;
      final cx = slot * i + slot / 2;
      final rect = Rect.fromLTWH(cx - barWidth / 2, size.height - h, barWidth, h);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  void _paintLine(Canvas canvas, Size size, {bool filled = false}) {
    final n = values.length;
    if (n == 0) return;
    final slot = n > 1 ? size.width / (n - 1) : size.width;
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0, niceMax);
      final h = niceMax == 0 ? 0.0 : (v / niceMax) * size.height;
      final x = n > 1 ? slot * i : size.width / 2;
      points.add(Offset(x, size.height - h));
    }

    if (filled) {
      final fillPath = Path()..moveTo(points.first.dx, size.height);
      for (final p in points) fillPath.lineTo(p.dx, p.dy);
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) linePath.lineTo(p.dx, p.dy);
    canvas.drawPath(linePath, linePaint);
  }

  void _paintPoints(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final slot = n > 1 ? size.width / (n - 1) : size.width;

    // Linha fina conectando os pontos, no estilo do gráfico de
    // referência "Point marks" — sem preenchimento.
    _paintLine(canvas, size, filled: false);

    final dotPaint = Paint()..color = color;
    final dotStrokePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0, niceMax);
      final h = niceMax == 0 ? 0.0 : (v / niceMax) * size.height;
      final x = n > 1 ? slot * i : size.width / 2;
      final center = Offset(x, size.height - h);
      canvas.drawCircle(center, 3.2, dotPaint);
      canvas.drawCircle(center, 3.2, dotStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.niceMax != niceMax;
  }
}

// ══════════════════════════════════════════════════════════════
// CALENDÁRIO MARKDOWN-NATIVO — bloco ```calendar{...json...}```
// ══════════════════════════════════════════════════════════════
// Formato esperado dentro da fence:
// {
//   "month": "Outubro",              (nome do mês exibido, opcional)
//   "year": 2025,                     (opcional)
//   "startWeekday": 0,                 (0 = domingo, quantas colunas
//                                        vazias antes do dia 1; se
//                                        omitido assume-se 0)
//   "daysInMonth": 31,                 (obrigatório)
//   "leadingDays": 5,                  (dias do mês anterior a
//                                        mostrar cinzentos antes do
//                                        dia 1 — opcional)
//   "trailingDays": 5,                 (dias do mês seguinte a
//                                        mostrar cinzentos depois do
//                                        último dia — opcional)
//   "today": 21                        (dia a destacar com círculo
//                                        vermelho — opcional)
// }
//
// Réplica fiel do calendário do Notion: grelha 7 colunas sem
// cabeçalho de dias da semana, linha fina separando cada semana,
// dias fora do mês corrente em cinza claro, dia atual com círculo
// vermelho preenchido e número em branco. SEM CARD — entra
// diretamente no fluxo, como o gráfico.
// ══════════════════════════════════════════════════════════════

class CalendarSpec {
  final String? month;
  final int? year;
  final int leadingDays;
  final int daysInMonth;
  final int trailingDays;
  final int? today;

  const CalendarSpec({
    this.month,
    this.year,
    required this.leadingDays,
    required this.daysInMonth,
    required this.trailingDays,
    this.today,
  });

  static CalendarSpec? tryParse(String rawJson) {
    try {
      Map<String, dynamic>? decoded = _tryDecode(rawJson);
      if (decoded == null) {
        final cleaned = rawJson.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
        decoded = _tryDecode(cleaned);
      }
      if (decoded == null) return null;

      final daysInMonth = decoded['daysInMonth'];
      if (daysInMonth is! num) return null;

      final leading = decoded['leadingDays'];
      final trailing = decoded['trailingDays'];
      final todayRaw = decoded['today'];
      final yearRaw = decoded['year'];

      return CalendarSpec(
        month: decoded['month']?.toString(),
        year: yearRaw is num ? yearRaw.toInt() : null,
        leadingDays: leading is num ? leading.toInt() : 0,
        daysInMonth: daysInMonth.toInt(),
        trailingDays: trailing is num ? trailing.toInt() : 0,
        today: todayRaw is num ? todayRaw.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final decoded = _jsonDecodeSafe(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _CalendarCell {
  final int number;
  final bool inCurrentMonth;
  final bool isToday;
  const _CalendarCell({
    required this.number,
    required this.inCurrentMonth,
    required this.isToday,
  });
}

// Widget de calendário — estilo Notion: sem card, sem cabeçalho de
// dias da semana, grelha 7 colunas, linha fina entre semanas, dias
// fora do mês esmaecidos, dia atual em círculo vermelho.
class NotionCalendar extends StatelessWidget {
  final CalendarSpec spec;
  final AppColorScheme s;
  const NotionCalendar({super.key, required this.spec, required this.s});

  List<_CalendarCell> _buildCells() {
    final cells = <_CalendarCell>[];

    // Dias do mês anterior (esmaecidos) — numerados a contar para
    // trás a partir do próprio leadingDays, tal como o Notion
    // mostra "26 27 28 29 30 31" antes do dia 1.
    final prevMonthLast = spec.leadingDays; // total de dias visíveis antes
    for (int k = 0; k < spec.leadingDays; k++) {
      cells.add(_CalendarCell(
        number: 0, // preenchido abaixo
        inCurrentMonth: false,
        isToday: false,
      ));
    }
    // Recalcula números reais dos dias do mês anterior de trás
    // para a frente, para bater certo com a imagem de referência.
    if (spec.leadingDays > 0) {
      // Assume que o mês anterior termina num dia >= leadingDays;
      // como não recebemos o total de dias do mês anterior,
      // numeramos de forma consistente terminando imediatamente
      // antes do dia 1 do mês atual.
      final placeholderLast = 31; // valor neutro só para numeração decrescente
      int startNumber = placeholderLast - spec.leadingDays + 1;
      // Ajuste simples: se o consumidor não fornecer o tamanho real
      // do mês anterior, ainda assim a sequência fica crescente e
      // visualmente coerente (ex.: 26, 27, 28, 29, 30, 31).
      for (int k = 0; k < spec.leadingDays; k++) {
        cells[k] = _CalendarCell(
          number: startNumber + k,
          inCurrentMonth: false,
          isToday: false,
        );
      }
    }

    // Dias do mês atual.
    for (int day = 1; day <= spec.daysInMonth; day++) {
      cells.add(_CalendarCell(
        number: day,
        inCurrentMonth: true,
        isToday: spec.today != null && spec.today == day,
      ));
    }

    // Dias do mês seguinte (esmaecidos).
    for (int day = 1; day <= spec.trailingDays; day++) {
      cells.add(_CalendarCell(
        number: day,
        inCurrentMonth: false,
        isToday: false,
      ));
    }

    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();
    final weeks = <List<_CalendarCell>>[];
    for (int i = 0; i < cells.length; i += 7) {
      final end = (i + 7 <= cells.length) ? i + 7 : cells.length;
      final week = cells.sublist(i, end);
      // Preenche a última semana incompleta com células vazias
      // transparentes para manter a grelha alinhada a 7 colunas.
      while (week.length < 7) {
        week.add(const _CalendarCell(number: -1, inCurrentMonth: false, isToday: false));
      }
      weeks.add(week);
    }

    final headerLabel = [
      if (spec.month != null) spec.month!,
      if (spec.year != null) spec.year!.toString(),
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerLabel.isNotEmpty) ...[
            Text(
              headerLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: s.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (int w = 0; w < weeks.length; w++) ...[
            Row(
              children: weeks[w].map((cell) => Expanded(
                child: _CalendarCellWidget(cell: cell, s: s),
              )).toList(),
            ),
            if (w < weeks.length - 1)
              Divider(height: 1, thickness: 1, color: s.outline.withOpacity(0.35)),
          ],
        ],
      ),
    );
  }
}

class _CalendarCellWidget extends StatelessWidget {
  final _CalendarCell cell;
  final AppColorScheme s;
  const _CalendarCellWidget({required this.cell, required this.s});

  @override
  Widget build(BuildContext context) {
    if (cell.number < 0) {
      // Célula vazia de preenchimento (última semana incompleta).
      return const SizedBox(height: 56);
    }

    final textColor = cell.isToday
        ? Colors.white
        : cell.inCurrentMonth
            ? s.onSurface
            : s.onSurfaceVariant.withOpacity(0.45);

    return SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: cell.isToday
              ? Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8483C), // vermelho Notion
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${cell.number}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  '${cell.number}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                  ),
                ),
        ),
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

      // ─────────────────────────────────────────────────────────
      // BLOCO DE CITAÇÃO (blockquote) — agrupa linhas ">" consecutivas
      // e remove tags [!NOTE], [!TIP], [!IMPORTANT], [!WARNING], [!CAUTION]
      // ─────────────────────────────────────────────────────────
      if (trimmed.startsWith('>')) {
        flushTable();
        final quoteLines = <String>[];
        while (i < lines.length) {
          final currentTrimmed = lines[i].trim();
          if (!currentTrimmed.startsWith('>')) break;

          // Remove o ">" e espaço opcional
          var content = currentTrimmed.replaceFirst(RegExp(r'^>\s?'), '');

          // Remove qualquer tag [![...]] se presente
          content = content.replaceFirst(
            RegExp(r'^\s*\[![^\]]*\]\s*'),
            '',
          );

          quoteLines.add(content);
          i++;
        }

        final quoteText = quoteLines.join('\n');
        widgets.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: s.outline,
                    borderRadius: BorderRadius.circular(2), // pontas curvas
                  ),
                ),
                Expanded(
                  child: _formattedText(quoteText, s),
                ),
              ],
            ),
          ),
        );
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

        final codeContent = codeLines.join('\n');

        // ─────────────────────────────────────────────────────
        // BLOCO ```chart``` — tenta interpretar como gráfico.
        // Se o JSON não for válido (raro, mas possível se a IA
        // errou a sintaxe), cai para o AiCodeBlock normal em vez
        // de mostrar erro — nunca mostra JSON cru como se fosse
        // texto solto.
        // ─────────────────────────────────────────────────────
        if (lang.toLowerCase() == 'chart') {
          final spec = ChartSpec.tryParse(codeContent);
          if (spec != null) {
            widgets.add(AiChartCard(spec: spec, s: s));
            continue;
          }
        }

        // ─────────────────────────────────────────────────────
        // BLOCO ```calendar``` — tenta interpretar como grelha de
        // calendário estilo Notion. Mesma lógica de fallback: se
        // o JSON vier inválido, cai para o AiCodeBlock normal em
        // vez de mostrar erro ou JSON cru.
        // ─────────────────────────────────────────────────────
        if (lang.toLowerCase() == 'calendar') {
          final calSpec = CalendarSpec.tryParse(codeContent);
          if (calSpec != null) {
            widgets.add(NotionCalendar(spec: calSpec, s: s));
            continue;
          }
        }

        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AiCodeBlock(
            code: codeContent,
            language: lang.isEmpty ? 'text' : lang,
            s: s,
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
    // Cor de link neutra (não usa mais azul vivo/roxo — texto em
    // prosa fica monocromático por pedido explícito do
    // utilizador, com sublinhado a marcar o link em vez da cor).
    final linkColor = s.onSurface;

    var processed = raw;
    // kEmojiShortcodes está vazio (ver acima) — este loop não faz
    // nada agora, mas mantém-se para não quebrar contrato.
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
            decorationColor: linkColor.withOpacity(0.5),
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
        // Código inline MANTÉM a cor de fundo — só o texto de
        // prosa perdeu cor, não os elementos que já eram
        // visualmente diferenciados por natureza (código).
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
// TABELA — implementação única
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

// ══════════════════════════════════════════════════════════════
// AI CODE BLOCK — MAIS CORES: paleta ampliada de syntax
// highlighting. Cada categoria de token tem cor própria e
// distinta (tags, atributos, strings, comentários, keywords,
// números, funções, tipos, constantes, operadores, self/this,
// decorators, built-ins) para um resultado visualmente mais rico
// do que a versão anterior, mantendo o texto de prosa fora dos
// blocos de código monocromático (isso não foi tocado).
// ══════════════════════════════════════════════════════════════

class _TokenPattern {
  final RegExp regex;
  final Color? color;
  final FontStyle? fontStyle;
  final FontWeight? fontWeight;

  const _TokenPattern(this.regex, {this.color, this.fontStyle, this.fontWeight});
}

// Paleta ampliada — mais matizes distintos por categoria de token,
// inspirada em temas ricos (One Dark Pro / Dracula / Night Owl),
// mas com mais subdivisões do que a paleta anterior tinha.
const Color _tokTag = Color(0xFFFF6BB3);        // tags HTML/XML
const Color _tokAttr = Color(0xFF9CDCFE);       // atributos HTML
const Color _tokString = Color(0xFFE3B341);     // strings
const Color _tokStringEscape = Color(0xFFFFD866); // escapes dentro de strings
const Color _tokComment = Color(0xFF6A737D);    // comentários
const Color _tokDoctype = Color(0xFF6CC7F5);    // <!DOCTYPE>
const Color _tokPunct = Color(0xFF9198A1);      // pontuação/parênteses
const Color _tokKeyword = Color(0xFFFF7B93);    // palavras-chave de controlo
const Color _tokKeywordImport = Color(0xFFFF9E64); // import/export/from
const Color _tokNumber = Color(0xFF79C0FF);     // números
const Color _tokFunction = Color(0xFFDCBDFB);   // nomes de função
const Color _tokType = Color(0xFFFFB454);       // tipos/classes
const Color _tokConstant = Color(0xFF56C7FF);   // true/false/null
const Color _tokOperator = Color(0xFFF97BE0);   // operadores (+, -, =>, etc.)
const Color _tokSelf = Color(0xFFE06C75);       // self/this
const Color _tokDecorator = Color(0xFF9ED072);  // decorators/annotations
const Color _tokBuiltin = Color(0xFF6FE3C4);    // funções nativas (print, len, etc.)
const Color _tokProperty = Color(0xFF7EE7FC);   // propriedades de objeto (obj.prop)

class AiCodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final AppColorScheme s;

  const AiCodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.s,
  });

  @override
  State<AiCodeBlock> createState() => _AiCodeBlockState();
}

class _AiCodeBlockState extends State<AiCodeBlock> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  bool get _canPreview {
    final lang = widget.language.toLowerCase();
    return lang == 'html' || lang == 'htm' || lang == 'xml' || lang == 'svg';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _openPreview() {
    if (!_canPreview) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiCodePreviewScreen(
          code: widget.code,
          language: widget.language,
          s: widget.s,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14.5,
      height: 1.7,
      color: const Color(0xFFE8E8E8),
    );

    final codeSpans = _highlightCode(widget.code, widget.language, baseStyle);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        children: [
          _buildCodeBody(codeSpans, baseStyle),
          Positioned(
            top: 12,
            right: 12,
            child: _buildActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBody(List<TextSpan> spans, TextStyle baseStyle) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 48, 18, 20),
          child: SelectableText.rich(
            TextSpan(style: baseStyle, children: spans),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_canPreview) ...[
            _ActionButton(
              svgAsset: 'play.svg',
              color: const Color(0xFF9A9A9A),
              backgroundColor: const Color(0xFF2C2C2C),
              onTap: _openPreview,
            ),
            const SizedBox(width: 4),
          ],
          _ActionButton(
            svgAsset: _copied ? 'check.svg' : 'copy.svg',
            color: _copied ? const Color(0xFF4ADE80) : const Color(0xFF9A9A9A),
            backgroundColor: const Color(0xFF2C2C2C),
            onTap: _copy,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String svgAsset;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.svgAsset,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _hover = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _hover = false),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _hover = false),
      onTap: widget.onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFF383838) : widget.backgroundColor,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: AppIcon(
          widget.svgAsset,
          size: 17,
          color: widget.color,
        ),
      ),
    );
  }
}

List<TextSpan> _highlightCode(String code, String language, TextStyle baseStyle) {
  final lang = language.toLowerCase();

  if (lang == 'html' || lang == 'htm' || lang == 'xml' || lang == 'svg') {
    return _highlightHtml(code, baseStyle);
  }

  final patterns = _patternsForLanguage(lang);
  final lines = code.split('\n');
  final spans = <TextSpan>[];

  for (int i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(TextSpan(text: '\n', style: baseStyle));
    spans.addAll(_highlightLineGeneric(lines[i], patterns, baseStyle));
  }

  return spans;
}

List<TextSpan> _highlightHtml(String code, TextStyle baseStyle) {
  final lines = code.split('\n');
  final spans = <TextSpan>[];

  for (int i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(TextSpan(text: '\n', style: baseStyle));
    spans.addAll(_highlightHtmlLine(lines[i], baseStyle));
  }

  return spans;
}

List<TextSpan> _highlightHtmlLine(String line, TextStyle baseStyle) {
  final spans = <TextSpan>[];

  final commentMatch = RegExp(r'^(\s*)(<!--.*-->)(\s*)$').firstMatch(line);
  if (commentMatch != null) {
    spans.add(TextSpan(text: commentMatch.group(1), style: baseStyle));
    spans.add(TextSpan(
      text: commentMatch.group(2),
      style: baseStyle.copyWith(color: _tokComment, fontStyle: FontStyle.italic),
    ));
    spans.add(TextSpan(text: commentMatch.group(3), style: baseStyle));
    return spans;
  }

  final doctypeMatch = RegExp(r'^(\s*)(<!DOCTYPE[^>]*>)(\s*)$', caseSensitive: false).firstMatch(line);
  if (doctypeMatch != null) {
    spans.add(TextSpan(text: doctypeMatch.group(1), style: baseStyle));
    spans.add(TextSpan(
      text: doctypeMatch.group(2),
      style: baseStyle.copyWith(color: _tokDoctype),
    ));
    spans.add(TextSpan(text: doctypeMatch.group(3), style: baseStyle));
    return spans;
  }

  int i = 0;
  StringBuffer buffer = StringBuffer();

  while (i < line.length) {
    if (line[i] == '<') {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
        buffer.clear();
      }
      int end = line.indexOf('>', i);
      if (end == -1) end = line.length - 1;
      final tagContent = line.substring(i, end + 1);
      spans.addAll(_highlightHtmlTag(tagContent, baseStyle));
      i = end + 1;
    } else {
      buffer.write(line[i]);
      i++;
    }
  }

  if (buffer.isNotEmpty) {
    spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
  }

  return spans;
}

List<TextSpan> _highlightHtmlTag(String tag, TextStyle baseStyle) {
  final spans = <TextSpan>[];
  final isClosing = tag.startsWith('</');
  final innerStart = isClosing ? 2 : 1;
  final innerEnd = tag.endsWith('>') ? tag.length - 1 : tag.length;
  final inner = tag.substring(innerStart, innerEnd);

  final nameMatch = RegExp(r'^([a-zA-Z0-9-]+)').firstMatch(inner);
  final tagName = nameMatch?.group(1) ?? '';
  final restStart = nameMatch != null ? nameMatch.group(0)!.length : 0;
  final rest = inner.substring(restStart);

  spans.add(TextSpan(
    text: isClosing ? '</' : '<',
    style: baseStyle.copyWith(color: _tokPunct),
  ));

  if (tagName.isNotEmpty) {
    spans.add(TextSpan(
      text: tagName,
      style: baseStyle.copyWith(color: _tokTag, fontWeight: FontWeight.w600),
    ));
  }

  final attrRegex = RegExp(r'''([a-zA-Z-]+)(\s*=\s*)("([^"]*)"|'([^']*)')|([a-zA-Z-]+)''');
  int lastIndex = 0;

  for (final m in attrRegex.allMatches(rest)) {
    if (m.start > lastIndex) {
      spans.add(TextSpan(
        text: rest.substring(lastIndex, m.start),
        style: baseStyle.copyWith(color: _tokPunct),
      ));
    }

    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1)!, style: baseStyle.copyWith(color: _tokAttr)));
      spans.add(TextSpan(text: m.group(2)!, style: baseStyle.copyWith(color: _tokPunct)));
      spans.add(TextSpan(text: m.group(3)!, style: baseStyle.copyWith(color: _tokString)));
    } else if (m.group(6) != null) {
      spans.add(TextSpan(text: m.group(6)!, style: baseStyle.copyWith(color: _tokAttr)));
    }
    lastIndex = m.end;
  }

  if (lastIndex < rest.length) {
    spans.add(TextSpan(
      text: rest.substring(lastIndex),
      style: baseStyle.copyWith(color: _tokPunct),
    ));
  }

  spans.add(TextSpan(
    text: tag.endsWith('/>') ? '/>' : '>',
    style: baseStyle.copyWith(color: _tokPunct),
  ));

  return spans;
}

List<TextSpan> _highlightLineGeneric(String line, List<_TokenPattern> patterns, TextStyle baseStyle) {
  final spans = <TextSpan>[];
  int index = 0;

  while (index < line.length) {
    bool matched = false;

    for (final pattern in patterns) {
      final match = pattern.regex.matchAsPrefix(line, index);
      if (match != null && match.group(0)!.isNotEmpty) {
        final text = match.group(0)!;
        spans.add(TextSpan(
          text: text,
          style: baseStyle.copyWith(
            color: pattern.color,
            fontStyle: pattern.fontStyle,
            fontWeight: pattern.fontWeight,
          ),
        ));
        index = match.end;
        matched = true;
        break;
      }
    }

    if (!matched) {
      spans.add(TextSpan(text: line[index], style: baseStyle));
      index++;
    }
  }

  return spans;
}

List<_TokenPattern> _patternsForLanguage(String language) {
  switch (language) {
    case 'dart':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'\\[nrt"\047\\$]'), color: _tokStringEscape),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\bthis\b|\bsuper\b'), color: _tokSelf, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'\b(?:import|export|library|part|show|hide|deferred|as)\b'), color: _tokKeywordImport),
        _TokenPattern(RegExp(r'\b(?:abstract|assert|async|await|break|case|catch|class|const|continue|covariant|default|do|dynamic|else|enum|extends|extension|external|factory|final|finally|for|Function|get|if|implements|in|interface|is|late|mixin|new|null|on|operator|required|rethrow|return|set|static|switch|sync|throw|try|typedef|var|void|while|with|yield)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:int|double|String|bool|List|Map|Set|Object|void|dynamic|Future|Stream|Widget|BuildContext|Duration|Color|Offset|Size|Rect)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\bprint\b(?=\()'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'=>|==|!=|<=|>=|&&|\|\||\?\?|\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'python':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'@[a-zA-Z_][\w.]*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'"""[\s\S]*?"""'), color: _tokString),
        _TokenPattern(RegExp(r"'''[\s\S]*?'''"), color: _tokString),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'\\[nrt"\047\\]'), color: _tokStringEscape),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\bself\b|\bcls\b'), color: _tokSelf, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'\b(?:import|from|as)\b'), color: _tokKeywordImport),
        _TokenPattern(RegExp(r'\b(?:and|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|global|if|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:int|float|str|bool|list|dict|set|tuple|object|bytes|frozenset)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:print|len|range|enumerate|zip|map|filter|sorted|sum|min|max|abs|isinstance|super|open|input|type)\b(?=\()'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'\b(?:True|False|None)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'==|!=|<=|>=|\*\*|//|->|[+\-*/%=<>!&|^~:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'javascript':
    case 'js':
    case 'jsx':
    case 'typescript':
    case 'ts':
    case 'tsx':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'`(?:\\`|[^`])*`'), color: _tokString),
        _TokenPattern(RegExp(r'\\[nrt"\047\\`]'), color: _tokStringEscape),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\bthis\b'), color: _tokSelf, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'\b(?:import|export|from|default)\b'), color: _tokKeywordImport),
        _TokenPattern(RegExp(r'\b(?:var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|new|class|extends|super|typeof|instanceof|in|of|async|await|try|catch|finally|throw|static|get|set|yield|interface|type|enum|implements|public|private|protected|readonly|namespace|declare)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:string|number|boolean|any|void|never|unknown|object|Array|Promise|Map|Set)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:console|Math|JSON|Object|Array|parseInt|parseFloat|setTimeout|setInterval)\b'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b(?:true|false|null|undefined)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_$]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_$]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'=>|===|!==|==|!=|<=|>=|&&|\|\||\?\?|\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'css':
    case 'scss':
      return [
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|s|ms|deg)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'#[0-9a-fA-F]{3,8}\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\.[a-zA-Z_-][\w-]*'), color: _tokFunction),
        _TokenPattern(RegExp(r'#[a-zA-Z_-][\w-]*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'[a-zA-Z-]+(?=\s*:)'), color: _tokAttr),
        _TokenPattern(RegExp(r'\b(?:a|abbr|address|area|article|aside|audio|b|base|bdi|bdo|blockquote|body|br|button|canvas|caption|cite|code|col|colgroup|data|datalist|dd|del|details|dfn|dialog|div|dl|dt|em|embed|fieldset|figcaption|figure|footer|form|h1|h2|h3|h4|h5|h6|head|header|hgroup|hr|html|i|iframe|img|input|ins|kbd|label|legend|li|link|main|map|mark|menu|meta|meter|nav|noscript|object|ol|optgroup|option|output|p|picture|pre|progress|q|rp|rt|ruby|s|samp|script|section|select|slot|small|source|span|strong|style|sub|summary|sup|table|tbody|td|template|textarea|tfoot|th|thead|time|title|tr|track|u|ul|var|video|wbr)\b'), color: _tokTag),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'bash':
    case 'shell':
    case 'sh':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'\$\{?[a-zA-Z_]\w*\}?'), color: _tokProperty),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:if|then|else|elif|fi|for|while|do|done|case|esac|function|export|readonly|local|return|exit)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:echo|printf|source|cd|ls|grep|awk|sed|curl|wget|cat|mkdir|rm|cp|mv|chmod|pip|npm|flutter|dart|git)\b'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'--?[a-zA-Z-]+'), color: _tokAttr),
        _TokenPattern(RegExp(r'[|&;><]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'sql':
      return [
        _TokenPattern(RegExp(r'--[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|DELETE|CREATE|TABLE|ALTER|DROP|INDEX|VIEW|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AS|AND|OR|NOT|NULL|PRIMARY|KEY|FOREIGN|REFERENCES|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|DISTINCT)\b', caseSensitive: false), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:COUNT|SUM|AVG|MIN|MAX|COALESCE|CAST|NOW|CURRENT_DATE)\b', caseSensitive: false), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b(?:int|varchar|char|text|date|datetime|timestamp|decimal|float|double|boolean|bool)\b', caseSensitive: false), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'=|<>|!=|<=|>=|[+\-*/<>]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'markdown':
    case 'md':
      return [
        _TokenPattern(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), color: _tokString),
        _TokenPattern(RegExp(r'(\*\*|__)(.*?)\1'), color: _tokKeyword),
        _TokenPattern(RegExp(r'(\*|_)(.*?)\1'), color: _tokTag),
        _TokenPattern(RegExp(r'^\s{0,3}#{1,6}\s.*$'), color: _tokType),
        _TokenPattern(RegExp(r'^\s{0,3}>.*$'), color: _tokComment),
        _TokenPattern(RegExp(r'`[^`]+`'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    default:
      return [
        _TokenPattern(RegExp(r'//[^\n]*|#[^\n]*|/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];
  }
}

// ══════════════════════════════════════════════════════════════
// TELA DE PREVIEW SEPARADA
// ══════════════════════════════════════════════════════════════

class AiCodePreviewScreen extends StatelessWidget {
  final String code;
  final String language;
  final AppColorScheme s;

  const AiCodePreviewScreen({
    super.key,
    required this.code,
    required this.language,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          language.isEmpty ? 'Preview' : 'Preview · $language',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
        leading: IconButton(
          icon: const AppIcon('back.svg', color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: code,
          mimeType: 'text/html',
          baseUrl: WebUri('about:blank'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          supportZoom: false,
          transparentBackground: false,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
      ),
    );
  }
}