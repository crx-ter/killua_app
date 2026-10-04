class EventoCalendario {
  final String id;
  final DateTime fecha;
  final String titulo;
  final String? descripcion;
  final int? color;
  final bool completado;

  EventoCalendario({
    required this.id,
    required this.fecha,
    required this.titulo,
    this.descripcion,
    this.color,
    this.completado = false,
  });

  factory EventoCalendario.desdeMapa(Map<String, dynamic> mapa) {
    return EventoCalendario(
      id: mapa['id'] as String,
      fecha: DateTime.fromMillisecondsSinceEpoch(mapa['fecha'] as int),
      titulo: mapa['titulo'] as String,
      descripcion: mapa['descripcion'] as String?,
      color: mapa['color'] as int?,
      completado: (mapa['completado'] as int? ?? 0) != 0,
    );
  }

  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'fecha': fecha.millisecondsSinceEpoch,
      'titulo': titulo,
      'descripcion': descripcion,
      'color': color,
      'completado': completado ? 1 : 0,
    };
  }
}
