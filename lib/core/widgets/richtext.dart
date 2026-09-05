import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../theme/colors.dart';
import '../../features/ai_widgets/ai_widgets.dart' show buildAiTableFromWidgetJson, buildAiWidget;
import '../../features/ai_widgets/ai_widgets_shared.dart' show parseAiWidgetBlocks;
import 'widgets.dart';
import '../navigation/app_page_route.dart';

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
  r'\cdot': '·', r'\ast': '∗', r'\star': '⋆', r'\circ': '∘',
  r'\bullet': '•', r'\oplus': '⊕', r'\otimes': '⊗', r'\ominus': '⊖',
  r'\odot': '⊙', r'\oslash': '⊘', r'\uplus': '⊎',
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\sim': '∼', r'\simeq': '≃', r'\cong': '≅', r'\propto': '∝',
  r'\ll': '≪', r'\gg': '≫', r'\prec': '≺', r'\succ': '≻',
  r'\preceq': '≼', r'\succeq': '≽', r'\subset': '⊂', r'\subseteq': '⊆',
  r'\supset': '⊃', r'\supseteq': '⊇', r'\in': '∈', r'\notin': '∉',
  r'\ni': '∋', r'\not\ni': '∌', r'\mid': '∣', r'\nmid': '∤',
  r'\parallel': '∥', r'\nparallel': '∦', r'\perp': '⊥',
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
  r'\forall': '∀', r'\exists': '∃', r'\nexists': '∄',
  r'\neg': '¬', r'\lnot': '¬', r'\land': '∧', r'\wedge': '∧',
  r'\lor': '∨', r'\vee': '∨', r'\top': '⊤', r'\bot': '⊥',
  r'\emptyset': '∅', r'\varnothing': '∅', r'\cup': '∪', r'\cap': '∩',
  r'\setminus': '∖', r'\complement': '∁',
  r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇', r'\hbar': 'ℏ',
  r'\ell': 'ℓ', r'\imath': 'ı', r'\jmath': 'ȷ',
  r'\int': '∫', r'\iint': '∬', r'\iiint': '∭', r'\oint': '∮',
  r'\sum': '∑', r'\prod': '∏', r'\coprod': '∐',
  r'\angle': '∠', r'\measuredangle': '∡', r'\sphericalangle': '∢',
  r'\degree': '°', r'\prime': '′', r'\backprime': '‵',
  r'\therefore': '∴', r'\because': '∵', r'\cdots': '⋯',
  r'\ldots': '…', r'\vdots': '⋮', r'\ddots': '⋱', r'\iddots': '⋰',
  r'\implies': '⟹', r'\impliedby': '⟸', r'\iff': '⟺',
  r'\mathbb{R}': 'ℝ', r'\mathbb{N}': 'ℕ', r'\mathbb{Z}': 'ℤ',
  r'\mathbb{Q}': 'ℚ', r'\mathbb{C}': 'ℂ', r'\mathbb{H}': 'ℍ',
  r'\mathbb{O}': '𝕆',
  r'\lvert': '|', r'\rvert': '|', r'\lVert': '‖', r'\rVert': '‖',
  r'\langle': '⟨', r'\rangle': '⟩', r'\lceil': '⌈', r'\rceil': '⌉',
  r'\lfloor': '⌊', r'\rfloor': '⌋', r'\lbrace': '{', r'\rbrace': '}',
  r'\hat': '', r'\bar': '', r'\vec': '', r'\dot': '', r'\ddot': '',
  r'\tilde': '', r'\overline': '', r'\underline': '', r'\boxed': '',
  r'\square': '□', r'\blacksquare': '■', r'\triangle': '△',
  r'\bigtriangleup': '△', r'\bigtriangledown': '▽', r'\lozenge': '◊',
  r'\diamond': '◆', r'\clubsuit': '♣', r'\diamondsuit': '♦',
  r'\heartsuit': '♥', r'\spadesuit': '♠',
};

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

const Map<String, String> kEmojiShortcodes = {};

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

class _MathBinom extends _MathAtom {
  final String top;
  final String bottom;
  _MathBinom(this.top, this.bottom);
}

class _MathOverbrace extends _MathAtom {
  final String content;
  final String? annotation;
  _MathOverbrace(this.content, {this.annotation});
}

class _MathUnderbrace extends _MathAtom {
  final String content;
  final String? annotation;
  _MathUnderbrace(this.content, {this.annotation});
}

class _MathXArrow extends _MathAtom {
  final String direction;
  final String content;
  final String label;
  _MathXArrow(this.direction, this.content, this.label);
}

class _MathOverset extends _MathAtom {
  final String label;
  final String content;
  _MathOverset(this.label, this.content);
}

class _MathUnderset extends _MathAtom {
  final String label;
  final String content;
  _MathUnderset(this.label, this.content);
}

class _MathLimits extends _MathAtom {
  final String? sub;
  final String? sup;
  final String symbol;
  _MathLimits(this.symbol, {this.sub, this.sup});
}

