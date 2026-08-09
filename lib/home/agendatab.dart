// ══════════════════════════════════════════════════════════════
// FILE: lib/home/agendatab.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../colors.dart';
import '../widgets.dart';

// ══════════════════════════════════════════════════════════════
// AGENDA TAB — placeholder funcional, pronto a ligar a um backend
// de eventos/tarefas mais tarde. Segue os mesmos padrões visuais do
// resto da app (AppIcon, s.* do AppColorScheme, sem elementos
// nativos Material/Cupertino de ícones).
// ══════════════════════════════════════════════════════════════

class AgendaTab extends StatelessWidget {
const AgendaTab({super.key});

@override
Widget build(BuildContext context) {
final s = AppTheme.of(context);
return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Padding(
padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
child: Row(children: [
Text('Agenda',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.w700,
color: s.onSurface)),
const Spacer(),
AppTap(
onTap: () {},
s: s,
size: 34,
child: AppIcon('add.svg', color: s.onSurface, size: 17),
),
]),
),
Expanded(
child: Center(
child: Column(mainAxisSize: MainAxisSize.min, children: [
AppIcon('agenda_tab.svg',
color: s.onSurfaceVariant.withOpacity(0.35), size: 52),
const SizedBox(height: 14),
Text('Sem eventos ainda',
style: TextStyle(fontSize: 16, color: s.onSurfaceVariant)),
const SizedBox(height: 6),
Text('Cria o teu primeiro evento',
style: TextStyle(
fontSize: 13,
color: s.onSurfaceVariant.withOpacity(0.55))),
]),
),
),
const SizedBox(height: 92),
]);
}
}