import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ia_config_service.dart';
import '../../services/ia_orquestador_service.dart';
import '../../services/document_reader.dart';
import '../drive/datos/drive_repositorio.dart';
import '../drive/modelos/drive_elemento.dart';
import 'modelos/mensaje_chat.dart';

/// Delimitadores del bloque de comando JSON que la IA debe emitir.
const _kInicioCmd = '<<<KILLUA_CMD';
const _kFinCmd = 'KILLUA_CMD>>>';

/// Controlador del chat IA con modo agente. Gestiona el historial de mensajes,
/// inyecta contexto de carpetas, e inyecta imágenes de las notas para que el
/// modelo multimodal pueda analizarlas.
class ChatIaControlador extends ChangeNotifier {
  ChatIaControlador({DriveRepositorio? repositorio})
    : _repositorio = repositorio ?? DriveRepositorio();

  final DriveRepositorio _repositorio;
  bool _disposed = false;

  // ─── Estado público ────────────────────────────────────────────────────

  final List<MensajeChat> historial = [];
  bool cargando = false;
  DriveElemento? carpetaContexto;
  List<ParteMensaje>? parteImagenesAdjunta; // Imágenes adjuntas por el usuario
  final List<ChatGuardado> chatsRecientes = [];

  Future<void> cargarChatsRecientes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('killua_chats_recientes') ?? [];
    chatsRecientes
      ..clear()
      ..addAll(
        raw.map((item) {
          try {
            return ChatGuardado.fromJson(
              Map<String, dynamic>.from(jsonDecode(item) as Map),
            );
          } catch (_) {
            return null;
          }
        }).whereType<ChatGuardado>(),
      );
    _safeNotify();
  }

  Future<void> abrirChatReciente(ChatGuardado chat) async {
    historial
      ..clear()
      ..addAll(chat.mensajes);
    _safeNotify();
  }

  Future<void> _guardarChatActual() async {
    if (historial.isEmpty) return;
    final titulo = historial
        .firstWhere(
          (mensaje) => mensaje.rol == RolMensaje.usuario,
          orElse: () => historial.first,
        )
        .textoPlano
        .trim();
    if (titulo.isEmpty) return;
    final chat = ChatGuardado(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: titulo.length > 60 ? '${titulo.substring(0, 60)}...' : titulo,
      actualizado: DateTime.now(),
      mensajes: List<MensajeChat>.from(historial),
    );
    chatsRecientes.removeWhere((item) => item.titulo == chat.titulo);
    chatsRecientes.insert(0, chat);
    if (chatsRecientes.length > 20) chatsRecientes.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'killua_chats_recientes',
      chatsRecientes.map((item) => jsonEncode(item.toJson())).toList(),
    );
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ─── Contexto / carpeta ────────────────────────────────────────────────

  /// Asigna la carpeta cuyo contenido se inyectará al System Prompt.
  Future<void> asignarCarpetaContexto(DriveElemento carpeta) async {
    carpetaContexto = carpeta;
    _safeNotify();
  }

  void quitarCarpetaContexto() {
    carpetaContexto = null;
    _safeNotify();
  }

  // ─── Envío de mensajes ─────────────────────────────────────────────────

  /// Agrega el mensaje del usuario al historial y solicita respuesta a la IA.
  Future<void> enviar(
    String texto, {
    List<ParteMensaje>? imagenesAdjuntas,
  }) async {
    final textoLimpio = texto.trim();
    // Usar imágenes adjuntas pasadas por parámetro o las guardadas en el estado
    final imagenes = imagenesAdjuntas ?? parteImagenesAdjunta;
    if (textoLimpio.isEmpty && (imagenes == null || imagenes.isEmpty)) {
      return;
    }
    if (cargando) return;

    // 1. Agregar mensaje del usuario
    final partes = <ParteMensaje>[];
    if (textoLimpio.isNotEmpty) {
      partes.add(ParteMensaje.texto(textoLimpio));
    }
    if (imagenes != null && imagenes.isNotEmpty) {
      partes.addAll(imagenes);
    }
    historial.add(
      MensajeChat(
        rol: RolMensaje.usuario,
        partes: partes,
        hora: DateTime.now(),
      ),
    );
    parteImagenesAdjunta = null; // Limpiar imágenes adjuntas después de usar
    cargando = true;
    _safeNotify();

    try {
      // 2. Leer configuración de IA
      final config = await IaConfigService.leer();
      if (!config.lista) {
        _agregarError(
          'No hay API key configurada. Ve a Ajustes → IA para configurarla.',
        );
        return;
      }

      // 3. Construir contexto de Drive si hay carpeta seleccionada
      final contextoDrive = await _construirContextoDrive();

      // 4. Construir lista de mensajes para la API (multimodal)
      final mensajesApi = _construirMensajesApi(
        contextoDrive: contextoDrive,
        config: config,
      );

      // 5. Llamar a la IA
      final respuestaRaw = await IaOrquestadorService.enviarMultimodal(
        config: config,
        mensajes: mensajesApi,
        maxTokens: 8192,
      );

      // 6. Parsear respuesta: separar texto visible de bloque de comando
      final (textoVisible, rawJson) = _parsearRespuesta(respuestaRaw);

      // 7. Ejecutar comando si existe
      KomandoAgente? comandoEjecutado;
      if (rawJson != null) {
        comandoEjecutado = await _ejecutarComando(rawJson);
      }

      // 8. Agregar respuesta visible al historial
      historial.add(
        MensajeChat(
          rol: RolMensaje.asistente,
          partes: [
            ParteMensaje.texto(
              textoVisible.trim().isEmpty
                  ? '✅ Acción ejecutada correctamente.'
                  : textoVisible.trim(),
            ),
          ],
          hora: DateTime.now(),
          comando: comandoEjecutado,
        ),
      );
      await _guardarChatActual();
    } on IaOrquestadorException catch (e) {
      _agregarError(e.mensaje);
    } catch (e) {
      _agregarError('Error inesperado: $e');
    } finally {
      cargando = false;
      _safeNotify();
    }
  }

  // ─── Construcción del System Prompt ────────────────────────────────────

  List<Map<String, dynamic>> _construirMensajesApi({
    required ContextoDrive contextoDrive,
    required IaConfig config,
  }) {
    final systemPrompt = _buildSystemPrompt(contextoDrive);

    final mensajesApi = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // Encontrar el índice del último mensaje de usuario en el historial
    final ultimoUsuarioIndex = [
      for (int i = 0; i < historial.length; i++)
        if (historial[i].rol == RolMensaje.usuario) i,
    ].lastOrNull;

    for (int i = 0; i < historial.length; i++) {
      final msg = historial[i];
      if (msg.rol == RolMensaje.sistema) continue;

      var mapaMsg = msg.aMapaApi();

      // Si es el último mensaje del usuario, inyectar imágenes del contexto
      if (i == ultimoUsuarioIndex && contextoDrive.imagenes.isNotEmpty) {
        if (mapaMsg['content'] is List) {
          (mapaMsg['content'] as List).addAll(
            contextoDrive.imagenes.map((img) => img.aMapaApi()),
          );
        }
      }

      mensajesApi.add(mapaMsg);
    }

    return mensajesApi;
  }

  String _buildSystemPrompt(ContextoDrive contextoDrive) {
    return '''
Eres KILLUA, la IA educativa, organizadora y ejecutora integrada en Killua.
Tu trabajo es transformar información del usuario en aprendizaje claro, estructuras de Drive útiles y notas ricas que puedan continuar editándose.

══ PRIORIDAD DE INFORMACIÓN ══
1. Archivos, imágenes, documentos y carpetas proporcionados por el usuario.
2. Elementos relacionados del contexto de Drive.
3. Conocimientos generales solo para explicar o conectar conceptos.
4. Información externa solo si el usuario la solicita y debes marcarla como "Información complementaria".
Nunca inventes contenido ni afirmes haber leído un archivo que no aparece en el contexto.

══ COMPORTAMIENTO EDUCATIVO ══
- Responde en el idioma del usuario y adapta la dificultad a su nivel.
- Si pide un curso, curso completo, aprender desde cero, organizar un archivo como curso o enseñarle todo, analiza primero el material y crea una estructura proporcional: información, objetivos, conocimientos previos, módulos, lecciones, práctica, evaluaciones, resumen y progreso.
- No resumas un documento cuando pidió un curso. Conserva definiciones, fórmulas, procedimientos, ejemplos, tablas, código, reglas, excepciones y ejercicios relevantes.
- Cada lección debe incluir objetivo, explicación progresiva, conceptos, ejemplos basados en la fuente, pasos, práctica básica/intermedia/avanzada, comprobación, resumen y requisitos previos.
- Mantén trazabilidad: incluye en cada nota una sección breve "Fuente" con el archivo, carpeta o sección de origen cuando esa información exista.
- Si el usuario pide continuar, modificar un módulo o agregar ejercicios, usa los IDs y contenidos existentes y modifica solo lo solicitado.

══ ACCIONES EN DRIVE ══
Puedes crear carpetas y notas, continuar dentro de carpetas existentes y modificar notas existentes.
No elimines, sobrescribas ni reemplaces contenido importante sin confirmación expresa.
No inventes IDs: usa solo IDs del contexto. Para elementos creados en el mismo lote usa referencias como padreId "@curso".
Si el usuario indica una carpeta por nombre, busca su ID en el contexto; si hay varias coincidencias, pide aclaración.

Cuando ejecutes acciones, coloca AL FINAL un bloque sin Markdown:
$_kInicioCmd
[
  {"comando":"crear_carpeta","padreId":null,"nombre":"Curso — Tema","referencia":"curso"},
  {"comando":"crear_nota","padreId":"@curso","titulo":"01 — Introducción","contenido":"# Título\n\nContenido de la lección.","protegida":false}
]
$_kFinCmd

Comandos:
- crear_carpeta: comando, padreId, nombre, referencia opcional.
- crear_nota: comando, padreId, titulo, contenidoDelta o contenido, protegida opcional.
- modificar_nota: comando, id exacto, contenidoDelta o contenido. Solo modifica una nota existente.

══ NOTAS EDITABLES Y NOTAS INTERNAS ══
- protegida:false: nota de estudio, ejercicios, resumen, apuntes o plantilla que el usuario debe poder editar.
- protegida:true: nota técnica interna para la IA, índice de navegación, metadatos o estructura especializada que el usuario no debe editar.
- Por defecto usa protegida:false. Usa true solo cuando la nota sea realmente interna y explica brevemente que es una nota protegida.

══ FORMATO ENRIQUECIDO OBLIGATORIO ══
Las notas nuevas deben usar el campo contenido con Markdown estándar: títulos, listas, checklists, citas, tablas, imágenes, enlaces, fórmulas delimitadas y bloques de código.
El editor de notas usa AppFlowy Editor y conserva el formato como documento estructurado. Para una nota nueva, prioriza Markdown legible; el campo contenidoDelta antiguo solo se acepta por compatibilidad con notas existentes.
Ejemplo: # Título, **negrita**, - lista, > cita y ```dart para código.
No uses HTML.

Plantilla mínima de lección: título, objetivo, explicación, conceptos importantes, ejemplo, pasos, práctica, comprobación, errores comunes, resumen y fuente.

══ ARCHIVOS Y ADJUNTOS ══
Usa como fuente principal todo PDF, Word, TXT, Markdown, CSV, JSON, Excel, PowerPoint, código, imagen, guía, manual o carpeta adjunta. Los documentos llegan como texto extraído y las imágenes como contenido visual. Si algo no pudo leerse, dilo y no lo completes inventando.

══ CONTEXTO DEL DRIVE ══
${contextoDrive.texto.isEmpty ? '(Sin carpeta seleccionada. Para crear en raíz usa padreId: null.)' : contextoDrive.texto}
''';
  }

  // ─── Lectura de notas de la carpeta ────────────────────────────────────

  Future<ContextoDrive> _construirContextoDrive() async {
    final carpeta = carpetaContexto;
    if (carpeta == null) return ContextoDrive(texto: '', imagenes: const []);

    final buffer = StringBuffer();
    buffer.writeln(
      'Carpeta seleccionada: "${carpeta.nombre}" (ID: ${carpeta.id})',
    );
    buffer.writeln();
    // Leer todos los elementos de la carpeta (recursivo en 1 nivel)
    await _escribirContenidoCarpeta(buffer, carpeta.id, profundidad: 0);

    final imagenes = <ParteMensaje>[];
    await _extraerImagenesDeCarpeta(
      carpeta.id,
      buffer: buffer,
      imagenes: imagenes,
    );

    return ContextoDrive(texto: buffer.toString(), imagenes: imagenes);
  }

  Future<void> _escribirContenidoCarpeta(
    StringBuffer buffer,
    String carpetaId, {
    required int profundidad,
  }) async {
    if (profundidad > 3) return; // Límite de profundidad para no saturar
    final elementos = await _repositorio.listar(carpetaId);

    for (final elemento in elementos) {
      final sangria = '  ' * profundidad;
      switch (elemento.tipo) {
        case TipoElementoDrive.carpeta:
          buffer.writeln(
            '$sangria📁 Carpeta: "${elemento.nombre}" (ID: ${elemento.id})',
          );
          await _escribirContenidoCarpeta(
            buffer,
            elemento.id,
            profundidad: profundidad + 1,
          );
        case TipoElementoDrive.nota:
          final contenido = elemento.contenido ?? '';
          // Limitar contenido largo para no saturar el context window
          final resumen = contenido.length > 1500
              ? '${contenido.substring(0, 1500)}...[contenido truncado]'
              : contenido;
          buffer.writeln(
            '$sangria📝 Nota: "${elemento.nombre}" (ID: ${elemento.id})',
          );
          if (resumen.isNotEmpty) {
            buffer.writeln('$sangria   Contenido:');
            buffer.writeln('$sangria   ---');
            for (final linea in resumen.split('\n')) {
              buffer.writeln('$sangria   $linea');
            }
            buffer.writeln('$sangria   ---');
          }
        case TipoElementoDrive.documento:
          buffer.writeln(
            '$sangria📄 Documento: "${elemento.nombre}" (ID: ${elemento.id})',
          );
          if (elemento.rutaRelativa != null) {
            try {
              final archivo = await _repositorio.archivoDeDocumento(
                elemento.rutaRelativa!,
              );
              if (await archivo.exists()) {
                final bytes = await archivo.readAsBytes();
                final texto = await DocumentReader.extractText(
                  bytes,
                  mime: elemento.mime ?? '',
                );
                if (texto != null && texto.isNotEmpty) {
                  final resumen = texto.length > 2000
                      ? '${texto.substring(0, 2000)}...[texto truncado]'
                      : texto;
                  buffer.writeln('$sangria   Contenido extraído:');
                  buffer.writeln('$sangria   ---');
                  for (final linea in resumen.split('\n')) {
                    buffer.writeln('$sangria   $linea');
                  }
                  buffer.writeln('$sangria   ---');
                } else {
                  buffer.writeln(
                    '$sangria   [formato binario, no legible directamente]',
                  );
                }
              }
            } catch (_) {
              buffer.writeln(
                '$sangria   [no se pudo leer el contenido del documento]',
              );
            }
          }
        case TipoElementoDrive.codigo:
          buffer.writeln(
            '$sangria💻 Código: "${elemento.nombre}" (ID: ${elemento.id})',
          );
          if (elemento.contenido?.isNotEmpty ?? false) {
            final resumen = elemento.contenido!.length > 1500
                ? '${elemento.contenido!.substring(0, 1500)}...[contenido truncado]'
                : elemento.contenido!;
            buffer.writeln('$sangria   Contenido:');
            buffer.writeln('$sangria   ---');
            buffer.writeln('$sangria   $resumen');
            buffer.writeln('$sangria   ---');
          }
      }
    }
  }

  Future<void> _extraerImagenesDeCarpeta(
    String carpetaId, {
    required StringBuffer buffer,
    required List<ParteMensaje> imagenes,
  }) async {
    final elementos = await _repositorio.listar(carpetaId);

    for (final elemento in elementos) {
      if (elemento.tipo == TipoElementoDrive.nota) {
        final notasImagenes = await _extraerImagenesDeNota(elemento);
        imagenes.addAll(notasImagenes);
      } else if (elemento.tipo == TipoElementoDrive.carpeta) {
        await _extraerImagenesDeCarpeta(
          elemento.id,
          buffer: buffer,
          imagenes: imagenes,
        );
      }
    }
  }

  Future<List<ParteMensaje>> _extraerImagenesDeNota(DriveElemento nota) async {
    final partes = <ParteMensaje>[];
    final contenido = nota.contenido ?? '';
    if (contenido.isEmpty) return partes;

    try {
      final json = jsonDecode(contenido);
      if (json is List) {
        for (final op in json) {
          if (op is Map && op['insert'] != null) {
            final insert = op['insert'];
            if (insert is Map && insert['image'] != null) {
              final ruta = insert['image'] as String;
              if (ruta.startsWith('data:')) {
                partes.add(ParteMensaje.imagen(ruta));
              } else if (ruta.startsWith('http')) {
                // Externas: no las incluimos porque no podemos leerlas.
                // Se pueden incluir como referencia textual.
              } else {
                final file = File(ruta);
                if (await file.exists()) {
                  final bytes = await file.readAsBytes();
                  final mime = _mimeDesdeRuta(ruta);
                  partes.add(
                    ParteMensaje.imagen(
                      'data:$mime;base64,${base64Encode(bytes)}',
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Si no es delta JSON válido, ignorar
    }
    return partes;
  }

  String _mimeDesdeRuta(String ruta) {
    final extension = ruta.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }

  // ─── Parseo de la respuesta ────────────────────────────────────────────

  /// Extrae el texto visible y el JSON de comando de la respuesta de la IA.
  /// Retorna (textoVisible, jsonString | null).
  (String, String?) _parsearRespuesta(String respuesta) {
    final inicioIdx = respuesta.indexOf(_kInicioCmd);
    final finIdx = respuesta.indexOf(_kFinCmd);

    if (inicioIdx == -1 || finIdx == -1 || finIdx <= inicioIdx) {
      return (respuesta, null);
    }

    final textoVisible = respuesta.substring(0, inicioIdx).trim();
    final rawJson = respuesta
        .substring(inicioIdx + _kInicioCmd.length, finIdx)
        .trim();

    return (textoVisible, rawJson);
  }

  // ─── Ejecución de comandos ─────────────────────────────────────────────

  Future<KomandoAgente> _ejecutarComando(String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        int exitosos = 0;
        final referencias = <String, String>{};
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            await _ejecutarUnSoloComando(item, referencias);
            exitosos++;
          }
        }
        return KomandoAgente(
          tipo: TipoComandoAgente.crearNota, // Arbitrario, ya que son múltiples
          ejecutado: true,
          descripcion: '$exitosos acciones ejecutadas en lote',
        );
      } else if (decoded is Map<String, dynamic>) {
        return await _ejecutarUnSoloComando(decoded, <String, String>{});
      }

      return const KomandoAgente(
        tipo: TipoComandoAgente.desconocido,
        ejecutado: false,
        descripcion: 'Formato de comando inválido',
      );
    } catch (e) {
      return KomandoAgente(
        tipo: TipoComandoAgente.desconocido,
        ejecutado: false,
        descripcion: 'Error al ejecutar comando: $e',
      );
    }
  }

  Future<KomandoAgente> _ejecutarUnSoloComando(
    Map<String, dynamic> mapa,
    Map<String, String> referencias,
  ) async {
    final comando = mapa['comando'] as String?;

    switch (comando) {
      case 'crear_nota':
        return await _ejecutarCrearNota(mapa, referencias);
      case 'crear_carpeta':
        return await _ejecutarCrearCarpeta(mapa, referencias);
      case 'modificar_nota':
        return await _ejecutarModificarNota(mapa);
      default:
        return const KomandoAgente(
          tipo: TipoComandoAgente.desconocido,
          ejecutado: false,
          descripcion: 'Comando desconocido',
        );
    }
  }

  String? _resolverPadre(
    Map<String, dynamic> mapa,
    Map<String, String> referencias,
  ) {
    final padre = mapa['padreId'] as String?;
    if (padre == null || padre == 'null') return null;
    if (padre.startsWith('@')) return referencias[padre.substring(1)];
    return padre;
  }

  Future<KomandoAgente> _ejecutarCrearNota(
    Map<String, dynamic> mapa,
    Map<String, String> referencias,
  ) async {
    final padreId = _resolverPadre(mapa, referencias);
    final titulo = (mapa['titulo'] as String?)?.trim() ?? 'Nueva nota';
    final contenido = _contenidoNota(mapa);
    final protegida = mapa['protegida'] as bool? ?? false;

    await _repositorio.crearNota(
      padreId,
      titulo,
      contenido: contenido,
      protegida: protegida,
    );

    return KomandoAgente(
      tipo: TipoComandoAgente.crearNota,
      ejecutado: true,
      descripcion: 'Nota "$titulo" creada',
    );
  }

  Future<KomandoAgente> _ejecutarCrearCarpeta(
    Map<String, dynamic> mapa,
    Map<String, String> referencias,
  ) async {
    final padreId = _resolverPadre(mapa, referencias);
    final nombre = (mapa['nombre'] as String?)?.trim() ?? 'Nueva carpeta';

    final carpeta = await _repositorio.crearCarpeta(padreId, nombre);
    final referencia = (mapa['referencia'] as String?)?.trim();
    if (referencia != null && referencia.isNotEmpty) {
      referencias[referencia] = carpeta.id;
    }

    return KomandoAgente(
      tipo: TipoComandoAgente.crearCarpeta,
      ejecutado: true,
      descripcion: 'Carpeta "$nombre" creada',
    );
  }

  Future<KomandoAgente> _ejecutarModificarNota(
    Map<String, dynamic> mapa,
  ) async {
    final id = mapa['id'] as String?;
    if (id == null || id.isEmpty) {
      throw ArgumentError('El campo "id" es requerido para modificar_nota.');
    }
    final contenido = _contenidoNota(mapa);

    // Verificar que la nota existe antes de modificar
    final nota = await _repositorio.obtener(id);
    if (nota == null || nota.tipo != TipoElementoDrive.nota) {
      throw StateError('No existe una nota con id "$id".');
    }

    await _repositorio.actualizarNota(id, contenido);

    return KomandoAgente(
      tipo: TipoComandoAgente.modificarNota,
      ejecutado: true,
      descripcion: 'Nota "${nota.nombre}" modificada',
    );
  }

  String _contenidoNota(Map<String, dynamic> mapa) {
    final delta = mapa['contenidoDelta'];
    if (delta is List) return jsonEncode(delta);
    final contenido = mapa['contenido'];
    if (contenido is String) return contenido;
    if (contenido is List || contenido is Map) return jsonEncode(contenido);
    return '';
  }

  // ─── Helpers privados ──────────────────────────────────────────────────

  void _agregarError(String mensaje) {
    historial.add(
      MensajeChat.texto(
        rol: RolMensaje.asistente,
        texto: mensaje,
        hora: DateTime.now(),
        esError: true,
      ),
    );
  }

  void limpiarHistorial() {
    historial.clear();
    notifyListeners();
  }
}

/// Contexto de Drive para la IA: texto descriptivo + imágenes extraídas.
class ContextoDrive {
  final String texto;
  final List<ParteMensaje> imagenes;

  const ContextoDrive({required this.texto, required this.imagenes});
}

class ChatGuardado {
  final String id;
  final String titulo;
  final DateTime actualizado;
  final List<MensajeChat> mensajes;

  const ChatGuardado({
    required this.id,
    required this.titulo,
    required this.actualizado,
    required this.mensajes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'actualizado': actualizado.toIso8601String(),
    'mensajes': mensajes.map((mensaje) => mensaje.aJson()).toList(),
  };

  factory ChatGuardado.fromJson(Map<String, dynamic> json) => ChatGuardado(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    actualizado: DateTime.parse(json['actualizado'] as String),
    mensajes: (json['mensajes'] as List<dynamic>)
        .map(
          (mensaje) =>
              MensajeChat.desdeJson(Map<String, dynamic>.from(mensaje as Map)),
        )
        .toList(),
  );
}
