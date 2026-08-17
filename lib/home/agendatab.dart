// ══════════════════════════════════════════════════════════════
// FILE: lib/home/agendatab.dart — PARTE 1/2
// Cole a Parte 2 logo a seguir a este bloco, no mesmo ficheiro.
// ══════════════════════════════════════════════════════════════
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
  late DateTime _current; // mês em foco (view Mês)
  late DateTime _focusDay; // dia em foco (view Dia/Semana)
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
    Navigator.of(context).pop(); // fecha o drawer com o push suave nativo
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
      // Duração/curva do push do Drawer nativo do Flutter (DrawerController)
      // não é configurável diretamente, mas o Scaffold já usa 246ms com
      // easeOut — muito próximo do padrão 220ms do resto do app. Para ficar
      // EXATO em 220ms + kCupertinoOut/kCupertinoIn (igual à AnimatedSwitcher
      // da Home), ver _AgendaDrawer abaixo, que embrulha o conteúdo do
      // drawer com a própria animação, independente da do Scaffold.
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
// DRAWER PRÓPRIO DA AGENDA — Dia / Semana / Mês.
// O Drawer nativo do Flutter já anima a 246ms com easeOut ao abrir
// (Curves.easeOut) — muito próximo do "não muito rápido nem lento"
// pedido. Para bater EXATO no padrão do resto do app (220ms +
// kCupertinoOut), o conteúdo interno faz a própria entrada com essa
// duração/curva assim que o Drawer é montado, sobrepondo-se
// visualmente à animação de slide do Scaffold.
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