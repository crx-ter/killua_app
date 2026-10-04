import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../../../services/theme_config_service.dart';
import 'calendario_repositorio.dart';
import 'evento_calendario.dart';

class CalendarioWidget extends StatefulWidget {
  const CalendarioWidget({super.key});

  @override
  State<CalendarioWidget> createState() => _CalendarioWidgetState();
}

class _CalendarioWidgetState extends State<CalendarioWidget> {
  final _repositorio = CalendarioRepositorio();
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _diaEnfocado = DateTime.now();
  List<EventoCalendario> _eventos = [];
  Map<DateTime, List<EventoCalendario>> _eventosPorDia = {};
  bool _cargando = false;
  bool _localeListo = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES').then((_) {
      if (mounted) setState(() => _localeListo = true);
    });
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    setState(() => _cargando = true);
    final todos = await _repositorio.listarTodosLosEventos();

    final map = <DateTime, List<EventoCalendario>>{};
    for (var e in todos) {
      final dia = DateTime(e.fecha.year, e.fecha.month, e.fecha.day);
      if (map[dia] == null) map[dia] = [];
      map[dia]!.add(e);
    }

    final eventosDia = await _repositorio.listarEventosDelDia(_diaSeleccionado);

    if (mounted) {
      setState(() {
        _eventosPorDia = map;
        _eventos = eventosDia;
        _cargando = false;
      });
    }
  }

  List<EventoCalendario> _obtenerEventosParaDia(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return _eventosPorDia[d] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_diaSeleccionado, selectedDay)) {
      setState(() {
        _diaSeleccionado = selectedDay;
        _diaEnfocado = focusedDay;
      });
      _cargarEventos();
    }
  }

  Future<void> _crearEvento() async {
    final titulo = await mostrarGlassDialog<String>(
      context: context,
      child: _DialogoNuevoEvento(),
    );
    if (titulo == null || titulo.trim().isEmpty) return;

    await _repositorio.crearEvento(
      fecha: _diaSeleccionado,
      titulo: titulo.trim(),
    );
    _cargarEventos();
  }

  Future<void> _eliminarEvento(EventoCalendario evento) async {
    await _repositorio.eliminarEvento(evento.id);
    _cargarEventos();
  }

  Future<void> _alternarCompletado(EventoCalendario evento) async {
    await _repositorio.alternarCompletado(evento);
    _cargarEventos();
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfigService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: TableCalendar<EventoCalendario>(
            locale: _localeListo ? 'es_ES' : null,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _diaEnfocado,
            selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
            onDaySelected: _onDaySelected,
            eventLoader: _obtenerEventosParaDia,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              defaultTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.amberAccent,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.amberAccent,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white),
              weekendStyle: TextStyle(color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tareas del día',
              style: TextStyle(
                color: themeConfig.currentTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: themeConfig.currentTextColor),
              onPressed: _crearEvento,
            ),
          ],
        ),
        if (_cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          )
        else if (_eventos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No hay tareas o eventos para este día.',
              style: TextStyle(
                color: themeConfig.currentTextColor.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ..._eventos.map(
            (evento) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GlassCard(
                padding: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Checkbox(
                    value: evento.completado,
                    onChanged: (_) => _alternarCompletado(evento),
                    activeColor: Colors.amberAccent,
                    checkColor: Colors.black,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  title: Text(
                    evento.titulo,
                    style: TextStyle(
                      color: Colors.white,
                      decoration: evento.completado
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Colors.white54,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => _eliminarEvento(evento),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DialogoNuevoEvento extends StatefulWidget {
  @override
  State<_DialogoNuevoEvento> createState() => _DialogoNuevoEventoState();
}

class _DialogoNuevoEventoState extends State<_DialogoNuevoEvento> {
  final _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nuevo Evento/Tarea',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controlador,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Título',
              labelStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
            onSubmitted: (valor) => Navigator.of(context).pop(valor.trim()),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controlador.text.trim()),
                child: const Text('Crear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
