import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../colors.dart';
import '../widgets.dart';
import '../api_service.dart';
import '../auth_service.dart';

enum AgendaViewMode { day, week, month }

extension AgendaViewModeX on AgendaViewMode {
  String get label => const {
        AgendaViewMode.day:   'Dia',
        AgendaViewMode.week:  'Semana',
        AgendaViewMode.month: 'Mês',
      }[this]!;
}

class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});
  @override State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  static const _months = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
  static const _weekdays = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<EventItem> _events = [];
  bool _loading = true;

  AgendaViewMode _mode = AgendaViewMode.month;
  late DateTime _current;
  late DateTime _focusDay;
  late DateTime _today;
  late String _selectedKey;

  String _key(int y, int m, int d) => '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  String _keyOf(DateTime d) => _key(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _current = DateTime(_today.year, _today.month, 1);
    _focusDay = DateTime(_today.year, _today.month, _today.day);
    _selectedKey = _keyOf(_focusDay);
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
        _focusDay = DateTime(created.startDate.year, created.startDate.month, created.startDate.day);
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

  void _selectDay(DateTime d) {
    setState(() {
      _selectedKey = _keyOf(d);
      _focusDay = d;
    });
  }

  void _selectMode(AgendaViewMode m) {
    Navigator.of(context).pop();
    if (m == _mode) return;
    setState(() => _mode = m);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final byDay = _eventsByDay;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: s.surface,
      drawer: _AgendaDrawer(
        s: s,
        current: _mode,
        onSelect: _selectMode,
      ),
      drawerEdgeDragWidth: 28,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              AppTap(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                s: s,
                size: 34,
                child: AppIcon('menu.svg', color: s.onSurface, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Agenda',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: s.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: s.hover, borderRadius: BorderRadius.circular(999)),
                child: Text(_mode.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.onSurfaceVariant)),
              ),
              const SizedBox(width: 10),
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
              child: switch (_mode) {
                AgendaViewMode.month => _MonthView(
                    s: s,
                    months: _months,
                    weekdays: _weekdays,
                    current: _current,
                    today: _today,
                    selectedKey: _selectedKey,
                    eventsByDay: byDay,
                    onPrevMonth: () => setState(() => _current = DateTime(_current.year, _current.month - 1, 1)),
                    onNextMonth: () => setState(() => _current = DateTime(_current.year, _current.month + 1, 1)),
                    onSelectDay: _selectDay,
                    onDeleteEvent: _deleteEvent,
                  ),
                AgendaViewMode.week => _WeekView(
                    s: s,
                    weekdays: _weekdays,
                    focusDay: _focusDay,
                    today: _today,
                    selectedKey: _selectedKey,
                    eventsByDay: byDay,
                    onPrevWeek: () => setState(() => _focusDay = _focusDay.subtract(const Duration(days: 7))),
                    onNextWeek: () => setState(() => _focusDay = _focusDay.add(const Duration(days: 7))),
                    onSelectDay: _selectDay,
                    onDeleteEvent: _deleteEvent,
                    onAddEventAt: (d, hour) => _createEventAt(d, hour),
                  ),
                AgendaViewMode.day => _DayView(
                    s: s,
                    focusDay: _focusDay,
                    today: _today,
                    eventsByDay: byDay,
                    onPrevDay: () => setState(() => _focusDay = _focusDay.subtract(const Duration(days: 1))),
                    onNextDay: () => setState(() => _focusDay = _focusDay.add(const Duration(days: 1))),
                    onDeleteEvent: _deleteEvent,
                    onAddEventAt: (hour) => _createEventAt(_focusDay, hour),
                  ),
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _createEventAt(DateTime day, int hour) async {
    final s = AppTheme.of(context);
    final initial = DateTime(day.year, day.month, day.day, hour, 0);
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
      });
    }
  }
}

// ══════════════════════════════════════════════════════════════
// _AgendaLoading
// ══════════════════════════════════════════════════════════════
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
// _AgendaDrawer + _AgendaDrawerItem
// ══════════════════════════════════════════════════════════════
class _AgendaDrawer extends StatefulWidget {
  final AppColorScheme s;
  final AgendaViewMode current;
  final ValueChanged<AgendaViewMode> onSelect;
  const _AgendaDrawer({required this.s, required this.current, required this.onSelect});

  @override
  State<_AgendaDrawer> createState() => _AgendaDrawerState();
}

