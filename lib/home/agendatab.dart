import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors.dart';
import '../widgets.dart';

// ─────────────────────────────────────────────────────────────────────
// Modelo de evento
// ─────────────────────────────────────────────────────────────────────
class AgendaEvent {
  final String id;
  String title;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  bool allDay;
  Color color;
  String description;
  String location;
  String repeat;

  AgendaEvent({
    required this.id,
    required this.title,
    required this.date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    this.allDay = false,
    this.color = const Color(0xFF4285F4),
    this.description = '',
    this.location = '',
    this.repeat = 'none',
  })  : startTime = startTime ?? const TimeOfDay(hour: 0, minute: 0),
        endTime = endTime ?? const TimeOfDay(hour: 0, minute: 0);

  String get dateStr =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String get startTimeStr =>
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

  String get endTimeStr =>
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────
// Enumerado e extensão para modos de vista
// ─────────────────────────────────────────────────────────────────────
enum AgendaViewMode { month, week, day, agenda }

extension AgendaViewModeX on AgendaViewMode {
  String get label => switch (this) {
        AgendaViewMode.month => 'Mês',
        AgendaViewMode.week => 'Semana',
        AgendaViewMode.day => 'Dia',
        AgendaViewMode.agenda => 'Agenda',
      };
}

// ─────────────────────────────────────────────────────────────────────
// Cores dos eventos (paleta fixa de dados, não são tokens de tema)
// ─────────────────────────────────────────────────────────────────────
const List<Color> kEventColors = [
  Color(0xFF4285F4),
  Color(0xFF0F9D58),
  Color(0xFFDB4437),
  Color(0xFFF4B400),
  Color(0xFF9C27B0),
  Color(0xFFFF6D00),
  Color(0xFF00ACC1),
  Color(0xFFE91E63),
];

const Color _kWeekendColor = Color(0xFFFF3B30);

const List<String> kRepeatOptions = [
  'none',
  'daily',
  'weekly',
  'monthly',
  'yearly',
];

const List<String> kRepeatLabels = [
  'Não repetir',
  'Todos os dias',
  'Todas as semanas',
  'Todos os meses',
  'Todos os anos',
];

// ─────────────────────────────────────────────────────────────────────
// Tela principal da agenda
// ─────────────────────────────────────────────────────────────────────
class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});
  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  AgendaViewMode _currentView = AgendaViewMode.month;
  DateTime _viewDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  List<AgendaEvent> _events = [];

  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _showEventScreen = false;
  bool _editing = false;
  AgendaEvent? _editingEvent;
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  DateTime _formDate = DateTime.now();
  TimeOfDay _formStart = TimeOfDay.now();
  TimeOfDay _formEnd = TimeOfDay.now();
  bool _formAllDay = false;
  Color _formColor = kEventColors.first;
  String _formRepeat = 'none';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _locationController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadSampleEvents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _loadSampleEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _events = [
      AgendaEvent(
        id: '1',
        title: 'Reunião de equipa',
        date: today,
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
        color: kEventColors[0],
        location: 'Sala 4',
      ),
      AgendaEvent(
        id: '2',
        title: 'Almoço com cliente',
        date: today.add(const Duration(days: 1)),
        startTime: const TimeOfDay(hour: 12, minute: 30),
        endTime: const TimeOfDay(hour: 13, minute: 30),
        color: kEventColors[2],
      ),
      AgendaEvent(
        id: '3',
        title: 'Aniversário da Maria',
        date: today.add(const Duration(days: 2)),
        allDay: true,
        color: kEventColors[4],
      ),
    ];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<AgendaEvent> _eventsOnDate(DateTime d) {
    final result = _events.where((ev) {
      final base = DateTime(ev.date.year, ev.date.month, ev.date.day);
      if (ev.repeat == 'none') return _isSameDay(base, d);
      if (ev.repeat == 'daily') return !base.isAfter(d);
      if (ev.repeat == 'weekly') return base.weekday == d.weekday && !base.isAfter(d);
      if (ev.repeat == 'monthly') return base.day == d.day && !base.isAfter(d);
      if (ev.repeat == 'yearly') return base.month == d.month && base.day == d.day && !base.isAfter(d);
      return false;
    }).toList()
      ..sort((a, b) {
        if (a.allDay && !b.allDay) return -1;
        if (!a.allDay && b.allDay) return 1;
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });
    return result;
  }

  void _prev() {
    setState(() {
      switch (_currentView) {
        case AgendaViewMode.month:
          _viewDate = DateTime(_viewDate.year, _viewDate.month - 1, 1);
          break;
        case AgendaViewMode.week:
          _selectedDay = _selectedDay.subtract(const Duration(days: 7));
          _viewDate = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
        case AgendaViewMode.day:
          _selectedDay = _selectedDay.subtract(const Duration(days: 1));
          _viewDate = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
        case AgendaViewMode.agenda:
          break;
      }
    });
  }

  void _next() {
    setState(() {
      switch (_currentView) {
        case AgendaViewMode.month:
          _viewDate = DateTime(_viewDate.year, _viewDate.month + 1, 1);
          break;
        case AgendaViewMode.week:
          _selectedDay = _selectedDay.add(const Duration(days: 7));
          _viewDate = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
        case AgendaViewMode.day:
          _selectedDay = _selectedDay.add(const Duration(days: 1));
          _viewDate = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
        case AgendaViewMode.agenda:
          break;
      }
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _viewDate = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  String get _navLabel {
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    const daysFull = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];
    switch (_currentView) {
      case AgendaViewMode.month:
        return '${months[_viewDate.month - 1]} ${_viewDate.year}';
      case AgendaViewMode.week:
        final start = _selectedDay.subtract(Duration(days: _selectedDay.weekday % 7));
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return '${start.day}–${end.day} ${months[start.month - 1]} ${start.year}';
        } else {
          return '${start.day} ${months[start.month - 1].substring(0, 3)} – ${end.day} ${months[end.month - 1].substring(0, 3)} ${end.year}';
        }
      case AgendaViewMode.day:
        return '${daysFull[_selectedDay.weekday]}, ${_selectedDay.day} ${months[_selectedDay.month - 1]}';
      case AgendaViewMode.agenda:
        return 'Agenda';
    }
  }

  void _openSearch() {
    setState(() => _showSearch = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<AgendaEvent> get _searchResults {
    if (_searchQuery.trim().isEmpty) return [];
    return _events.where((ev) {
      final q = _searchQuery.toLowerCase();
      return ev.title.toLowerCase().contains(q) ||
          ev.description.toLowerCase().contains(q) ||
          ev.location.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  void _openNewEvent({DateTime? date, int? hour}) {
    final d = date ?? _selectedDay;
    final h = hour ?? DateTime.now().hour;
    _formDate = d;
    _formStart = TimeOfDay(hour: h, minute: 0);
    _formEnd = TimeOfDay(hour: (h + 1) % 24, minute: 0);
    _formAllDay = false;
    _formColor = kEventColors[0];
    _formRepeat = 'none';
    _titleController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _editing = false;
    _editingEvent = null;
    setState(() => _showEventScreen = true);
  }

  void _openEditEvent(AgendaEvent ev) {
    _editing = true;
    _editingEvent = ev;
    _formDate = ev.date;
    _formStart = ev.startTime;
    _formEnd = ev.endTime;
    _formAllDay = ev.allDay;
    _formColor = ev.color;
    _formRepeat = ev.repeat;
    _titleController.text = ev.title;
    _locationController.text = ev.location;
    _descriptionController.text = ev.description;
    setState(() => _showEventScreen = true);
  }

  void _closeEventScreen() {
    setState(() {
      _showEventScreen = false;
      _editing = false;
      _editingEvent = null;
    });
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty) {
      _showValidationDialog('Insere um título para o evento.');
      return;
    }
    final event = AgendaEvent(
      id: _editingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      date: _formDate,
      startTime: _formStart,
      endTime: _formEnd,
      allDay: _formAllDay,
      color: _formColor,
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      repeat: _formRepeat,
    );
    setState(() {
      if (_editing) {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) _events[index] = event;
      } else {
        _events.add(event);
      }
    });
    _closeEventScreen();
  }

  void _showValidationDialog(String message) {
    showFluentDialog<void>(
      context: context,
      s: AppTheme.of(context),
      child: FluentDialog(
        s: AppTheme.of(context),
        title: 'Atenção',
        content: Text(
          message,
          style: TextStyle(
            fontSize: kTypeBody,
            color: AppTheme.of(context).onSurface,
          ),
        ),
        actions: [
          FluentButton(
            s: AppTheme.of(context),
            label: 'OK',
            onTap: () => Navigator.pop(context),
            style: FluentButtonStyle.primary,
          ),
        ],
      ),
    );
  }

  void _deleteEvent(String id) {
    setState(() => _events.removeWhere((e) => e.id == id));
    _closeEventScreen();
  }

  void _openDetail(AgendaEvent ev) {
    showFluentBottomSheet<void>(
      context: context,
      s: AppTheme.of(context),
      child: _AgendaDetailSheet(
        s: AppTheme.of(context),
        event: ev,
        onEdit: () {
          Navigator.pop(context);
          _openEditEvent(ev);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteEvent(ev.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Scaffold(
      backgroundColor: s.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(s),
              Expanded(
                child: _buildBody(s),
              ),
            ],
          ),
          Positioned(
            right: kSpaceL,
            bottom: MediaQuery.of(context).padding.bottom + 88,
            child: _buildFab(s),
          ),
          Positioned(
            left: kSpaceM,
            right: kSpaceM,
            bottom: MediaQuery.of(context).padding.bottom + kSpaceL,
            child: _buildTabBar(s),
          ),
          if (_showSearch) _buildSearchOverlay(s),
          if (_showEventScreen) _buildEventScreen(s),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColorScheme s) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kSpaceL,
        left: kSpaceM,
        right: kSpaceM,
        bottom: kSpaceM,
      ),
      child: Row(
        children: [
          FluentIconButton(
            s: s,
            child: AppIcon('back_arrow.svg', color: s.onSurfaceVariant, size: 19),
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _navArrow(s, isLeft: true, onTap: _prev),
                GestureDetector(
                  onTap: _goToday,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: kSpaceM, vertical: kSpaceXS),
                    child: Text(
                      _navLabel,
                      style: TextStyle(
                        fontSize: kTypeBodyLarge,
                        fontWeight: FontWeight.w700,
                        color: s.onSurface,
                      ),
                    ),
                  ),
                ),
                _navArrow(s, isLeft: false, onTap: _next),
              ],
            ),
          ),
          FluentIconButton(
            s: s,
            child: AppIcon('search.svg', color: s.onSurfaceVariant, size: 19),
            onTap: _openSearch,
          ),
        ],
      ),
    );
  }

  Widget _navArrow(AppColorScheme s, {required bool isLeft, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusCircle),
      child: Padding(
        padding: EdgeInsets.all(kSpaceS),
        child: AppIcon(
          isLeft ? 'chevron_left.svg' : 'chevron_right.svg',
          color: s.onSurfaceVariant,
          size: 17,
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme s) {
    return SingleChildScrollView(
      child: AnimatedSwitcher(
        duration: kDurationSlow,
        child: _buildView(s),
      ),
    );
  }

  Widget _buildView(AppColorScheme s) {
    switch (_currentView) {
      case AgendaViewMode.month:
        return _buildMonthView(s);
      case AgendaViewMode.week:
        return _buildWeekView(s);
      case AgendaViewMode.day:
        return _buildDayView(s);
      case AgendaViewMode.agenda:
        return _buildAgendaView(s);
    }
  }

  Widget _buildMonthView(AppColorScheme s) {
    final days = _monthDays(_viewDate);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: kSpaceM),
          child: Row(
            children: List.generate(7, (i) {
              final weekend = i == 0 || i == 6;
              return Expanded(
                child: Center(
                  child: Text(
                    ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'][i],
                    style: TextStyle(
                      fontSize: kTypeCaption,
                      fontWeight: FontWeight.w700,
                      color: weekend ? _kWeekendColor : s.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(height: kSpaceXS),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: kSpaceS),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.78,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final inMonth = day.month == _viewDate.month;
            final isToday = _isToday(day);
            final dayEvents = _eventsOnDate(day);
            return _MonthDayCell(
              s: s,
              day: day,
              inMonth: inMonth,
              isToday: isToday,
              events: dayEvents,
              onTap: () {
                setState(() {
                  _selectedDay = day;
                  if (!inMonth) {
                    _viewDate = DateTime(day.year, day.month, 1);
                  }
                });
              },
              onDoubleTap: () => _openNewEvent(date: day),
              onEventTap: (ev) => _openDetail(ev),
            );
          },
        ),
      ],
    );
  }

  List<DateTime> _monthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday % 7));
    return List.generate(42, (i) => start.add(Duration(days: i)));
  }

  Widget _buildWeekView(AppColorScheme s) {
    final weekDays = _weekDays(_selectedDay);
    return Column(
      children: [
        Row(
          children: weekDays.map((d) {
            final isToday = _isToday(d);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = d;
                    _currentView = AgendaViewMode.day;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: kSpaceS),
                  child: Column(
                    children: [
                      Text(
                        ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'][d.weekday],
                        style: TextStyle(
                          fontSize: kTypeCaption,
                          fontWeight: FontWeight.w700,
                          color: (d.weekday == 0 || d.weekday == 6)
                              ? _kWeekendColor
                              : s.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: kSpaceXS),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday ? s.primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: kTypeBody,
                            fontWeight: FontWeight.w700,
                            color: isToday
                                ? s.onPrimary
                                : (d.weekday == 0 || d.weekday == 6)
                                    ? _kWeekendColor
                                    : s.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: kSpaceS),
        Expanded(
          child: ListView.builder(
            itemCount: 24,
            itemBuilder: (context, hour) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Padding(
                      padding: EdgeInsets.only(top: kSpaceXXS),
                      child: Text(
                        hour == 0 ? '' : '${hour.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: kTypeCaption, color: s.onSurfaceVariant),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weekDays.map((d) {
                        final dayEvents =
                            _eventsOnDate(d).where((e) => !e.allDay && e.startTime.hour == hour).toList();
                        return Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: s.subtleFillHover, width: 0.5),
                                right: BorderSide(color: s.subtleFillHover, width: 0.5),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: InkWell(
                                    onDoubleTap: () => _openNewEvent(date: d, hour: hour),
                                    onTap: () {
                                      setState(() => _selectedDay = d);
                                    },
                                  ),
                                ),
                                ...dayEvents.map((ev) => Positioned(
                                      top: kSpaceXXS,
                                      left: kSpaceXXS,
                                      right: kSpaceXXS,
                                      child: _WeekEventChip(
                                        s: s,
                                        event: ev,
                                        onTap: () => _openDetail(ev),
                                      ),
                                    )),
                                if (_isToday(d) && DateTime.now().hour == hour)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: (DateTime.now().minute / 60) * 56,
                                    child: Container(
                                      height: 2,
                                      color: s.primary,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: s.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<DateTime> _weekDays(DateTime focus) {
    final start = focus.subtract(Duration(days: focus.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  Widget _buildDayView(AppColorScheme s) {
    final dayEvents = _eventsOnDate(_selectedDay);
    final allDay = dayEvents.where((e) => e.allDay).toList();
    final timed = dayEvents.where((e) => !e.allDay).toList();
    return Column(
      children: [
        if (allDay.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceS),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: s.subtleFillHover, width: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    'Todo\no dia',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: kTypeCaption, color: s.onSurfaceVariant),
                  ),
                ),
                SizedBox(width: kSpaceS),
                Expanded(
                  child: Column(
                    children: allDay.map((ev) => _AllDayChip(
                          s: s,
                          event: ev,
                          onTap: () => _openDetail(ev),
                        )).toList(),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: 24,
            itemBuilder: (context, hour) {
              final hourEvents = timed.where((e) => e.startTime.hour == hour).toList();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Padding(
                      padding: EdgeInsets.only(top: kSpaceXXS),
                      child: Text(
                        hour == 0 ? '' : '${hour.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: kTypeCaption, color: s.onSurfaceVariant),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: s.subtleFillHover, width: 0.5),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: InkWell(
                              onDoubleTap: () => _openNewEvent(date: _selectedDay, hour: hour),
                              onTap: () {},
                            ),
                          ),
                          ...hourEvents.map((ev) => Positioned(
                                top: kSpaceXXS,
                                left: kSpaceXS,
                                right: kSpaceS,
                                child: _DayEventCard(
                                  s: s,
                                  event: ev,
                                  onTap: () => _openDetail(ev),
                                ),
                              )),
                          if (_isToday(_selectedDay) && DateTime.now().hour == hour)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: (DateTime.now().minute / 60) * 56,
                              child: Container(
                                height: 2,
                                color: s.primary,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: s.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaView(AppColorScheme s) {
    final base = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysWithEvents = <DateTime, List<AgendaEvent>>{};
    for (int i = 0; i < 60; i++) {
      final d = base.add(Duration(days: i));
      final evs = _eventsOnDate(d);
      if (evs.isNotEmpty) daysWithEvents[d] = evs;
    }
    if (daysWithEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon('calendar.svg', color: s.onSurfaceVariant, size: 52),
            SizedBox(height: kSpaceM),
            Text('Sem eventos nos próximos 60 dias',
                style: TextStyle(color: s.onSurfaceVariant, fontSize: kTypeBodyLarge)),
            SizedBox(height: kSpaceM),
            FluentButton(
              s: s,
              label: 'Criar evento',
              onTap: () => _openNewEvent(),
              style: FluentButtonStyle.primary,
            ),
          ],
        ),
      );
    }
    return ListView(
      children: daysWithEvents.entries.map((entry) {
        final date = entry.key;
        final evs = entry.value;
        final isToday = _isToday(date);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceS + kSpaceXXS),
              color: s.surface,
              child: Row(
                children: [
                  Text(
                    ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'][date.weekday],
                    style: TextStyle(
                      fontSize: kTypeCaption,
                      fontWeight: FontWeight.w800,
                      color: isToday ? s.primary : s.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(width: kSpaceS),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? s.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: kTypeBody,
                        fontWeight: FontWeight.w700,
                        color: isToday ? s.onPrimary : s.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(width: kSpaceS),
                  Text(
                    ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'][date.month - 1],
                    style: TextStyle(fontSize: kTypeCaption, color: s.onSurfaceVariant),
                  ),
                  if (isToday) ...[
                    SizedBox(width: kSpaceS),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: kSpaceS, vertical: kSpaceXXS),
                      decoration: BoxDecoration(
                        color: s.primary,
                        borderRadius: BorderRadius.circular(kRadiusCircle),
                      ),
                      child: Text('Hoje',
                          style: TextStyle(fontSize: kTypeCaption, color: s.onPrimary, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
            ),
            ...evs.map((ev) => _AgendaEventTile(
                  s: s,
                  event: ev,
                  onTap: () => _openDetail(ev),
                )),
            SizedBox(height: kSpaceXS),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFab(AppColorScheme s) {
    return Material(
      color: s.primary,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        onTap: () => _openNewEvent(),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: AppIcon('add.svg', color: s.onPrimary, size: 24),
        ),
      ),
    );
  }

  Widget _buildTabBar(AppColorScheme s) {
    return Container(
      padding: EdgeInsets.all(kSpaceXS),
      decoration: BoxDecoration(
        color: s.floatingSurface,
        borderRadius: BorderRadius.circular(kRadiusCircle),
        border: Border.all(color: s.subtleFillHover),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: AgendaViewMode.values.map((mode) {
          final selected = mode == _currentView;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentView = mode),
              borderRadius: BorderRadius.circular(kRadiusCircle),
              child: AnimatedContainer(
                duration: kDurationSlower,
                curve: kFluentDecelerate,
                padding: EdgeInsets.symmetric(vertical: kSpaceS + kSpaceXXS),
                decoration: BoxDecoration(
                  color: selected ? s.subtleFillHover : Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadiusCircle),
                  border: Border.all(
                    color: selected ? s.subtleFillHover : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: kSpaceS,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  mode.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: kTypeCaption,
                    fontWeight: FontWeight.w600,
                    color: selected ? s.onSurface : s.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchOverlay(AppColorScheme s) {
    return Positioned.fill(
      child: Material(
        color: s.surface,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kSpaceL,
                left: kSpaceM,
                right: kSpaceM,
                bottom: kSpaceM,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: kSpaceM),
                      decoration: BoxDecoration(
                        color: s.subtleFillHover,
                        borderRadius: BorderRadius.circular(kRadiusLarge),
                      ),
                      child: Row(
                        children: [
                          AppIcon('search.svg', color: s.onSurfaceVariant, size: 16),
                          SizedBox(width: kSpaceS),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: TextStyle(color: s.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Pesquisar eventos...',
                                hintStyle: TextStyle(color: s.onSurfaceVariant),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: kSpaceS + kSpaceXXS),
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            InkWell(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: AppIcon('close.svg', color: s.onSurfaceVariant, size: 13),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: kSpaceS + kSpaceXXS),
                  InkWell(
                    onTap: _closeSearch,
                    child: Text('Cancelar',
                        style: TextStyle(color: s.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _searchQuery.trim().isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon('calendar.svg', color: s.onSurfaceVariant.withOpacity(0.25), size: 36),
                        SizedBox(height: kSpaceM),
                        Text('Pesquisa por título, local ou descrição',
                            style: TextStyle(color: s.onSurfaceVariant)),
                      ],
                    )
                  : _searchResults.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppIcon('search.svg',
                                color: s.onSurfaceVariant.withOpacity(0.3), size: 40),
                            SizedBox(height: kSpaceM),
                            Text('Sem resultados para «$_searchQuery»',
                                style: TextStyle(color: s.onSurfaceVariant)),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final ev = _searchResults[index];
                            return InkWell(
                              onTap: () {
                                _openDetail(ev);
                                _closeSearch();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceM),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: s.subtleFillHover, width: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: ev.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: kSpaceM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ev.title,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: s.onSurface)),
                                          SizedBox(height: kSpaceXXS),
                                          Text(
                                            '${_formatShortDate(ev.date)}'
                                            '${ev.allDay ? '' : ' · ${_formatTime(ev.startTime)}'}'
                                            '${ev.location.isNotEmpty ? ' · 📍 ${ev.location}' : ''}',
                                            style: TextStyle(
                                                fontSize: kTypeCaption, color: s.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AppIcon('chevron_right.svg',
                                        color: s.onSurfaceVariant.withOpacity(0.4), size: 14),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventScreen(AppColorScheme s) {
    return Positioned.fill(
      child: Material(
        color: s.surface,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kSpaceL,
                left: kSpaceM,
                right: kSpaceM,
                bottom: kSpaceM,
              ),
              child: Row(
                children: [
                  FluentIconButton(
                    s: s,
                    child: AppIcon('close.svg', color: s.onSurfaceVariant, size: 16),
                    onTap: _closeEventScreen,
                  ),
                  Expanded(
                    child: Text(
                      _editing ? 'Editar evento' : 'Novo evento',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, color: s.onSurface),
                    ),
                  ),
                  InkWell(
                    onTap: _saveEvent,
                    child: Text('Guardar',
                        style: TextStyle(fontWeight: FontWeight.w700, color: s.primary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: kSpaceXXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceL),
                      child: FluentTextField(
                        s: s,
                        controller: _titleController,
                        hint: 'Título do evento',
                        autofocus: _editing ? false : true,
                        background: Colors.transparent,
                        radius: kRadiusNone,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cor',
                              style: TextStyle(
                                  fontSize: kTypeCaption,
                                  fontWeight: FontWeight.w700,
                                  color: s.onSurfaceVariant,
                                  letterSpacing: 0.6)),
                          SizedBox(height: kSpaceM),
                          Wrap(
                            spacing: kSpaceS + kSpaceXXS,
                            runSpacing: kSpaceS + kSpaceXXS,
                            children: kEventColors.map((color) {
                              final selected = _formColor == color;
                              return GestureDetector(
                                onTap: () => setState(() => _formColor = color),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: selected
                                        ? Border.all(color: s.surface, width: 3)
                                        : null,
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: color,
                                              spreadRadius: 2,
                                              blurRadius: kSpaceXS,
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: s.subtleFillHover, width: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSettingRow(
                            s,
                            icon: 'clock.svg',
                            label: 'Todo o dia',
                            trailing: AppSwitch(
                              value: _formAllDay,
                              s: s,
                              onChanged: (val) => setState(() => _formAllDay = val),
                            ),
                          ),
                          _buildSettingRow(
                            s,
                            icon: 'calendar.svg',
                            label: 'Data',
                            trailing: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _formDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _formDate = picked);
                              },
                              child: Text(
                                _formatShortDate(_formDate),
                                style: TextStyle(color: s.onSurfaceVariant, fontSize: kTypeBody),
                              ),
                            ),
                          ),
                          if (!_formAllDay) ...[
                            _buildSettingRow(
                              s,
                              icon: 'clock.svg',
                              label: 'Início',
                              trailing: InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _formStart,
                                  );
                                  if (picked != null) setState(() => _formStart = picked);
                                },
                                child: Text(
                                  _formatTime(_formStart),
                                  style: TextStyle(color: s.onSurfaceVariant, fontSize: kTypeBody),
                                ),
                              ),
                            ),
                            _buildSettingRow(
                              s,
                              icon: 'clock.svg',
                              label: 'Fim',
                              trailing: InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _formEnd,
                                  );
                                  if (picked != null) setState(() => _formEnd = picked);
                                },
                                child: Text(
                                  _formatTime(_formEnd),
                                  style: TextStyle(color: s.onSurfaceVariant, fontSize: kTypeBody),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: s.subtleFillHover, width: 0.5),
                        ),
                      ),
                      child: _buildSettingRow(
                        s,
                        icon: 'location.svg',
                        label: 'Local',
                        trailing: Expanded(
                          child: FluentTextField(
                            s: s,
                            controller: _locationController,
                            textAlign: TextAlign.right,
                            hint: 'Adicionar local',
                            background: Colors.transparent,
                            radius: kRadiusNone,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: s.subtleFillHover, width: 0.5),
                        ),
                      ),
                      child: _buildSettingRow(
                        s,
                        icon: 'repeat.svg',
                        label: 'Repetir',
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _formRepeat,
                            dropdownColor: s.floatingSurface,
                            style: TextStyle(color: s.onSurfaceVariant, fontSize: kTypeBody),
                            items: kRepeatOptions.map((val) {
                              return DropdownMenuItem(
                                value: val,
                                child: Text(kRepeatLabels[kRepeatOptions.indexOf(val)]),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _formRepeat = val ?? 'none'),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceM),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppIcon('note.svg', color: s.onSurfaceVariant, size: 18),
                          SizedBox(width: kSpaceM),
                          Expanded(
                            child: FluentTextField(
                              s: s,
                              controller: _descriptionController,
                              maxLines: 4,
                              minLines: 2,
                              hint: 'Adicionar notas...',
                              background: Colors.transparent,
                              radius: kRadiusNone,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_editing)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceXL),
                        child: SizedBox(
                          width: double.infinity,
                          child: FluentButton(
                            s: s,
                            label: 'Eliminar evento',
                            onTap: () => _deleteEvent(_editingEvent!.id),
                            style: FluentButtonStyle.destructive,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(AppColorScheme s,
      {required String icon, required String label, required Widget trailing}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceM),
      child: Row(
        children: [
          AppIcon(icon, color: s.onSurfaceVariant, size: 18),
          SizedBox(width: kSpaceM),
          Text(label,
              style: TextStyle(fontSize: kTypeBodyLarge, fontWeight: FontWeight.w500, color: s.onSurface)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  Widget _MonthDayCell({
    required AppColorScheme s,
    required DateTime day,
    required bool inMonth,
    required bool isToday,
    required List<AgendaEvent> events,
    required VoidCallback onTap,
    required VoidCallback onDoubleTap,
    required void Function(AgendaEvent) onEventTap,
  }) {
    final textColor = inMonth ? s.onSurface : s.onSurfaceVariant.withOpacity(0.5);
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        margin: EdgeInsets.all(kSpaceXXS),
        child: Opacity(
          opacity: inMonth ? 1 : 0.28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 23,
                height: 23,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? s.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: kTypeCaption,
                    fontWeight: FontWeight.w600,
                    color: isToday
                        ? s.onPrimary
                        : (day.weekday == 0 || day.weekday == 6)
                            ? _kWeekendColor
                            : textColor,
                  ),
                ),
              ),
              SizedBox(height: kSpaceXXS),
              ...events.take(3).map((ev) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: kSpaceXXS),
                    child: InkWell(
                      onTap: () => onEventTap(ev),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: kSpaceXXS + 1, vertical: kSpaceXXS),
                        decoration: BoxDecoration(
                          color: ev.color.withOpacity(0.13),
                          border: Border(left: BorderSide(color: ev.color, width: 2.5)),
                          borderRadius: BorderRadius.circular(kRadiusSmall),
                        ),
                        child: Text(
                          '${ev.allDay ? '' : '${_formatTime(ev.startTime)} '}${ev.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: kTypeCaption, color: ev.color),
                        ),
                      ),
                    ),
                  )),
              if (events.length > 3)
                Padding(
                  padding: EdgeInsets.only(left: kSpaceXS),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('+${events.length - 3} mais',
                        style: TextStyle(fontSize: kTypeCaption, fontWeight: FontWeight.w600, color: s.primary)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _WeekEventChip({
    required AppColorScheme s,
    required AgendaEvent event,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: kSpaceXXS, vertical: kSpaceXXS),
        padding: EdgeInsets.symmetric(horizontal: kSpaceXS, vertical: kSpaceXXS),
        decoration: BoxDecoration(
          color: event.color.withOpacity(0.16),
          border: Border(left: BorderSide(color: event.color, width: 3)),
          borderRadius: BorderRadius.circular(kRadiusSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: kTypeCaption,
                    fontWeight: FontWeight.w700,
                    color: event.color)),
            Text(_formatTime(event.startTime),
                style: TextStyle(fontSize: kTypeCaption, color: event.color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _AllDayChip({
    required AppColorScheme s,
    required AgendaEvent event,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: kSpaceXXS),
        padding: EdgeInsets.symmetric(horizontal: kSpaceS, vertical: kSpaceXXS),
        decoration: BoxDecoration(
          color: event.color.withOpacity(0.13),
          border: Border(left: BorderSide(color: event.color, width: 3)),
          borderRadius: BorderRadius.circular(kRadiusMedium),
        ),
        child: Text(event.title,
            style: TextStyle(
                fontSize: kTypeCaption, fontWeight: FontWeight.w600, color: event.color)),
      ),
    );
  }

  Widget _DayEventCard({
    required AppColorScheme s,
    required AgendaEvent event,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: kSpaceXXS),
        padding: EdgeInsets.symmetric(horizontal: kSpaceS + kSpaceXXS, vertical: kSpaceS),
        decoration: BoxDecoration(
          color: event.color.withOpacity(0.1),
          border: Border(left: BorderSide(color: event.color, width: 4)),
          borderRadius: BorderRadius.circular(kRadiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title,
                style: TextStyle(
                    fontSize: kTypeBody,
                    fontWeight: FontWeight.w700,
                    color: event.color)),
            SizedBox(height: kSpaceXXS),
            Text(
              '${_formatTime(event.startTime)} – ${_formatTime(event.endTime)}',
              style: TextStyle(fontSize: kTypeCaption, color: event.color.withOpacity(0.8)),
            ),
            if (event.location.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: kSpaceXXS),
                child: Text('📍 ${event.location}',
                    style: TextStyle(fontSize: kTypeCaption, color: event.color.withOpacity(0.7))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _AgendaEventTile({
    required AppColorScheme s,
    required AgendaEvent event,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceXXS),
        padding: EdgeInsets.symmetric(horizontal: kSpaceM, vertical: kSpaceS + kSpaceXXS),
        decoration: BoxDecoration(
          color: event.color.withOpacity(0.06),
          border: Border(left: BorderSide(color: event.color, width: 4)),
          borderRadius: BorderRadius.circular(kRadiusLarge),
        ),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: event.color, shape: BoxShape.circle)),
            SizedBox(width: kSpaceS + kSpaceXXS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: s.onSurface)),
                  SizedBox(height: kSpaceXXS),
                  Text(
                    event.allDay
                        ? 'Todo o dia'
                        : '${_formatTime(event.startTime)} – ${_formatTime(event.endTime)}',
                    style: TextStyle(fontSize: kTypeCaption, color: s.onSurfaceVariant),
                  ),
                  if (event.description.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: kSpaceXS),
                      child: Text(event.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: kTypeCaption, color: s.onSurfaceVariant.withOpacity(0.75))),
                    ),
                ],
              ),
            ),
            AppIcon('chevron_right.svg', color: s.onSurfaceVariant, size: 14),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatShortDate(DateTime d) {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return '${days[d.weekday]}, ${d.day} ${months[d.month - 1]}';
  }

  String _formatFullDate(DateTime d) {
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    const days = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];
    return '${days[d.weekday]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bottom sheet de detalhe de evento
// ─────────────────────────────────────────────────────────────────────
class _AgendaDetailSheet extends StatelessWidget {
  final AppColorScheme s;
  final AgendaEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AgendaDetailSheet({
    required this.s,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatFullDate(DateTime d) {
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    const days = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];
    return '${days[d.weekday]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FluentBottomSheet(
      s: s,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: kSpaceXS, height: kSpaceXXXL, color: event.color),
              SizedBox(width: kSpaceS + kSpaceXXS),
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontSize: kTypeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: s.onSurface,
                  ),
                ),
              ),
              FluentIconButton(
                s: s,
                child: AppIcon('edit.svg', color: s.primary, size: 18),
                onTap: onEdit,
              ),
              FluentIconButton(
                s: s,
                child: AppIcon('trash.svg', color: s.error, size: 18),
                onTap: onDelete,
              ),
              FluentIconButton(
                s: s,
                child: AppIcon('close.svg', color: s.onSurfaceVariant, size: 14),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          _detailRow(s, 'calendar.svg', _formatFullDate(event.date)),
          if (event.allDay)
            _detailRow(s, 'clock.svg', 'Todo o dia')
          else
            _detailRow(s, 'clock.svg', '${_formatTime(event.startTime)} – ${_formatTime(event.endTime)}'),
          if (event.location.isNotEmpty)
            _detailRow(s, 'location.svg', event.location),
          if (event.repeat != 'none')
            _detailRow(
                s,
                'repeat.svg',
                kRepeatLabels[kRepeatOptions.indexOf(event.repeat)]),
          if (event.description.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceS),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon('note.svg', color: s.onSurfaceVariant, size: 18),
                  SizedBox(width: kSpaceM),
                  Expanded(
                    child: Text(
                      event.description,
                      style: TextStyle(color: s.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(AppColorScheme s, String icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kSpaceL, vertical: kSpaceS),
      child: Row(
        children: [
          AppIcon(icon, color: s.onSurfaceVariant, size: 18),
          SizedBox(width: kSpaceM),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: kTypeBody, color: s.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}