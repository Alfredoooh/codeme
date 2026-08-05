import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// CURVAS
// ══════════════════════════════════════════════════════════════

const Curve kCupertino    = Cubic(0.25, 0.1, 0.25, 1.0);
const Curve kCupertinoIn  = Cubic(0.42, 0.0, 1.0,  1.0);
const Curve kCupertinoOut = Cubic(0.0,  0.0, 0.58, 1.0);

// ══════════════════════════════════════════════════════════════
// CORES
// ══════════════════════════════════════════════════════════════

class AppColorScheme {
  final bool isDark;
  const AppColorScheme(this.isDark);

  Color get primary            => isDark ? const Color(0xFF94BBFF) : const Color(0xFF2F7BF6);
  Color get onPrimary          => isDark ? const Color(0xFF003166) : const Color(0xFFFFFFFF);
  Color get primaryContainer   => isDark ? const Color(0xFF004591) : const Color(0xFFE8F0FF);
  Color get onPrimaryContainer => isDark ? const Color(0xFFD3E4FF) : const Color(0xFF00204D);

  Color get surface            => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
  Color get onSurface          => isDark ? const Color(0xFFEDEDED) : const Color(0xFF111111);
  Color get onSurfaceVariant   => isDark ? const Color(0xFFBBBBBB) : const Color(0xFF555555);

  Color get cardBackground  => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get pageBackground  => isDark ? const Color(0xFF141414) : const Color(0xFFF2F2F7);

  Color get outline        => isDark ? const Color(0xFF48484A) : const Color(0xFFCCCCCC);
  Color get outlineVariant => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);

  Color get error   => isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  Color get barrier => const Color(0x80000000);
  Color get hover   => isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000);
  Color get pressed => isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000);

  // Botão Projetos: sempre azul sólido sem sombra colorida
  Color get navBg => isDark ? const Color(0xFF2C2C2E) : const Color(0xFF2C2C2E);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 4))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 2)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4,  offset: const Offset(0, 1)),
        ];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 28, offset: const Offset(0, 8))]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.11), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6,  offset: const Offset(0, 2)),
        ];
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  bool isDark = false;
  void toggleDark() { isDark = !isDark; notifyListeners(); }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

class AppTheme extends InheritedNotifier<AppThemeNotifier> {
  AppTheme({super.key, required super.child}) : super(notifier: appTheme);

  static AppColorScheme of(BuildContext context) {
    final n = context.dependOnInheritedWidgetOfExactType<AppTheme>()?.notifier;
    return AppColorScheme(n?.isDark ?? false);
  }
}