class _AgendaDrawerState extends State<_AgendaDrawer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _ctrl, curve: kCupertinoOut);
    _slide = Tween<Offset>(begin: const Offset(-0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: kCupertinoOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Drawer(
      backgroundColor: s.floatingSurface,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Visualização',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: s.onSurfaceVariant, letterSpacing: 0.4)),
                const SizedBox(height: 14),
                for (final mode in AgendaViewMode.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _AgendaDrawerItem(
                      s: s,
                      mode: mode,
                      selected: mode == widget.current,
                      onTap: () => widget.onSelect(mode),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaDrawerItem extends StatefulWidget {
  final AppColorScheme s;
  final AgendaViewMode mode;
  final bool selected;
  final VoidCallback onTap;
  const _AgendaDrawerItem({
    required this.s,
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  @override State<_AgendaDrawerItem> createState() => _AgendaDrawerItemState();
}

class _AgendaDrawerItemState extends State<_AgendaDrawerItem> {
  bool _pressed = false;

  static const _icons = {
    AgendaViewMode.day:   'agenda_day.svg',
    AgendaViewMode.week:  'agenda_week.svg',
    AgendaViewMode.month: 'agenda_tab.svg',
  };

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final sel = widget.selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: kCupertinoOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? s.hover : (_pressed ? s.hover.withOpacity(0.6) : Colors.transparent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          AppIcon(_icons[widget.mode]!, size: 17, color: sel ? s.primary : s.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(widget.mode.label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? s.onSurface : s.onSurfaceVariant,
              )),
          if (sel) ...[
            const Spacer(),
            AppIcon('check.svg', size: 14, color: s.primary),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _NewEventSheet
// ══════════════════════════════════════════════════════════════
class _NewEventSheet extends StatefulWidget {
  final AppColorScheme s;
  final DateTime initialDate;
  const _NewEventSheet({required this.s, required this.initialDate});

  @override
  State<_NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends State<_NewEventSheet> {
  late final TextEditingController _titleCtrl;
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _start = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked != null) {
      setState(() {
        _start = DateTime(
          _start.year,
          _start.month,
          _start.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop({
      'title': title,
      'startAt': _start.millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Material(
      color: s.floatingSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Novo evento',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: TextStyle(color: s.onSurface),
                decoration: InputDecoration(
                  hintText: 'Título',
                  hintStyle: TextStyle(color: s.onSurfaceVariant),
                  filled: true,
                  fillColor: s.hover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: s.hover,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      AppIcon('clock.svg', size: 16, color: s.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(
                        '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: s.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_start.day.toString().padLeft(2, '0')}/${_start.month.toString().padLeft(2, '0')}/${_start.year}',
                        style: TextStyle(color: s.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: s.primary,
                    foregroundColor: s.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Criar evento'),
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
// Widgets de calendário comuns
// ══════════════════════════════════════════════════════════════
class _CalendarHeader extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _CalendarHeader({
    required this.s,
    required this.title,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: AppIcon('chevron_left.svg', size: 20, color: s.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: s.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: AppIcon('chevron_right.svg', size: 20, color: s.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final AppColorScheme s;
  final List<String> weekdays;

  const _WeekdayRow({required this.s, required this.weekdays});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  weekdays[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: s.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _MonthView + auxiliares
// ─────────────────────────────────────────────────────────────
class _MonthView extends StatelessWidget {
  final AppColorScheme s;
  final List<String> months;
  final List<String> weekdays;
  final DateTime current;
  final DateTime today;
  final String selectedKey;
  final Map<String, List<EventItem>> eventsByDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<EventItem> onDeleteEvent;

  const _MonthView({
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
    required this.onDeleteEvent,
  });

  String _keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final year = current.year;
    final month = current.month;
    final firstDay = DateTime(year, month, 1);
    final leading = firstDay.weekday % 7;
    final daysCount = _daysInMonth(year, month);
    final cells = <DateTime>[];

    for (int i = 0; i < leading; i++) {
      cells.add(DateTime(year, month, 0).subtract(Duration(days: leading - 1 - i)));
    }
    for (int d = 1; d <= daysCount; d++) {
      cells.add(DateTime(year, month, d));
    }
    final total = ((cells.length + 6) ~/ 7) * 7;
    for (int i = cells.length; i < total; i++) {
      cells.add(DateTime(year, month + 1, i - cells.length + 1));
    }

    return Column(
      children: [
        _CalendarHeader(
          s: s,
          title: '${months[month - 1]} $year',
          onPrev: onPrevMonth,
          onNext: onNextMonth,
        ),
        const SizedBox(height: 8),
        _WeekdayRow(s: s, weekdays: weekdays),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.82,
            ),
            itemCount: total,
            itemBuilder: (ctx, index) {
              final day = cells[index];
              final key = _keyOf(day);
              final isCurrentMonth = day.month == month && day.year == year;
              final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
              final isSelected = key == selectedKey;
              final events = eventsByDay[key] ?? [];

              return _MonthDayCell(
                s: s,
                day: day,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                isSelected: isSelected,
                events: events,
                onTap: () => onSelectDay(day),
                onDeleteEvent: onDeleteEvent,
              );
            },
          ),
        ),
        if (eventsByDay[selectedKey]?.isNotEmpty ?? false)
          _SelectedDayEvents(
            s: s,
            date: DateTime.parse(selectedKey),
            events: eventsByDay[selectedKey]!,
            onDelete: onDeleteEvent,
          ),
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  final AppColorScheme s;
  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<EventItem> events;
  final VoidCallback onTap;
  final ValueChanged<EventItem> onDeleteEvent;

  const _MonthDayCell({
    required this.s,
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
    required this.onDeleteEvent,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isCurrentMonth
        ? s.onSurface
        : s.onSurfaceVariant.withOpacity(0.5);
    final bgColor = isSelected
        ? s.primary
        : isToday
            ? s.hover
            : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? s.onPrimary : textColor,
                fontSize: 14,
              ),
            ),
            if (events.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? s.onPrimary : s.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayEvents extends StatelessWidget {
  final AppColorScheme s;
  final DateTime date;
  final List<EventItem> events;
  final ValueChanged<EventItem> onDelete;

  const _SelectedDayEvents({
    required this.s,
    required this.date,
    required this.events,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.floatingSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.hover),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
            style: TextStyle(fontWeight: FontWeight.w700, color: s.onSurface),
          ),
          const SizedBox(height: 8),
          ...events.map((e) => _EventRow(
                s: s,
                event: e,
                onDelete: () => onDelete(e),
              )),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final AppColorScheme s;
  final EventItem event;
  final VoidCallback onDelete;

  const _EventRow({
    required this.s,
    required this.event,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final start = event.startDate;
    final time = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(time, style: TextStyle(fontSize: 12, color: s.primary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(event.title, style: TextStyle(color: s.onSurface)),
          ),
          GestureDetector(
            onTap: onDelete,
            child: AppIcon('trash.svg', size: 16, color: s.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WeekView
// ─────────────────────────────────────────────────────────────
class _WeekView extends StatelessWidget {
  final AppColorScheme s;
  final List<String> weekdays;
  final DateTime focusDay;
  final DateTime today;
  final String selectedKey;
  final Map<String, List<EventItem>> eventsByDay;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<EventItem> onDeleteEvent;
  final void Function(DateTime day, int hour) onAddEventAt;

  const _WeekView({
    required this.s,
    required this.weekdays,
    required this.focusDay,
    required this.today,
    required this.selectedKey,
    required this.eventsByDay,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onSelectDay,
    required this.onDeleteEvent,
    required this.onAddEventAt,
  });

  List<DateTime> _weekDays(DateTime focus) {
    final start = focus.subtract(Duration(days: focus.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _monthName(int m) {
    const months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final days = _weekDays(focusDay);
    return Column(
      children: [
        _CalendarHeader(
          s: s,
          title: '${days.first.day} – ${days.last.day} ${_monthName(days.first.month)}',
          onPrev: onPrevWeek,
          onNext: onNextWeek,
        ),
        const SizedBox(height: 8),
        Row(
          children: days.map((d) {
            final key = _keyOf(d);
            final isSelected = key == selectedKey;
            final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelectDay(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? s.primary : isToday ? s.hover : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        weekdays[d.weekday % 7],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? s.onPrimary : s.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? s.onPrimary : s.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.map((d) {
                final key = _keyOf(d);
                final events = eventsByDay[key] ?? [];
                return Expanded(
                  child: Column(
                    children: [
                      IconButton(
                        icon: AppIcon('add.svg', size: 14, color: s.onSurfaceVariant),
                        onPressed: () => onAddEventAt(d, 9),
                      ),
                      ...events.map((e) => Padding(
                            padding: const EdgeInsets.all(4),
                            child: _EventCard(
                              s: s,
                              event: e,
                              onTap: () => onSelectDay(d),
                              onDelete: () => onDeleteEvent(e),
                            ),
                          )),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────
// _DayView
// ─────────────────────────────────────────────────────────────
class _DayView extends StatelessWidget {
  final AppColorScheme s;
  final DateTime focusDay;
  final DateTime today;
  final Map<String, List<EventItem>> eventsByDay;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final ValueChanged<EventItem> onDeleteEvent;
  final ValueChanged<int> onAddEventAt;

  const _DayView({
    required this.s,
    required this.focusDay,
    required this.today,
    required this.eventsByDay,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onDeleteEvent,
    required this.onAddEventAt,
  });

  @override
  Widget build(BuildContext context) {
    final key = '${focusDay.year}-${focusDay.month.toString().padLeft(2, '0')}-${focusDay.day.toString().padLeft(2, '0')}';
    final events = eventsByDay[key] ?? [];
    final isToday = focusDay.year == today.year && focusDay.month == today.month && focusDay.day == today.day;

    return Column(
      children: [
        _CalendarHeader(
          s: s,
          title: '${focusDay.day.toString().padLeft(2, '0')}/${focusDay.month.toString().padLeft(2, '0')}/${focusDay.year}',
          onPrev: onPrevDay,
          onNext: onNextDay,
        ),
        const SizedBox(height: 8),
        if (isToday)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Hoje',
              style: TextStyle(color: s.primary, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: AppIcon('add.svg', size: 20, color: s.primary),
                  onPressed: () => onAddEventAt(9),
                ),
              ),
              ...events.map((e) => _EventCard(
                    s: s,
                    event: e,
                    onTap: () {},
                    onDelete: () => onDeleteEvent(e),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EventCard
// ─────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final AppColorScheme s;
  final EventItem event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EventCard({
    required this.s,
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final start = event.startDate;
    final time = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.floatingSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.hover),
      ),
      child: Row(
        children: [
          Text(time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.primary)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(event.title, style: TextStyle(color: s.onSurface)),
          ),
          IconButton(
            icon: AppIcon('trash.svg', size: 16, color: s.onSurfaceVariant),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}