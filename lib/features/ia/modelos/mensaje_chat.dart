/// Representa un mensaje en la conversación del chat IA.
enum RolMensaje {
  /// Mensaje de configuración del sistema (invisible para el usuario).
  sistema,

  /// Mensaje enviado por el usuario.
  usuario,

  /// Mensaje generado por el asistente IA.
  asistente,
}

/// Tipo de contenido multimodal.
enum TipoParte { texto, imagen, documento }

/// Parte de un mensaje multimodal (texto o imagen).
class ParteMensaje {
  final TipoParte tipo;
  final String? texto; // Para tipo texto
  final String? dataUrl; // Data URL de imagen: data:image/jpeg;base64,...
  final String? nombreArchivo;

  const ParteMensaje.texto(this.texto)
    : tipo = TipoParte.texto,
      dataUrl = null,
      nombreArchivo = null;

  const ParteMensaje.imagen(this.dataUrl)
    : tipo = TipoParte.imagen,
      texto = null,
      nombreArchivo = null;

  const ParteMensaje.documento({
    required String nombre,
    required String contenido,
  }) : tipo = TipoParte.documento,
       texto = contenido,
       dataUrl = null,
       nombreArchivo = nombre;

  Map<String, dynamic> aJson() => {
    'tipo': tipo.name,
    'texto': texto,
    'dataUrl': dataUrl,
    'nombreArchivo': nombreArchivo,
  };

  factory ParteMensaje.desdeJson(Map<String, dynamic> json) {
    final tipo = TipoParte.values.byName(json['tipo'] as String);
    return switch (tipo) {
      TipoParte.texto => ParteMensaje.texto(json['texto'] as String? ?? ''),
      TipoParte.imagen => ParteMensaje.imagen(json['dataUrl'] as String?),
      TipoParte.documento => ParteMensaje.documento(
        nombre: json['nombreArchivo'] as String? ?? 'archivo',
        contenido: json['texto'] as String? ?? '',
      ),
    };
  }

  /// Convierte al formato multimodal compatible con proveedores OpenAI.
  Map<String, dynamic> aMapaApi() {
    switch (tipo) {
      case TipoParte.texto:
        return {'type': 'text', 'text': texto ?? ''};
      case TipoParte.imagen:
        return {
          'type': 'image_url',
          'image_url': {'url': dataUrl ?? ''},
        };
      case TipoParte.documento:
        return {
          'type': 'text',
          'text':
              '[Documento adjunto: ${nombreArchivo ?? 'archivo'}]\n${texto ?? ''}',
        };
    }
  }
}

class MensajeChat {
  final RolMensaje rol;
  final List<ParteMensaje> partes;
  final DateTime hora;
  final bool esError;
  final KomandoAgente? comando;

  const MensajeChat({
    required this.rol,
    required this.partes,
    required this.hora,
    this.esError = false,
    this.comando,
  });

  /// Compatibilidad: crea mensaje solo texto (legacy).
  factory MensajeChat.texto({
    required RolMensaje rol,
    required String texto,
    required DateTime hora,
    bool esError = false,
    KomandoAgente? comando,
  }) {
    return MensajeChat(
      rol: rol,
      partes: [ParteMensaje.texto(texto)],
      hora: hora,
      esError: esError,
      comando: comando,
    );
  }

  Map<String, dynamic> aJson() => {
    'rol': rol.name,
    'partes': partes.map((parte) => parte.aJson()).toList(),
    'hora': hora.toIso8601String(),
    'esError': esError,
    'comando': comando == null
        ? null
        : {
            'tipo': comando!.tipo.name,
            'ejecutado': comando!.ejecutado,
            'descripcion': comando!.descripcion,
          },
  };

  factory MensajeChat.desdeJson(Map<String, dynamic> json) {
    final comandoJson = json['comando'] as Map<String, dynamic>?;
    return MensajeChat(
      rol: RolMensaje.values.byName(json['rol'] as String),
      partes: (json['partes'] as List<dynamic>)
          .map(
            (parte) =>
                ParteMensaje.desdeJson(Map<String, dynamic>.from(parte as Map)),
          )
          .toList(),
      hora: DateTime.parse(json['hora'] as String),
      esError: json['esError'] as bool? ?? false,
      comando: comandoJson == null
          ? null
          : KomandoAgente(
              tipo: TipoComandoAgente.values.byName(
                comandoJson['tipo'] as String,
              ),
              ejecutado: comandoJson['ejecutado'] as bool? ?? false,
              descripcion: comandoJson['descripcion'] as String?,
            ),
    );
  }

  /// Texto plano concatenado para mostrar en UI.
  String get textoPlano => partes
      .where((p) => p.tipo == TipoParte.texto)
      .map((p) => p.texto ?? '')
      .join('\n');

  bool get tieneImagenes => partes.any((p) => p.tipo == TipoParte.imagen);

  /// Convierte al formato multimodal compatible con proveedores OpenAI.
  Map<String, dynamic> aMapaApi() {
    return {
      'role': switch (rol) {
        RolMensaje.sistema => 'system',
        RolMensaje.usuario => 'user',
        RolMensaje.asistente => 'assistant',
      },
      'content': partes.map((p) => p.aMapaApi()).toList(),
    };
  }
}

/// Comando JSON que la IA emitió para actuar sobre el Drive.
class KomandoAgente {
  final TipoComandoAgente tipo;
  final bool ejecutado;
  final String? descripcion;

  const KomandoAgente({
    required this.tipo,
    this.ejecutado = false,
    this.descripcion,
  });
}

enum TipoComandoAgente { crearNota, crearCarpeta, modificarNota, desconocido }
