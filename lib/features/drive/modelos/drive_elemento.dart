enum TipoElementoDrive {
  carpeta,
  nota,
  documento,
  codigo;

  String get valor => name;

  static TipoElementoDrive desdeValor(String valor) {
    return TipoElementoDrive.values.firstWhere(
      (tipo) => tipo.valor == valor,
      orElse: () =>
          throw FormatException('Tipo de elemento de Drive inválido: $valor'),
    );
  }
}

/// Un registro persistente del Drive. Las rutas de documentos siempre son
/// relativas a la carpeta privada que administra [DriveRepositorio].
class DriveElemento {
  final String id;
  final String? padreId;
  final TipoElementoDrive tipo;
  final String nombre;
  final String? contenido;
  final String? rutaRelativa;
  final String? mime;
  final int? tamano;
  final DateTime creado;
  final DateTime modificado;
  final bool protegida;
  final bool favorita;
  final String? lenguaje;
  final int orden;
  final int prioridad;

  const DriveElemento({
    required this.id,
    required this.padreId,
    required this.tipo,
    required this.nombre,
    required this.contenido,
    required this.rutaRelativa,
    required this.mime,
    required this.tamano,
    required this.creado,
    required this.modificado,
    this.protegida = false,
    this.favorita = false,
    this.lenguaje,
    this.orden = 0,
    this.prioridad = 0,
  });

  DriveElemento copyWith({
    String? contenido,
    String? lenguaje,
    DateTime? modificado,
  }) {
    return DriveElemento(
      id: id,
      padreId: padreId,
      tipo: tipo,
      nombre: nombre,
      contenido: contenido ?? this.contenido,
      rutaRelativa: rutaRelativa,
      mime: mime,
      tamano: tamano,
      creado: creado,
      modificado: modificado ?? this.modificado,
      protegida: protegida,
      favorita: favorita,
      lenguaje: lenguaje ?? this.lenguaje,
      orden: orden,
      prioridad: prioridad,
    );
  }

  factory DriveElemento.desdeMapa(Map<String, Object?> mapa) {
    return DriveElemento(
      id: mapa['id']! as String,
      padreId: mapa['padre_id'] as String?,
      tipo: TipoElementoDrive.desdeValor(mapa['tipo']! as String),
      nombre: mapa['nombre']! as String,
      contenido: mapa['contenido'] as String?,
      rutaRelativa: mapa['ruta_relativa'] as String?,
      mime: mapa['mime'] as String?,
      tamano: mapa['tamano'] as int?,
      creado: DateTime.fromMillisecondsSinceEpoch(mapa['creado']! as int),
      modificado: DateTime.fromMillisecondsSinceEpoch(
        mapa['modificado']! as int,
      ),
      protegida: (mapa['protegida'] as int? ?? 0) != 0,
      favorita: (mapa['favorita'] as int? ?? 0) != 0,
      lenguaje: mapa['lenguaje'] as String?,
      orden: mapa['orden'] as int? ?? 0,
      prioridad: mapa['prioridad'] as int? ?? 0,
    );
  }

  Map<String, Object?> aMapa() {
    return {
      'id': id,
      'padre_id': padreId,
      'tipo': tipo.valor,
      'nombre': nombre,
      'contenido': contenido,
      'ruta_relativa': rutaRelativa,
      'mime': mime,
      'tamano': tamano,
      'creado': creado.millisecondsSinceEpoch,
      'modificado': modificado.millisecondsSinceEpoch,
      'protegida': protegida ? 1 : 0,
      'favorita': favorita ? 1 : 0,
      'lenguaje': lenguaje,
      'orden': orden,
      'prioridad': prioridad,
    };
  }
}
