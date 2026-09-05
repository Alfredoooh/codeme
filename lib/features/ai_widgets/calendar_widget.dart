// ══════════════════════════════════════════════════════════════
// FILE: lib/features/ai_widgets/calendar_widget.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import 'ai_widgets_shared.dart';

// ══════════════════════════════════════════════════════════════
// CALENDÁRIO — CARD
// ══════════════════════════════════════════════════════════════
class AiCalendarWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiCalendarWidget({super.key, required this.json, required this.s});
  @override
  State<AiCalendarWidget> createState() => _AiCalendarWidgetState();
}

class _AiCalendarWidgetState extends State<AiCalendarWidget> {
  late DateTime _month;
  String? _selectedKey;
  bool _found = true;
  String? _humanLabel;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    final json = widget.json;
    _found = json['found'] != false;
    final isoDate = json['isoDate']?.toString();
    _humanLabel = json['humanLabel']?.toString();
    if (_found && isoDate != null) {
      try {
        final d = DateTime.parse(isoDate);
        _month = DateTime(d.year, d.month, 1);
        _selectedKey = isoDate;
      } catch (_) {
        final now = DateTime.now();
        _month = DateTime(now.year, now.month, 1);
      }
    } else {
      final now = DateTime.now();
      _month = DateTime(now.year, now.month, 1);
    }
  }

  void _goToMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  void _selectDay(DateTime day) {
    final key = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    setState(() => _selectedKey = key);
    HapticFeedback.selectionClick();
  }

  void _openNewEvent() async {
    if (_selectedKey == null) return;
    await Navigator.of(context).push(
      AppPageRoute(builder: (_) => _NewEventScreen(s: widget.s, dateKey: _selectedKey!)),
    );
  }

  List<DateTime?> _buildGrid() {
    final firstWeekday = _month.weekday; // 1=segunda
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = (firstWeekday - 1) % 7;
    final grid = <DateTime?>[];
    for (int i = 0; i < leading; i++) {
      grid.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      grid.add(DateTime(_month.year, _month.month, d));
    }
    while (grid.length % 7 != 0) {
      grid.add(null);
    }
    return grid;
  }

  static const _weekdayLabels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
  static const _monthLabels = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final p = _p;

    if (!_found) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(24), boxShadow: p.cardShadow),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('calendar_off', color: p.onSurfaceVariant, size: 28),
            const SizedBox(height: 10),
            Text('Data não reconhecida', style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final grid = _buildGrid();
    final today = DateTime.now();
    final todayKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(24), boxShadow: p.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthLabels[_month.month - 1]} ${_month.year}',
                  style: TextStyle(color: p.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: () => _goToMonth(-1),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: p.navBtnBg, shape: BoxShape.circle),
                  child: AppIcon('chevron_left', color: p.onSurfaceVariant, size: 14),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _goToMonth(1),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: p.navBtnBg, shape: BoxShape.circle),
                  child: AppIcon('chevron_right', color: p.onSurfaceVariant, size: 14),
                ),
              ),
            ],
          ),
          if (_humanLabel != null) ...[
            const SizedBox(height: 2),
            Text(_humanLabel!, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          Row(
            children: _weekdayLabels.map((w) => Expanded(
              child: Center(child: Text(w, style: TextStyle(color: p.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600))),
            )).toList(),
          ),
          const SizedBox(height: 6),
          ...List.generate((grid.length / 7).ceil(), (row) {
            return Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final day = idx < grid.length ? grid[idx] : null;
                if (day == null) return const Expanded(child: SizedBox(height: 38));
                final key = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                final isSelected = key == _selectedKey;
                final isToday = key == todayKey;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDay(day),
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.all(2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? p.primary : (isToday ? p.primary.withOpacity(0.12) : Colors.transparent),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isSelected ? p.onPrimary : (isToday ? p.primary : p.onSurface),
                          fontSize: 13,
                          fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _selectedKey != null ? _openNewEvent : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selectedKey != null ? p.primary : p.optionBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Novo evento',
                style: TextStyle(
                  color: _selectedKey != null ? p.onPrimary : p.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — NOVO EVENTO
// ══════════════════════════════════════════════════════════════
class _NewEventScreen extends StatefulWidget {
  final AppColorScheme s;
  final String dateKey;
  const _NewEventScreen({required this.s, required this.dateKey});
  @override State<_NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<_NewEventScreen> {
  final _nameCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  Color _color = const Color(0xFF2F7BF6);

  static const _colorOptions = [
    Color(0xFF2F7BF6), Color(0xFF4EC994), Color(0xFFE0A93E),
    Color(0xFFE05E5E), Color(0xFF9B6EE0), Color(0xFF3EC7E0),
  ];

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: 'Novo evento', onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.dateKey, style: TextStyle(color: p.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 20),
              _FieldLabel(p: p, text: 'Nome do evento'),
              const SizedBox(height: 6),
              _StyledField(p: p, controller: _nameCtrl, hint: 'Ex: Reunião com equipa'),
              const SizedBox(height: 16),
              _FieldLabel(p: p, text: 'Hora'),
              const SizedBox(height: 6),
              _StyledField(p: p, controller: _timeCtrl, hint: 'Ex: 14:00', keyboardType: TextInputType.datetime),
              const SizedBox(height: 16),
              _FieldLabel(p: p, text: 'Cor'),
              const SizedBox(height: 10),
              Row(
                children: _colorOptions.map((c) {
                  final active = c.value == _color.value;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 34, height: 34,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: active ? Border.all(color: p.onSurface, width: 2) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (_nameCtrl.text.trim().isEmpty) return;
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('Guardar evento', style: TextStyle(color: p.onPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final WidgetPalette p;
  final String text;
  const _FieldLabel({required this.p, required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600));
  }
}

class _StyledField extends StatelessWidget {
  final WidgetPalette p;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _StyledField({required this.p, required this.controller, required this.hint, this.keyboardType});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: p.onSurface, fontSize: 14.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: p.onSurfaceVariant, fontSize: 14.5),
        ),
      ),
    );
  }
}