// ══════════════════════════════════════════════════════════════
// FILE: lib/home/agendatab.dart
// ══════════════════════════════════════════════════════════════
import 'dart:math' as math;
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
  static const _months = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
  static const _weekdays = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];

  List<EventItem> _events = [];
  bool _loading = true;

  late DateTime _current;
  late DateTime _today;
  late String _selectedKey;

  String _key(int y, int m, int d) => '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  String _keyOf(DateTime d) => _key(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _current = DateTime(_today.year, _today.month, 1);
    _selectedKey = _key(_today.year, _today.month, _today.day);
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

  Map<String, List<EventItem>> get _eventsByDay {
    final map = <String, List<EventItem>>{};
    for (final e in _events) {
      map.putIfAbsent(_keyOf(e.startDate), () => []).add(e);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
    }
    return map;
  }

  Future<void> _createEvent() async {
    final s = AppTheme.of(context);
    final parts = _selectedKey.split('-');
    final selDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final initial = DateTime(selDate.year, selDate.month, selDate.day, now.hour, now.minute)
        .add(const Duration(hours: 1));

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _NewEventSheet(s: s, initialDate: initial),
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
      setState(() {
        _events = [..._events, created];
        _selectedKey = _keyOf(created.startDate);
        _current = DateTime(created.startDate.year, created.startDate.month, 1);
      });
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
    final byDay = _eventsByDay;
    final selectedEvents = byDay[_selectedKey] ?? const [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
      if (_loading)
        const Expanded(child: Center(child: _AgendaLoading()))
      else
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              _AgendaCalendarCard(
                s: s,
                months: _months,
                weekdays: _weekdays,
                current: _current,
                today: _today,
                selectedKey: _selectedKey,
                eventsByDay: byDay,
                onPrevMonth: () => setState(() => _current = DateTime(_current.year, _current.month - 1, 1)),
                onNextMonth: () => setState(() => _current = DateTime(_current.year, _current.month + 1, 1)),
                onSelectDay: (key) => setState(() => _selectedKey = key),
                onAddEvent: _createEvent,
              ),
              const SizedBox(height: 18),
              _SelectedDayHeader(s: s, selectedKey: _selectedKey, today: _today),
              const SizedBox(height: 10),
              if (selectedEvents.isEmpty)
                _EmptyDayState(s: s)
              else
                ...selectedEvents.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EventRow(s: s, event: e, onDelete: () => _deleteEvent(e)),
                    )),
              const SizedBox(height: 80),
            ],
          ),
        ),
    ]);
  }
}

class _AgendaLoading extends StatelessWidget {
  const _AgendaLoading();
  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return SizedBox(
      width: 22, height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant)),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CALENDAR CARD — mesmo design do card do widget de IA: preview
// mensal com aspect ratio, header com nav circular, dots de evento
// por dia, botão pill de ação no rodapé do card.
// ══════════════════════════════════════════════════════════════

class _AgendaCalendarCard extends StatelessWidget {
  final AppColorScheme s;
  final List<String> months;
  final List<String> weekdays;
  final DateTime current;
  final DateTime today;
  final String selectedKey;
  final Map<String, List<EventItem>> eventsByDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<String> onSelectDay;
  final VoidCallback onAddEvent;

  const _AgendaCalendarCard({
    required this.s,
    required this.months,
    required this.weekdays,
    required this.current,
    required this.today,
    required this.selectedKey,
    required this.eventsByDay,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.onAddEvent,
  });

  String _key(int y, int m, int d) => '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final y = current.year, m = current.month;
    final firstDay = DateTime(y, m, 1).weekday % 7;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final daysInPrev = DateTime(y, m, 0).day;

    final cells = <Widget>[];
    for (int i = firstDay - 1; i >= 0; i--) {
      final day = daysInPrev - i;
      cells.add(_buildDayCell(
        label: day.toString(),
        isOtherMonth: true,
        isToday: false,
        isSelected: false,
        eventColors: const [],
        onTap: null,
      ));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final key = _key(y, m, d);
      final isToday = DateTime(y, m, d) == DateTime(today.year, today.month, today.day);
      final dayEvents = eventsByDay[key] ?? const [];
      cells.add(_buildDayCell(
        label: d.toString(),
        isOtherMonth: false,
        isToday: isToday,
        isSelected: key == selectedKey,
        eventColors: dayEvents.map((e) => Color(int.parse(e.color.replaceFirst('#', '0xFF')))).toList(),
        onTap: () => onSelectDay(key),
      ));
    }
    final total = firstDay + daysInMonth;
    final rem = total % 7 == 0 ? 0 : 7 - total % 7;
    for (int d = 1; d <= rem; d++) {
      cells.add(_buildDayCell(
        label: d.toString(),
        isOtherMonth: true,
        isToday: false,
        isSelected: false,
        eventColors: const [],
        onTap: null,
      ));
    }

