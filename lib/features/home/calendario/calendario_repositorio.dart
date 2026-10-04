import 'package:uuid/uuid.dart';

import '../../drive/datos/drive_base_datos.dart';
import 'evento_calendario.dart';

class CalendarioRepositorio {
  CalendarioRepositorio({DriveBaseDatos? baseDatos})
    : _baseDatos = baseDatos ?? DriveBaseDatos.instancia;

  final DriveBaseDatos _baseDatos;
  final _uuid = const Uuid();

  Future<List<EventoCalendario>> listarEventosDelDia(DateTime dia) async {
    final db = await _baseDatos.baseDatos;
    final inicioDia = DateTime(
      dia.year,
      dia.month,
      dia.day,
    ).millisecondsSinceEpoch;
    final finDia = DateTime(
      dia.year,
      dia.month,
      dia.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final filas = await db.query(
      'eventos_calendario',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [inicioDia, finDia],
      orderBy: 'fecha ASC',
    );
    return filas.map(EventoCalendario.desdeMapa).toList();
  }

  Future<List<EventoCalendario>> listarTodosLosEventos() async {
    final db = await _baseDatos.baseDatos;
    final filas = await db.query('eventos_calendario');
    return filas.map(EventoCalendario.desdeMapa).toList();
  }

  Future<EventoCalendario> crearEvento({
    required DateTime fecha,
    required String titulo,
    String? descripcion,
    int? color,
  }) async {
    final db = await _baseDatos.baseDatos;
    final evento = EventoCalendario(
      id: _uuid.v4(),
      fecha: fecha,
      titulo: titulo,
      descripcion: descripcion,
      color: color,
    );
    await db.insert('eventos_calendario', evento.aMapa());
    return evento;
  }

  Future<void> alternarCompletado(EventoCalendario evento) async {
    final db = await _baseDatos.baseDatos;
    await db.update(
      'eventos_calendario',
      {'completado': evento.completado ? 0 : 1},
      where: 'id = ?',
      whereArgs: [evento.id],
    );
  }

  Future<void> eliminarEvento(String id) async {
    final db = await _baseDatos.baseDatos;
    await db.delete('eventos_calendario', where: 'id = ?', whereArgs: [id]);
  }
}