class _MathNot extends _MathAtom {
  final String content;
  _MathNot(this.content);
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
    (m) => '\u0006COLOR{${m.group(1)}}{${m.group(2)}}\u0006',
  );
  result = result.replaceAllMapped(
    RegExp(r'\\textcolor\{([^{}]+)\}\{([^{}]+)\}'),
    (m) => '\u0006COLOR{${m.group(1)}}{${m.group(2)}}\u0006',
  );

  for (final acc in ['hat', 'bar', 'vec', 'dot', 'ddot', 'tilde']) {
    result = result.replaceAllMapped(
      RegExp(r'\\' + acc + r'\{([^{}]+)\}'),
      (m) => '\u0007ACC{$acc}{${m.group(1)}}\u0007',
    );
  }

  result = result.replaceAllMapped(
    RegExp(r'\\not\s*(\S)'),
    (m) => '\u0008NOT{${m.group(1)}}\u0008',
  );

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
    r'|\\binom\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\overbrace\{([^{}]+)\}\^?\{?([^{}]*)\}?'
    r'|\\underbrace\{([^{}]+)\}_?\{?([^{}]*)\}?'
    r'|\\overset\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\underset\{([^{}]+)\}\{([^{}]+)\}'
    r'|\\xrightarrow\s*(?:\[([^\]]*)\])?\{([^{}]+)\}'
    r'|\\xleftarrow\s*(?:\[([^\]]*)\])?\{([^{}]+)\}'
    r'|\\sum\\limits_\{([^{}]+)\}\^\{([^{}]+)\}'
    r'|\\sum\\limits\^\{([^{}]+)\}_\{([^{}]+)\}'
    r'|\\sum\\limits_\{([^{}]+)\}'
    r'|\\sum\\limits\^\{([^{}]+)\}'
    r'|\\prod\\limits_\{([^{}]+)\}\^\{([^{}]+)\}'
    r'|\\prod\\limits\^\{([^{}]+)\}_\{([^{}]+)\}'
    r'|\\prod\\limits_\{([^{}]+)\}'
    r'|\\prod\\limits\^\{([^{}]+)\}'
    r'|\\int\\limits_\{([^{}]+)\}\^\{([^{}]+)\}'
    r'|\\int\\limits\^\{([^{}]+)\}_\{([^{}]+)\}'
    r'|\\int\\limits_\{([^{}]+)\}'
    r'|\\int\\limits\^\{([^{}]+)\}'
    r'|\u0004OVERLINE\{([^{}]+)\}\u0004'
    r'|\u0004UNDERLINE\{([^{}]+)\}\u0004'
    r'|\u0005BOXED\{([^{}]+)\}\u0005'
    r'|\u0006COLOR\{([^{}]+)\}\{([^{}]+)\}\u0006'
    r'|\u0007ACC\{([^{}]+)\}\{([^{}]+)\}\u0007'
    r'|\u0008NOT\{([^{}]+)\}\u0008'
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
    } else if (match.startsWith(r'\binom')) {
      atoms.add(_MathBinom(m.group(6)!, m.group(7)!));
    } else if (match.startsWith(r'\overbrace')) {
      atoms.add(_MathOverbrace(m.group(8)!, annotation: m.group(9)?.isEmpty ?? true ? null : m.group(9)));
    } else if (match.startsWith(r'\underbrace')) {
      atoms.add(_MathUnderbrace(m.group(10)!, annotation: m.group(11)?.isEmpty ?? true ? null : m.group(11)));
    } else if (match.startsWith(r'\overset')) {
      atoms.add(_MathOverset(m.group(12)!, m.group(13)!));
    } else if (match.startsWith(r'\underset')) {
      atoms.add(_MathUnderset(m.group(14)!, m.group(15)!));
    } else if (match.startsWith(r'\xrightarrow')) {
      atoms.add(_MathXArrow('right', m.group(16)!, m.group(17)!));
    } else if (match.startsWith(r'\xleftarrow')) {
      atoms.add(_MathXArrow('left', m.group(18)!, m.group(19)!));
    } else if (match.startsWith(r'\sum')) {
      final sub = m.group(20) ?? m.group(22) ?? m.group(24) ?? m.group(26);
      final sup = m.group(21) ?? m.group(23) ?? m.group(25) ?? m.group(27);
      atoms.add(_MathLimits('∑', sub: sub, sup: sup));
    } else if (match.startsWith(r'\prod')) {
      final sub = m.group(28) ?? m.group(30) ?? m.group(32) ?? m.group(34);
      final sup = m.group(29) ?? m.group(31) ?? m.group(33) ?? m.group(35);
      atoms.add(_MathLimits('∏', sub: sub, sup: sup));
    } else if (match.startsWith(r'\int')) {
      final sub = m.group(36) ?? m.group(38) ?? m.group(40) ?? m.group(42);
      final sup = m.group(37) ?? m.group(39) ?? m.group(41) ?? m.group(43);
      atoms.add(_MathLimits('∫', sub: sub, sup: sup));
    } else if (match.startsWith('\u0004OVERLINE')) {
      atoms.add(_MathOverline(m.group(44)!));
    } else if (match.startsWith('\u0004UNDERLINE')) {
      atoms.add(_MathUnderline(m.group(45)!));
    } else if (match.startsWith('\u0005BOXED')) {
      atoms.add(_MathBoxed(m.group(46)!));
    } else if (match.startsWith('\u0006COLOR')) {
      atoms.add(_MathColor(m.group(47)!, m.group(48)!));
    } else if (match.startsWith('\u0007ACC')) {
      atoms.add(_MathAccent(m.group(49)!, m.group(50)!));
    } else if (match.startsWith('\u0008NOT')) {
      atoms.add(_MathNot(m.group(51)!));
    } else if (match.startsWith('\u0003OVER')) {
      atoms.add(_MathArrow('over', m.group(52)!));
    } else if (match.startsWith('\u0003UNDER')) {
      atoms.add(_MathArrow('under', m.group(53)!));
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
    r'\u0002(?:TXT|BF|IT|SF|TT)\{([^{}]+)\}\u0002',
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
    final baseFontSize = block ? 17.0 : 15.5;
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
        case _MathBinom(:final top, :final bottom):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('(', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(top, style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
                    Text(bottom, style: baseStyle.copyWith(fontSize: baseFontSize * 0.82)),
                  ],
                ),
                Text(')', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
              ],
            ),
          ));
        case _MathOverbrace(:final content, :final annotation):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (annotation != null)
                Text(annotation, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
              Text('⏞', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
              Text(content, style: baseStyle),
            ],
          ));
        case _MathUnderbrace(:final content, :final annotation):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content, style: baseStyle),
              Text('⏟', style: baseStyle.copyWith(fontSize: baseFontSize * 1.2)),
              if (annotation != null)
                Text(annotation, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
            ],
          ));
        case _MathXArrow(:final direction, :final content, :final label):
          rowChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.isEmpty
                    ? (direction == 'left' ? '⟵' : '⟶')
                    : label,
                  style: baseStyle.copyWith(fontSize: baseFontSize * 0.75)),
                Text(content, style: baseStyle),
              ],
            ),
          ));
        case _MathOverset(:final label, :final content):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
              Text(content, style: baseStyle),
            ],
          ));
        case _MathUnderset(:final label, :final content):
          rowChildren.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content, style: baseStyle),
              Text(label, style: baseStyle.copyWith(fontSize: baseFontSize * 0.7)),
            ],
          ));
        case _MathLimits(:final symbol, :final sub, :final sup):
          rowChildren.add(Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (sup != null)
                Text(sup, style: baseStyle.copyWith(fontSize: baseFontSize * 0.65)),
              Text(symbol, style: baseStyle.copyWith(fontSize: baseFontSize * 1.3)),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Text(sub, style: baseStyle.copyWith(fontSize: baseFontSize * 0.65)),
                ),
            ],
          ));
        case _MathNot(:final content):
          rowChildren.add(Stack(
            alignment: Alignment.center,
            children: [
              Text(content, style: baseStyle),
              Container(
                width: content.length * baseFontSize * 0.5,
                height: 1.2,
                color: s.onSurface,
                transform: Matrix4.skewY(-0.3),
              ),
            ],
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

class MathBlockParseResult {
  final String textWithMarkers;
  final List<String> blocks;
  const MathBlockParseResult({required this.textWithMarkers, required this.blocks});
}

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

class _RichTextBlockParser {
  static List<Widget> parse(String raw, AppColorScheme s) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final mathExtract = _extractMathBlocks(normalized);
    if (mathExtract.blocks.isEmpty) {
      return _parseStructural(normalized, s);
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
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MathInline(expression: mathExtract.blocks[idx], s: s, block: true),
        ));
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
    List<TextAlign>? tableAlignments;

    void flushTable() {
      if (tableRows != null && tableRows!.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Container(
            color: s.pageBackground,
            child: _AiTable(
              rows: tableRows!,
              s: s,
              alignments: tableAlignments,
            ),
          ),
        ));
      }
      tableRows = null;
      tableAlignments = null;
    }

    bool isFence(String value) => RegExp(r'^\s*(```+|~~~+)').hasMatch(value);

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        flushTable();
        if (widgets.isNotEmpty && widgets.last is! SizedBox) {
          widgets.add(const SizedBox(height: 5));
        }
        i++;
        continue;
      }

      if (RegExp(r'^<details>\s*$').hasMatch(trimmed) ||
          trimmed.startsWith('<details>')) {
        flushTable();
        final detailLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('</details>')) {
          detailLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++;
        widgets.add(_buildDetailsBlock(detailLines.join('\n'), s));
        continue;
      }

      final headerMatch = RegExp(r'^\s*(#{1,6})\s+(.*?)(?:\s+#+)?$').firstMatch(line);
      if (headerMatch != null) {
        flushTable();
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!.trim();
        widgets.add(Padding(
          padding: EdgeInsets.only(
            top: widgets.isEmpty ? 0 : (level <= 2 ? 11 : 7),
            bottom: level <= 2 ? 6 : 4,
          ),
          child: _formattedText(
            content,
            s,
            fontSize: switch (level) {
              1 => 22,
              2 => 19,
              3 => 17.5,
              4 => 16.5,
              5 => 15.75,
              _ => 15.25,
            },
            fontWeight: FontWeight.w700,
          ),
        ));
        i++;
        continue;
      }

      if (i + 1 < lines.length && trimmed.isNotEmpty) {
        final next = lines[i + 1].trim();
        final isH1 = RegExp(r'^={3,}$').hasMatch(next);
        final isH2 = RegExp(r'^-{3,}$').hasMatch(next);
        if ((isH1 || isH2) &&
            !trimmed.startsWith('-') &&
            !trimmed.startsWith('*') &&
            !trimmed.startsWith('+') &&
            !trimmed.startsWith('>')) {
          flushTable();
          widgets.add(Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 10, bottom: 5),
            child: _formattedText(
              trimmed,
              s,
              fontSize: isH1 ? 21 : 18,
              fontWeight: FontWeight.w700,
            ),
          ));
          i += 2;
          continue;
        }
      }

      if (RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$').hasMatch(line)) {
        flushTable();
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, thickness: 1),
        ));
        i++;
        continue;
      }

      final tableCandidate = _splitTableRow(trimmed);
      final isLastLine = i == lines.length - 1;
      if (tableCandidate != null) {
        final nextRow = i + 1 < lines.length ? _splitTableRow(lines[i + 1].trim()) : null;
        final looksLikeHeader = nextRow != null && _isTableSeparatorRow(nextRow);
        if (looksLikeHeader || tableRows != null) {
          // Se esta é a última linha do texto recebido até agora e ainda
          // não fecha com '|' no fim, a linha pode estar a meio de chegar
          // via streaming — não adiciona à tabela ainda, para não forçar
          // o Table a rebuilder incompleto (o que expõe o fundo por trás
          // durante um frame, criando o flash cinza).
          final rowIncomplete = isLastLine && !trimmed.endsWith('|');
          if (rowIncomplete) {
            i++;
            continue;
          }
          if (looksLikeHeader) {
            tableRows ??= [];
            tableRows!.add(tableCandidate);
            tableAlignments = _parseTableAlignments(nextRow!);
            i += 2;
          } else if (!_isTableSeparatorRow(tableCandidate)) {
            tableRows ??= [];
            tableRows!.add(tableCandidate);
            i++;
          } else {
            i++;
          }
          continue;
        }
      }
      if (tableRows != null) flushTable();

      if (isFence(trimmed)) {
        final fence = RegExp(r'^(```+|~~~+)').firstMatch(trimmed)!;
        final marker = fence.group(1)!;
        final info = trimmed.substring(fence.end).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length) {
          final candidate = lines[i].trimLeft();
          if (candidate.startsWith(marker)) break;
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++;
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AiCodeBlock(
            code: codeLines.join('\n'),
            language: info.isEmpty ? 'text' : info.split(RegExp(r'\s+')).first,
            s: s,
          ),
        ));
        continue;
      }

      if (RegExp(r'^(?: {4}|\t)').hasMatch(line)) {
        final codeLines = <String>[];
        while (i < lines.length) {
          final current = lines[i];
          if (current.trim().isEmpty) {
            codeLines.add('');
            i++;
            continue;
          }
          if (!RegExp(r'^(?: {4}|\t)').hasMatch(current)) break;
          codeLines.add(current.startsWith('\t')
              ? current.substring(1)
              : current.substring(current.length >= 4 ? 4 : current.length));
          i++;
        }
        while (codeLines.isNotEmpty && codeLines.last.isEmpty) {
          codeLines.removeLast();
        }
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AiCodeBlock(code: codeLines.join('\n'), language: 'text', s: s),
        ));
        continue;
      }

      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        String? admonitionType;
        bool firstLine = true;

        while (i < lines.length) {
          final currentTrimmed = lines[i].trim();
          if (!currentTrimmed.startsWith('>')) break;

          var content = currentTrimmed.replaceFirst(RegExp(r'^>\s?'), '');
          if (firstLine) {
            final tagMatch = RegExp(
              r'^\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION|INFO|SUCCESS|QUESTION)\]\s*',
              caseSensitive: false,
            ).firstMatch(content);
            if (tagMatch != null) {
              admonitionType = tagMatch.group(1)!.toUpperCase();
              content = content.substring(tagMatch.end);
            }
            firstLine = false;
          }
          quoteLines.add(content);
          i++;
        }

        final quoteText = quoteLines.join('\n').trim();
        final label = admonitionType == null ? null : _admonitionLabel(admonitionType!);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                    color: s.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (label != null) ...[
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: s.onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      _formattedText(quoteText, s),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
        continue;
      }

      final listMatch = RegExp(
        r'^(\s*)([-+*]|\d+[.)]|[a-zA-Z][.)])\s+(?:\[([ xX])\]\s+)?(.*)$',
      ).firstMatch(line);
      if (listMatch != null) {
        flushTable();
        final rendered = <Widget>[];

        while (i < lines.length) {
          final current = lines[i];
          final match = RegExp(
            r'^(\s*)([-+*]|\d+[.)]|[a-zA-Z][.)])\s+(?:\[([ xX])\]\s+)?(.*)$',
          ).firstMatch(current);
          if (match == null) break;

          final indent = match.group(1)!.replaceAll('\t', '    ').length;
          final marker = match.group(2)!;
          final checked = match.group(3);
          final content = match.group(4)!;
          final left = (indent ~/ 2) * 16.0;
          final isOrdered = RegExp(r'^(?:\d+[.)]|[a-zA-Z][.)])$').hasMatch(marker);
          final markerText = isOrdered ? marker : null;

          rendered.add(Padding(
            padding: EdgeInsets.only(left: left, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: checked != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: AppIcon(
                            checked.toLowerCase() == 'x'
                                ? 'check_box.svg'
                                : 'check_box_outline_blank.svg',
                            size: 16,
                            color: checked.toLowerCase() == 'x'
                                ? s.primary
                                : s.onSurfaceVariant,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: markerText == null
                              ? Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(top: 7, left: 4),
                                  decoration: BoxDecoration(
                                    color: s.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : Text(
                                  markerText,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: s.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                ),
                Expanded(
                  child: _formattedText(
                    content,
                    s,
                    fontWeight: checked?.toLowerCase() == 'x' ? FontWeight.normal : null,
                  ),
                ),
              ],
            ),
          ));
          i++;
        }

        widgets.addAll(rendered);
        continue;
      }

      if (i + 1 < lines.length && trimmed.isNotEmpty && lines[i + 1].trimLeft().startsWith(':')) {
        flushTable();
        final term = trimmed;
        i++;
        final defs = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith(':')) {
          defs.add(lines[i].trimLeft().substring(1).trim());
          i++;
        }
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _formattedText(term, s, fontWeight: FontWeight.w700),
              for (final def in defs)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: _formattedText(def, s),
                ),
            ],
          ),
        ));
        continue;
      }

      final hardBreak = RegExp(r'(?: {2,}|\\)$').hasMatch(line);
      final content = hardBreak
          ? line.replaceFirst(RegExp(r'(?: {2,}|\\)$'), '')
          : trimmed;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _formattedText(content, s, forceLineBreak: hardBreak),
      ));
      i++;
    }

    flushTable();
    return widgets;
  }

  static Widget _buildDetailsBlock(String content, AppColorScheme s) {
    String summary = 'Detalhes';
    var body = content;
    final summaryMatch = RegExp(r'<summary>(.*?)</summary>', dotAll: true).firstMatch(content);
    if (summaryMatch != null) {
      summary = summaryMatch.group(1)!.trim();
      body = content.replaceRange(summaryMatch.start, summaryMatch.end, '').trim();
    }
    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: ExpansionTile(
        title: Text(summary, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: s.onSurface)),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: s.onSurfaceVariant,
        collapsedIconColor: s.onSurfaceVariant,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _formattedText(body, s),
          ),
        ],
      ),
    );
  }

  static List<String>? _splitTableRow(String line) {
    if (!line.contains('|')) return null;
    final value = line.trim();
    if (!(value.startsWith('|') || value.endsWith('|'))) return null;

    var body = value;
    if (body.startsWith('|')) body = body.substring(1);
    if (body.endsWith('|')) body = body.substring(0, body.length - 1);

    final cells = <String>[];
    final current = StringBuffer();
    bool escaped = false;
    for (final char in body.split('')) {
      if (escaped) {
        current.write(char);
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '|') {
        cells.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    if (escaped) current.write('\\');
    cells.add(current.toString().trim());
    return cells;
  }

  static bool _isTableSeparatorRow(List<String> row) {
    if (row.isEmpty) return false;
    return row.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.trim()));
  }

  static List<TextAlign>? _parseTableAlignments(List<String> separatorRow) {
    final alignments = <TextAlign>[];
    for (final cell in separatorRow) {
      final t = cell.trim();
      if (t.startsWith(':') && t.endsWith(':')) {
        alignments.add(TextAlign.center);
      } else if (t.endsWith(':')) {
        alignments.add(TextAlign.right);
      } else {
        alignments.add(TextAlign.left);
      }
    }
    return alignments;
  }

  static String _admonitionLabel(String type) => switch (type) {
        'NOTE' => 'Nota',
        'TIP' => 'Dica',
        'IMPORTANT' => 'Importante',
        'WARNING' => 'Aviso',
        'CAUTION' => 'Cuidado',
        'INFO' => 'Informação',
        'SUCCESS' => 'Sucesso',
        'QUESTION' => 'Questão',
        _ => 'Nota',
      };

  static List<InlineSpan> inlineSpans(
    String raw,
    AppColorScheme s, {
    double fontSize = 15.5,
    bool forceLineBreak = false,
  }) {
    final processed = _normalizeInlineMarkdown(raw);
    final spans = <InlineSpan>[];

    final pattern = RegExp(
      r'(\$\$[^$\n]+?\$\$)|'
      r'(\$[^$\n]+?\$)|'
      r'(!?\[[^\]\n]+\]\([^\)\n]+(?:\s+[\x22\x27][^\x22\x27]*[\x22\x27])?\))|'
      r'(\*\*\*[^*\n]+?\*\*\*)|'
      r'(\*\*[^*\n]+?\*\*|__[^_\n]+?__)|'
      r'(~~[^~\n]+?~~)|'
      r'(\*[^*\n]+?\*|_[^_\n]+?_)|'
      r'(==[^=\n]+?==)|'
      r'(\+\+[^+\n]+?\+\+)|'
      r'(<sup>[^<]+</sup>)|'
      r'(<sub>[^<]+</sub>)|'
      r'(```[^`\n]*```)|'
      r'(`[^`\n]+?`)|'
      r'(\^\([^\)\n]+\)|\^\w+)|'
      r'(\~\([^\)\n]+\)|\~\w+)|'
      r'(https?://[^\s<>]+)|'
      r'(?<=\s|^)([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})(?=\s|$)|'
      r'(<br\s*/?>)|'
      r'(\\)$',
      multiLine: true,
    );

    int last = 0;
    for (final m in pattern.allMatches(processed)) {
      if (m.start > last) {
        spans.add(TextSpan(text: _unescapeInline(processed.substring(last, m.start))));
      }

      final token = m.group(0)!;
      if (token.startsWith('\$\$') && token.endsWith('\$\$')) {
        final expr = token.substring(2, token.length - 2);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MathInline(expression: expr, s: s, block: false),
        ));
      } else if (token.startsWith(r'$')) {
        final expr = token.substring(1, token.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MathInline(expression: expr, s: s, block: false),
        ));
      } else if (token.startsWith('![')) {
        final match = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)').firstMatch(token);
        if (match != null) {
          spans.add(TextSpan(text: match.group(1)!.isEmpty ? 'imagem' : match.group(1)!));
        }
      } else if (token.startsWith('[')) {
        final match = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)').firstMatch(token);
        if (match != null) {
          final label = match.group(1)!;
          final url = match.group(2)!;
          spans.add(TextSpan(
            text: label,
            style: const TextStyle(decoration: TextDecoration.underline),
            recognizer: null,
            semanticsLabel: '$label — $url',
          ));
        }
      } else if (token.startsWith('***')) {
        spans.add(TextSpan(
          text: token.substring(3, token.length - 3),
          style: const TextStyle(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
        ));
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(TextSpan(
          text: _unescapeInline(token.substring(2, token.length - 2)),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (token.startsWith('~~')) {
        spans.add(TextSpan(
          text: _unescapeInline(token.substring(2, token.length - 2)),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ));
      } else if (token.startsWith('==')) {
        spans.add(TextSpan(text: token.substring(2, token.length - 2)));
      } else if (token.startsWith('++')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(decoration: TextDecoration.underline),
        ));
      } else if (token.startsWith('<sup>')) {
        final value = token.substring(5, token.length - 6);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Transform.translate(
            offset: Offset(0, -fontSize * 0.35),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('<sub>')) {
        final value = token.substring(5, token.length - 6);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Transform.translate(
            offset: Offset(0, fontSize * 0.12),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('```')) {
        spans.add(TextSpan(
          text: token.substring(3, token.length - 3),
          style: const TextStyle(fontFamily: 'monospace'),
        ));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
          text: _unescapeInline(token.substring(1, token.length - 1)),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: s.hover, fontSize: fontSize - 1),
        ));
      } else if (token.startsWith('^')) {
        final value = token.startsWith('^(')
            ? token.substring(2, token.length - 1)
            : token.substring(1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Transform.translate(
            offset: Offset(0, -fontSize * 0.35),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('~')) {
        final value = token.startsWith('~(')
            ? token.substring(2, token.length - 1)
            : token.substring(1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Transform.translate(
            offset: Offset(0, fontSize * 0.12),
            child: Text(value, style: TextStyle(fontSize: fontSize * 0.7, height: 1.0)),
          ),
        ));
      } else if (token.startsWith('http://') || token.startsWith('https://')) {
        spans.add(TextSpan(
          text: token,
          style: const TextStyle(decoration: TextDecoration.underline),
          semanticsLabel: token,
        ));
      } else if (token.startsWith('<br')) {
        spans.add(const TextSpan(text: '\n'));
      } else if (token == r'\\') {
        spans.add(const TextSpan(text: '\n'));
      } else if (token.startsWith('*') || token.startsWith('_')) {
        spans.add(TextSpan(
          text: _unescapeInline(token.substring(1, token.length - 1)),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (token.contains('@')) {
        spans.add(TextSpan(
          text: token,
          style: const TextStyle(decoration: TextDecoration.underline),
        ));
      }
      last = m.end;
    }

    if (last < processed.length) {
      spans.add(TextSpan(text: _unescapeInline(processed.substring(last))));
    }
    if (forceLineBreak) spans.add(const TextSpan(text: '\n'));
    return spans;
  }

  static String _normalizeInlineMarkdown(String value) {
    var result = value.replaceAll('\u200B', '');
    kEmojiShortcodes.forEach((code, replacement) {
      result = result.replaceAll(code, replacement);
    });
    return result;
  }

  static String _unescapeInline(String value) {
    return value.replaceAllMapped(RegExp(r'\\([\\`*_[\]{}()#+.!|>~-])'), (m) => m.group(1)!);
  }

  static Widget _formattedText(
    String raw,
    AppColorScheme s, {
    double fontSize = 15.5,
    FontWeight? fontWeight,
    bool forceLineBreak = false,
  }) {
    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          color: s.onSurface,
          fontSize: fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          height: 1.45,
        ),
        children: inlineSpans(
          raw,
          s,
          fontSize: fontSize,
          forceLineBreak: forceLineBreak,
        ),
      ),
    );
  }
}