    final rows = <List<Widget>>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, math.min(i + 7, cells.length)));
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: s.outline.withOpacity(0.1)),
        boxShadow: s.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: s.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${months[m - 1]} $y',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: s.onSurface,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Row(
                          children: [
                            _NavButton(s: s, icon: 'chevron_left.svg', onTap: onPrevMonth),
                            const SizedBox(width: 8),
                            _NavButton(s: s, icon: 'chevron_right.svg', onTap: onNextMonth),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: weekdays.map((w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: s.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: rows.map((row) => Expanded(
                          child: Row(
                            children: row.map((cell) => Expanded(child: cell)).toList(),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: s.hover,
              borderRadius: BorderRadius.circular(50),
            ),
            child: GestureDetector(
              onTap: onAddEvent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('add.svg', size: 14, color: s.onPrimary),
                    const SizedBox(width: 7),
                    Text(
                      'Novo evento',
                      style: TextStyle(
                        color: s.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required String label,
    required bool isOtherMonth,
    required bool isToday,
    required bool isSelected,
    required List<Color> eventColors,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday
                  ? s.primary
                  : isSelected
                      ? s.hover
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday || eventColors.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? s.onPrimary
                    : isOtherMonth
                        ? s.onSurfaceVariant.withOpacity(0.5)
                        : s.onSurface,
              ),
            ),
          ),
          if (eventColors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                children: eventColors.take(2).map((c) => Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 1),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final AppColorScheme s;
  final String icon;
  final VoidCallback onTap;
  const _NavButton({required this.s, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: s.hover, shape: BoxShape.circle),
          child: AppIcon(icon, size: 12, color: s.onSurfaceVariant),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// SELECTED DAY HEADER + EMPTY STATE + EVENT ROW
// ══════════════════════════════════════════════════════════════

class _SelectedDayHeader extends StatelessWidget {
  final AppColorScheme s;
  final String selectedKey;
  final DateTime today;
  const _SelectedDayHeader({required this.s, required this.selectedKey, required this.today});

  static const _months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
  static const _weekdaysFull = ['Domingo','Segunda','Terça','Quarta','Quinta','Sexta','Sábado'];

  @override
  Widget build(BuildContext context) {
    final parts = selectedKey.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
    final label = '${_weekdaysFull[d.weekday % 7]}, ${d.day} ${_months[d.month - 1]}';
    return Row(children: [
      Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: s.onSurface)),
      if (isToday) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: s.primary.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
          child: Text('Hoje', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s.primary)),
        ),
      ],
    ]);
  }
}

class _EmptyDayState extends StatelessWidget {
  final AppColorScheme s;
  const _EmptyDayState({required this.s});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s.outline.withOpacity(0.1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppIcon('agenda_tab.svg', color: s.onSurfaceVariant.withOpacity(0.35), size: 30),
          const SizedBox(height: 8),
          Text('Sem eventos neste dia', style: TextStyle(fontSize: 13, color: s.onSurfaceVariant)),
        ]),
      );
}

class _EventRow extends StatelessWidget {
  final AppColorScheme s;
  final EventItem event;
  final VoidCallback onDelete;
  const _EventRow({required this.s, required this.event, required this.onDelete});

  String _fmtTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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
                Text(_fmtTime(event.startDate), style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant)),
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

// ══════════════════════════════════════════════════════════════
// NEW EVENT SHEET — mesmo bottom sheet, agora recebe a data
// já pré-selecionada a partir do dia clicado no calendário.
// ══════════════════════════════════════════════════════════════

class _NewEventSheet extends StatefulWidget {
  final AppColorScheme s;
  final DateTime initialDate;
  const _NewEventSheet({required this.s, required this.initialDate});
  @override State<_NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends State<_NewEventSheet> {
  final _ctrl = TextEditingController();
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

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