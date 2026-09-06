// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/widgets/account_picker_sheet.dart
// Bottom sheet com as contas guardadas neste dispositivo.
// Aparece ao tocar em "Continuar com email" quando já existem
// contas usadas anteriormente. Tem botão para ignorar e ir
// direto para o login normal.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../services/local_accounts_service.dart';

/// Mostra o bottom sheet de contas guardadas.
/// Devolve a [LocalAccount] escolhida, ou `null` se o utilizador
/// tocou em "Usar outra conta" / fechou o sheet.
Future<LocalAccount?> showAccountPickerSheet({
  required BuildContext context,
  required List<LocalAccount> accounts,
}) {
  return showModalBottomSheet<LocalAccount?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AccountPickerSheet(accounts: accounts),
  );
}

class _AccountPickerSheet extends StatelessWidget {
  final List<LocalAccount> accounts;
  const _AccountPickerSheet({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: s.outline.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: s.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              'Contas neste dispositivo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolhe uma conta para continuar.',
              style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...accounts.map((a) => _AccountTile(account: a)),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(null),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.cardBackground,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: s.outline.withOpacity(0.45)),
                ),
                child: Text(
                  'Usar outra conta',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatefulWidget {
  final LocalAccount account;
  const _AccountTile({required this.account});

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final a = widget.account;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: () => Navigator.of(context).pop(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _p ? s.hover : s.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s.outline.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: s.primary.withOpacity(0.15),
              backgroundImage:
                  (a.avatar != null && a.avatar!.isNotEmpty)
                      ? NetworkImage(a.avatar!)
                      : null,
              child: (a.avatar == null || a.avatar!.isEmpty)
                  ? Text(
                      a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: s.primary, fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: s.onSurface),
                  ),
                  Text(
                    a.identifier,
                    style: TextStyle(
                        fontSize: 12.5, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AppIcon('chevron_right', size: 16, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}