// ══════════════════════════════════════════════════════════════
// FILE: lib/home/agendatab.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../colors.dart';
import '../widgets.dart';
import '../api_service.dart';
import '../auth_service.dart';

class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});
  @override State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  List<EventItem> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = authController.token;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    final events = await EventsApiService.list(token);
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _createEvent() async {
    final s = AppTheme.of(context);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _NewEventSheet(s: s),
    );
    if (result == null) return;
    final token = authController.token;
    if (token == null) return;
    final created = await EventsApiService.create(
      token,
      title: result['title'] as String,
      startAt: result['startAt'] as int,
    );
    if (created != null && mounted) {
      setState(() => _events = [..._events, created]..sort((a, b) => a.startAt.compareTo(b.startAt)));
    }
  }

  Future<void> _deleteEvent(EventItem e) async {
    final token = authController.token;
    if (token == null) return;
    final ok = await EventsApiService.delete(token, e.id);
    if (ok && mounted) {
      setState(() => _events.removeWhere((x) => x.id == e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Text('Agenda',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: s.onSurface)),
          const Spacer(),
          AppTap(
            onTap: _createEvent,
            s: s,
            size: 34,
            child: AppIcon('add.svg', color: s.onSurface, size: 17),
          ),
        ]),
      ),
      Expanded(child: _buildBody(s)),
      const SizedBox(height: 92),
    ]);
  }

  Widget _buildBody(AppColorScheme s) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant)),
        ),
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppIcon('agenda_tab.svg', color: s.onSurfaceVariant.withOpacity(0.35), size: 52),
          const SizedBox(height: 14),
          Text('Sem eventos ainda', style: TextStyle(fontSize: 16, color: s.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('Cria o teu primeiro evento',
              style: TextStyle(fontSize: 13, color: s.onSurfaceVariant.withOpacity(0.55))),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      itemCount: _events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _EventRow(s: s, event: _events[i], onDelete: () => _deleteEvent(_events[i])),
    );
  }
}

class _EventRow extends StatelessWidget {
  final AppColorScheme s;
  final EventItem event;
  final VoidCallback onDelete;
  const _EventRow({required this.s, required this.event, required this.onDelete});

  String _fmtDate(DateTime d) {
    const months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: s.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(
              color: Color(int.parse(event.color.replaceFirst('#', '0xFF'))),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: s.onSurface)),
                const SizedBox(height: 2),
                Text(_fmtDate(event.startDate), style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 28, height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.error.withOpacity(0.12), shape: BoxShape.circle),
              child: AppIcon('trash.svg', size: 13, color: s.error),
            ),
          ),
        ]),
      );
}

class _NewEventSheet extends StatefulWidget {
  final AppColorScheme s;
  const _NewEventSheet({required this.s});
  @override State<_NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends State<_NewEventSheet> {
  final _ctrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (time == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: SheetGrabber(s: s)),
                Text('Novo evento',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: TextStyle(fontSize: 15, color: s.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Título do evento',
                    hintStyle: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                    filled: true,
                    fillColor: s.hover,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: s.hover, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      AppIcon('agenda_tab.svg', size: 16, color: s.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        '${_date.day}/${_date.month}/${_date.year} · ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 14, color: s.onSurface),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (_ctrl.text.trim().isEmpty) return;
                    Navigator.pop(context, {
                      'title': _ctrl.text.trim(),
                      'startAt': _date.millisecondsSinceEpoch,
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
                    child: Text('Criar evento',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onPrimary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}