class _AiTable extends StatelessWidget {
  final List<List<String>> rows;
  final AppColorScheme s;
  final List<TextAlign>? alignments;

  const _AiTable({
    required this.rows,
    required this.s,
    this.alignments,
  });

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
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Align(
                          alignment: _alignmentFor(e.key, alignments),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: s.onSurface),
                              children: _RichTextBlockParser.inlineSpans(
                                  e.value, s, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            for (final row in body)
              TableRow(
                children: row
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Align(
                            alignment: _alignmentFor(e.key, alignments),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 13.5, color: s.onSurface),
                                children: _RichTextBlockParser.inlineSpans(
                                    e.value, s, fontSize: 13.5),
                              ),
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

  Alignment _alignmentFor(int colIndex, List<TextAlign>? alignments) {
    if (alignments != null && colIndex < alignments.length) {
      switch (alignments[colIndex]) {
        case TextAlign.center: return Alignment.center;
        case TextAlign.right: return Alignment.centerRight;
        default: return Alignment.centerLeft;
      }
    }
    return Alignment.centerLeft;
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

class _TokenPattern {
  final RegExp regex;
  final Color? color;
  final FontStyle? fontStyle;
  final FontWeight? fontWeight;

  const _TokenPattern(this.regex, {this.color, this.fontStyle, this.fontWeight});
}

const Color _tokTag = Color(0xFFFF6BB3);
const Color _tokAttr = Color(0xFF9CDCFE);
const Color _tokString = Color(0xFFE3B341);
const Color _tokStringEscape = Color(0xFFFFD866);
const Color _tokComment = Color(0xFF6A737D);
const Color _tokDoctype = Color(0xFF6CC7F5);
const Color _tokPunct = Color(0xFF9198A1);
const Color _tokKeyword = Color(0xFFFF7B93);
const Color _tokKeywordImport = Color(0xFFFF9E64);
const Color _tokNumber = Color(0xFF79C0FF);
const Color _tokFunction = Color(0xFFDCBDFB);
const Color _tokType = Color(0xFFFFB454);
const Color _tokConstant = Color(0xFF56C7FF);
const Color _tokOperator = Color(0xFFF97BE0);
const Color _tokSelf = Color(0xFFE06C75);
const Color _tokDecorator = Color(0xFF9ED072);
const Color _tokBuiltin = Color(0xFF6FE3C4);
const Color _tokProperty = Color(0xFF7EE7FC);

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
      AppPageRoute(
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
      fontSize: 15.0,
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
  final styleBlockPattern = RegExp(r'<style[^>]*>([\s\S]*?)</style>', caseSensitive: false);
  if (styleBlockPattern.hasMatch(code)) {
    return _highlightHtmlWithCss(code, baseStyle);
  }

  final lines = code.split('\n');
  final spans = <TextSpan>[];

  for (int i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(TextSpan(text: '\n', style: baseStyle));
    spans.addAll(_highlightHtmlLine(lines[i], baseStyle));
  }

  return spans;
}

List<TextSpan> _highlightHtmlWithCss(String code, TextStyle baseStyle) {
  final spans = <TextSpan>[];
  int last = 0;
  final cssPattern = RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false);
  for (final m in cssPattern.allMatches(code)) {
    if (m.start > last) {
      spans.addAll(_highlightHtmlLine(code.substring(last, m.start), baseStyle));
    }
    final cssContent = code.substring(m.start, m.end);
    final cssInnerMatch = RegExp(r'<style[^>]*>([\s\S]*?)</style>', caseSensitive: false).firstMatch(cssContent);
    if (cssInnerMatch != null) {
      spans.add(TextSpan(
        text: '<style>',
        style: baseStyle.copyWith(color: _tokTag, fontWeight: FontWeight.w600),
      ));
      final cssLines = cssInnerMatch.group(1)!.split('\n');
      for (final line in cssLines) {
        spans.addAll(_highlightLineGeneric(line, _patternsForLanguage('css'), baseStyle));
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
      spans.add(TextSpan(
        text: '</style>',
        style: baseStyle.copyWith(color: _tokTag, fontWeight: FontWeight.w600),
      ));
    } else {
      spans.add(TextSpan(text: cssContent, style: baseStyle));
    }
    last = m.end;
  }
  if (last < code.length) {
    spans.addAll(_highlightHtmlLine(code.substring(last), baseStyle));
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

    case 'go':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'`[^`]*`'), color: _tokString),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:func|package|import|return|if|else|for|range|go|defer|select|case|default|break|continue|switch|type|struct|interface|map|chan|var|const|nil|true|false)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:string|int|float64|bool|byte|rune|error|uint|int8|int16|int32|int64|uint8|uint16|uint32|uint64)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:fmt|len|cap|print|println|append|copy|make|new)\b'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'==|!=|<=|>=|:=|\+\+|--|[+\-*/%=<>!&|^~]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'rust':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'#\[[^\]]+\]'), color: _tokDecorator),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:fn|let|mut|const|static|if|else|for|while|loop|match|return|impl|trait|struct|enum|pub|use|mod|self|super|crate|where|async|await)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:u8|u16|u32|u64|usize|i8|i16|i32|i64|isize|f32|f64|bool|String|Vec|Option|Result|Box|HashMap)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:println|print|format|vec|panic|assert|Some|None|Ok|Err)\b'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'=>|==|!=|<=|>=|::|\+\+|--|[+\-*/%=<>!&|^~]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'kotlin':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:fun|val|var|class|object|interface|enum|data|sealed|if|else|for|while|do|return|when|in|is|as|new|this|super|companion|init|constructor)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:String|Int|Double|Boolean|Float|Long|Short|Byte|Char|Unit|Any|List|Map|Set)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:print|println|require|assert|run|let|apply|also|with)\b'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\?\?|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'swift':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:func|var|let|class|struct|enum|protocol|extension|if|else|for|while|repeat|return|guard|switch|case|default|break|continue|import|init|self|super|where|as|is|try|catch|throw)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:String|Int|Double|Bool|Float|Character|Array|Dictionary|Set|Optional|Any)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:print|assert|map|filter|reduce|first|last|append|count)\b'), color: _tokBuiltin),
        _TokenPattern(RegExp(r'\b(?:true|false|nil)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'c':
    case 'cpp':
    case 'c++':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])'"), color: _tokString),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:int|float|double|char|void|bool|auto|long|short|unsigned|signed|size_t|uint8_t|uint16_t|uint32_t|uint64_t|int8_t|int16_t|int32_t|int64_t)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:if|else|for|while|do|return|break|continue|switch|case|default|goto|typedef|struct|union|enum|static|const|volatile|extern|inline|sizeof|new|delete|this|class|namespace|using|template|typename)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:true|false|null|NULL|nullptr)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'csharp':
    case 'cs':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:int|long|short|byte|float|double|decimal|char|string|bool|void|object|var|dynamic)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:if|else|for|while|do|return|break|continue|switch|case|default|goto|class|struct|enum|interface|namespace|using|public|private|protected|internal|static|readonly|const|virtual|override|abstract|sealed|async|await|try|catch|finally|throw|new|this|base|is|as|in|out|ref)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'=>|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'java':
      return [
        _TokenPattern(RegExp(r'//[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'/\*.*?\*/'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'@[a-zA-Z_]\w*'), color: _tokDecorator),
        _TokenPattern(RegExp(r'\b0[xX][0-9a-fA-F]+\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:int|long|short|byte|float|double|char|boolean|void|String|Object)\b'), color: _tokType, fontWeight: FontWeight.w500),
        _TokenPattern(RegExp(r'\b(?:if|else|for|while|do|return|break|continue|switch|case|default|class|interface|enum|package|import|public|private|protected|static|final|abstract|synchronized|transient|volatile|try|catch|finally|throw|new|this|super|extends|implements|instanceof)\b'), color: _tokKeyword),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\b[A-Z]\w*(?=\()'), color: _tokType),
        _TokenPattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), color: _tokFunction),
        _TokenPattern(RegExp(r'\.[a-zA-Z_]\w*(?!\()'), color: _tokProperty),
        _TokenPattern(RegExp(r'->|==|!=|<=|>=|&&|\|\||\.\.\.|\+\+|--|[+\-*/%=<>!&|^~?:]'), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'json':
      return [
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'[{}[\]\,:]'), color: _tokPunct),
      ];

    case 'yaml':
    case 'yml':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r"'(?:\\.|[^'\\])*'"), color: _tokString),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'[:\-]'), color: _tokPunct),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'toml':
      return [
        _TokenPattern(RegExp(r'#[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\b(?:true|false|null)\b'), color: _tokConstant),
        _TokenPattern(RegExp(r'\[\[?.*?\]\]?'), color: _tokType),
        _TokenPattern(RegExp(r'='), color: _tokOperator),
        _TokenPattern(RegExp(r'[^\s\w]'), color: _tokPunct),
      ];

    case 'ini':
      return [
        _TokenPattern(RegExp(r'#[^\n]*|;[^\n]*'), color: _tokComment, fontStyle: FontStyle.italic),
        _TokenPattern(RegExp(r'"(?:\\.|[^"\\])*"'), color: _tokString),
        _TokenPattern(RegExp(r'\b\d+(?:\.\d+)?\b'), color: _tokNumber),
        _TokenPattern(RegExp(r'\[([^\]]+)\]'), color: _tokType),
        _TokenPattern(RegExp(r'='), color: _tokOperator),
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

class AiCodePreviewScreen extends StatefulWidget {
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
  State<AiCodePreviewScreen> createState() => _AiCodePreviewScreenState();
}

enum _PreviewTab { code, preview }

class _AiCodePreviewScreenState extends State<AiCodePreviewScreen> {
  _PreviewTab _tab = _PreviewTab.preview;

  static const Color _headerColor = Color(0xFF161616);
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const double _concaveRadius = 28;

  Future<void> _share() async {
    await Share.share(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _headerColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              child: Row(
                children: [
                  _RoundIconButton(
                    svgAsset: 'close.svg',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PreviewTabSwitch(
                      value: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    svgAsset: 'share1.svg',
                    onTap: _share,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(_concaveRadius),
                    topRight: Radius.circular(_concaveRadius),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _tab == _PreviewTab.code
                    ? _CodeTabView(code: widget.code, language: widget.language)
                    : _PreviewTabView(code: widget.code),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConcaveBottomClipper extends CustomClipper<Path> {
  final double radius;
  const _ConcaveBottomClipper(this.radius);

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..quadraticBezierTo(
        size.width - radius, size.height - radius,
        size.width - radius * 2, size.height,
      )
      ..lineTo(radius * 2, size.height)
      ..quadraticBezierTo(
        radius, size.height - radius,
        0, size.height,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PreviewTabSwitch extends StatelessWidget {
  final _PreviewTab value;
  final ValueChanged<_PreviewTab> onChanged;
  const _PreviewTabSwitch({required this.value, required this.onChanged});

  static const _options = [
    (_PreviewTab.code, 'Código'),
    (_PreviewTab.preview, 'Pré-visualizar'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _options.indexWhere((o) => o.$1 == value);

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / _options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: segmentWidth * selectedIndex.clamp(0, _options.length - 1),
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF454545),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              for (final (tab, label) in _options)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(tab),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              value == tab ? FontWeight.w700 : FontWeight.w500,
                          color: value == tab
                              ? Colors.white
                              : Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]);
      }),
    );
  }
}

class _RoundIconButton extends StatefulWidget {
  final String svgAsset;
  final VoidCallback onTap;
  const _RoundIconButton({required this.svgAsset, required this.onTap});

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            shape: BoxShape.circle,
          ),
          child: AppIcon(widget.svgAsset, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}

class _CodeTabView extends StatelessWidget {
  final String code;
  final String language;
  const _CodeTabView({required this.code, required this.language});

  @override
  Widget build(BuildContext context) {
    final baseStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 14.5,
      height: 1.7,
      color: Color(0xFF1F1F1F),
    );
    final spans = _highlightCode(code, language, baseStyle);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText.rich(
          TextSpan(style: baseStyle, children: spans),
        ),
      ),
    );
  }
}

class _PreviewTabView extends StatelessWidget {
  final String code;
  const _PreviewTabView({required this.code});

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
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
    );
  }
}