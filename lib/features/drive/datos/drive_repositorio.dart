import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../modelos/drive_elemento.dart';
import 'drive_base_datos.dart';

/// Error entendible para el JSON de cursos. La pantalla podrá mostrar su texto
/// directamente sin dejar registros creados a medias.
class FormatoCursoInvalido implements Exception {
  final String mensaje;

  const FormatoCursoInvalido(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Contrato de datos del Drive. Las pantallas y la futura IA hablan con esta
/// clase, nunca con SQLite ni con archivos directamente.
class DriveRepositorio {
  DriveRepositorio({DriveBaseDatos? baseDatos})
    : _baseDatos = baseDatos ?? DriveBaseDatos.instancia;

  final DriveBaseDatos _baseDatos;
  final Uuid _uuid = const Uuid();

  Future<List<DriveElemento>> listar(String? padreId) async {
    final db = await _baseDatos.baseDatos;
    final filas = await db.query(
      'elementos_drive',
      where: padreId == null ? 'padre_id IS NULL' : 'padre_id = ?',
      whereArgs: padreId == null ? null : [padreId],
      orderBy: '''
        prioridad DESC,
        orden ASC,
        CASE tipo
          WHEN 'carpeta' THEN 0
          WHEN 'nota' THEN 1
          WHEN 'documento' THEN 2
          ELSE 3
        END,
        favorita DESC,
        nombre COLLATE NOCASE ASC
      ''',
    );
    return filas.map(DriveElemento.desdeMapa).toList();
  }

  Future<DriveElemento?> obtener(String id) async {
    final db = await _baseDatos.baseDatos;
    final filas = await db.query(
      'elementos_drive',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return DriveElemento.desdeMapa(filas.first);
  }

  /// Devuelve los ancestros en orden desde la carpeta raíz hasta [id].
  Future<List<DriveElemento>> rutaDe(String id) async {
    final rutaInversa = <DriveElemento>[];
    var actualId = id;
    while (true) {
      final actual = await obtener(actualId);
      if (actual == null) {
        throw StateError('No existe el elemento de Drive solicitado.');
      }
      rutaInversa.add(actual);
      final padreId = actual.padreId;
      if (padreId == null) break;
      actualId = padreId;
    }
    return rutaInversa.reversed.toList();
  }

  Future<DriveElemento> crearCarpeta(String? padreId, String nombre) {
    return _crearElemento(
      padreId: padreId,
      tipo: TipoElementoDrive.carpeta,
      nombre: nombre,
    );
  }

  Future<DriveElemento> crearNota(
    String? padreId,
    String nombre, {
    String contenido = '',
    bool protegida = false,
  }) {
    return _crearElemento(
      padreId: padreId,
      tipo: TipoElementoDrive.nota,
      nombre: nombre,
      contenido: contenido,
      protegida: protegida,
    );
  }

  Future<DriveElemento> _crearElemento({
    required String? padreId,
    required TipoElementoDrive tipo,
    required String nombre,
    String? contenido,
    String? rutaRelativa,
    String? mime,
    int? tamano,
    bool protegida = false,
  }) async {
    final nombreLimpio = _nombreValido(nombre);
    await _validarPadre(padreId);

    final ahora = DateTime.now();
    final elemento = DriveElemento(
      id: _uuid.v4(),
      padreId: padreId,
      tipo: tipo,
      nombre: nombreLimpio,
      contenido: contenido,
      rutaRelativa: rutaRelativa,
      mime: mime,
      tamano: tamano,
      creado: ahora,
      modificado: ahora,
      protegida: protegida,
    );
    final db = await _baseDatos.baseDatos;
    await db.insert('elementos_drive', elemento.aMapa());
    return elemento;
  }

  Future<DriveElemento> crearCodigo({
    String? padreId,
    required String nombre,
  }) async {
    return _crearElemento(
      padreId: padreId,
      tipo: TipoElementoDrive.codigo,
      nombre: nombre,
    );
  }

  Future<void> guardar(DriveElemento elemento) async {
    final db = await _baseDatos.baseDatos;
    await db.update(
      'elementos_drive',
      elemento.aMapa(),
      where: 'id = ?',
      whereArgs: [elemento.id],
    );
  }

  Future<void> actualizarNota(String id, String contenido) async {
    final db = await _baseDatos.baseDatos;
    final actualizados = await db.update(
      'elementos_drive',
      {
        'contenido': contenido,
        'modificado': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND tipo = ?',
      whereArgs: [id, TipoElementoDrive.nota.valor],
    );
    if (actualizados == 0) {
      throw StateError('No existe la nota que intentas guardar.');
    }
  }

  Future<void> renombrar(String id, String nombre) async {
    final db = await _baseDatos.baseDatos;
    final actualizados = await db.update(
      'elementos_drive',
      {
        'nombre': _nombreValido(nombre),
        'modificado': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (actualizados == 0) {
      throw StateError('No existe el elemento que intentas renombrar.');
    }
  }

  Future<void> alternarFavorito(DriveElemento elemento) async {
    final db = await _baseDatos.baseDatos;
    await db.update(
      'elementos_drive',
      {'favorita': elemento.favorita ? 0 : 1},
      where: 'id = ?',
      whereArgs: [elemento.id],
    );
  }

  Future<void> alternarPrioridad(DriveElemento elemento) async {
    final db = await _baseDatos.baseDatos;
    await db.update(
      'elementos_drive',
      {'prioridad': elemento.prioridad > 0 ? 0 : 1},
      where: 'id = ?',
      whereArgs: [elemento.id],
    );
  }

  /// Devuelve todos los elementos marcados como favoritos, sin importar carpeta.
  Future<List<DriveElemento>> listarFavoritos() async {
    final db = await _baseDatos.baseDatos;
    final filas = await db.query(
      'elementos_drive',
      where: 'favorita = 1',
      orderBy: "CASE tipo WHEN 'carpeta' THEN 0 WHEN 'nota' THEN 1 ELSE 2 END, nombre COLLATE NOCASE ASC",
    );
    return filas.map(DriveElemento.desdeMapa).toList();
  }

  /// Elimina en cascada los registros hijos y sus archivos privados.
  Future<void> eliminar(String id) async {
    final raiz = await obtener(id);
    if (raiz == null) {
      throw StateError('No existe el elemento que intentas eliminar.');
    }

    final descendientes = await _descendientesDe(id);
    final documentos = [
      raiz,
      ...descendientes,
    ].where((elemento) => elemento.tipo == TipoElementoDrive.documento);

    for (final documento in documentos) {
      final rutaRelativa = documento.rutaRelativa;
      if (rutaRelativa == null) continue;
      final archivo = await _archivoPrivado(rutaRelativa);
      if (await archivo.exists()) {
        await archivo.delete();
      }
    }

    final db = await _baseDatos.baseDatos;
    await db.delete('elementos_drive', where: 'id = ?', whereArgs: [id]);
  }

  /// Devuelve el [File] del documento en el almacenamiento privado de la app.
  /// La pantalla de visor llama esto; nunca guarda la ruta absoluta.
  Future<File> archivoDeDocumento(String rutaRelativa) =>
      _archivoPrivado(rutaRelativa);

  /// Copia [archivo] antes de guardar el registro, así el Drive no depende de
  /// que el usuario conserve el archivo original en su teléfono.
  Future<DriveElemento> importarDocumento(String? padreId, File archivo) async {
    if (!await archivo.exists()) {
      throw ArgumentError.value(
        archivo.path,
        'archivo',
        'El archivo no existe.',
      );
    }
    await _validarPadre(padreId);

    final nombre = _nombreValido(_nombreDeRuta(archivo.path));
    final extension = _extensionDeNombre(nombre);
    final id = _uuid.v4();
    final rutaRelativa = extension.isEmpty ? id : '$id.$extension';
    final destino = await _archivoPrivado(rutaRelativa);
    await destino.parent.create(recursive: true);
    await archivo.copy(destino.path);

    try {
      final ahora = DateTime.now();
      final elemento = DriveElemento(
        id: id,
        padreId: padreId,
        tipo: TipoElementoDrive.documento,
        nombre: nombre,
        contenido: null,
        rutaRelativa: rutaRelativa,
        mime: _mimeDesdeExtension(extension),
        tamano: await destino.length(),
        creado: ahora,
        modificado: ahora,
      );
      final db = await _baseDatos.baseDatos;
      await db.insert('elementos_drive', elemento.aMapa());
      return elemento;
    } catch (_) {
      if (await destino.exists()) await destino.delete();
      rethrow;
    }
  }

  /// Importa el contrato de curso de la IA de manera atómica. Primero valida
  /// todo el JSON y después usa una sola transacción de SQLite.
  Future<void> importarArbol(String? padreId, Object json) async {
    await _validarPadre(padreId);
    final raiz = _validarNodo(json, ruta: 'raíz');
    final db = await _baseDatos.baseDatos;
    await db.transaction((txn) async {
      await _insertarNodo(txn, padreId, raiz);
    });
  }

  Future<void> _insertarNodo(
    Transaction txn,
    String? padreId,
    _NodoCurso nodo,
  ) async {
    final ahora = DateTime.now();
    final id = _uuid.v4();
    await txn.insert('elementos_drive', {
      'id': id,
      'padre_id': padreId,
      'tipo': nodo.tipo.valor,
      'nombre': nodo.nombre,
      'contenido': nodo.contenido,
      'ruta_relativa': null,
      'mime': null,
      'tamano': null,
      'creado': ahora.millisecondsSinceEpoch,
      'modificado': ahora.millisecondsSinceEpoch,
    });
    for (final hijo in nodo.hijos) {
      await _insertarNodo(txn, id, hijo);
    }
  }

  _NodoCurso _validarNodo(Object json, {required String ruta}) {
    if (json is! Map) {
      throw FormatoCursoInvalido(
        'El elemento en $ruta debe ser un objeto JSON.',
      );
    }
    final tipoTexto = json['tipo'];
    if (tipoTexto is! String ||
        (tipoTexto != TipoElementoDrive.carpeta.valor &&
            tipoTexto != TipoElementoDrive.nota.valor)) {
      throw FormatoCursoInvalido(
        'El elemento en $ruta debe tener tipo "carpeta" o "nota".',
      );
    }
    final nombre = json['nombre'];
    if (nombre is! String || nombre.trim().isEmpty) {
      throw FormatoCursoInvalido('El elemento en $ruta necesita un nombre.');
    }
    if (nombre.trim().length > 140) {
      throw FormatoCursoInvalido('El nombre en $ruta es demasiado largo.');
    }

    final tipo = TipoElementoDrive.desdeValor(tipoTexto);
    final contenido = json['contenido'];
    if (contenido != null && contenido is! String) {
      throw FormatoCursoInvalido('El contenido de $ruta debe ser texto.');
    }

    final hijosJson = json['hijos'];
    if (tipo == TipoElementoDrive.nota && hijosJson != null) {
      throw FormatoCursoInvalido('Una nota no puede tener hijos ($ruta).');
    }
    if (hijosJson != null && hijosJson is! List) {
      throw FormatoCursoInvalido('Los hijos de $ruta deben ser una lista.');
    }

    final hijos = <_NodoCurso>[];
    final listaHijos = hijosJson as List?;
    for (final hijo in listaHijos ?? const []) {
      hijos.add(_validarNodo(hijo, ruta: '$ruta › ${nombre.trim()}'));
    }
    return _NodoCurso(
      tipo: tipo,
      nombre: nombre.trim(),
      contenido: contenido as String? ?? '',
      hijos: hijos,
    );
  }

  Future<void> _validarPadre(String? padreId) async {
    if (padreId == null) return;
    final padre = await obtener(padreId);
    if (padre == null || padre.tipo != TipoElementoDrive.carpeta) {
      throw StateError('La carpeta destino ya no existe.');
    }
  }

  Future<List<DriveElemento>> _descendientesDe(String padreId) async {
    final resultado = <DriveElemento>[];
    final pendientes = <String>[padreId];
    final db = await _baseDatos.baseDatos;
    while (pendientes.isNotEmpty) {
      final actual = pendientes.removeLast();
      final filas = await db.query(
        'elementos_drive',
        where: 'padre_id = ?',
        whereArgs: [actual],
      );
      final hijos = filas.map(DriveElemento.desdeMapa).toList();
      resultado.addAll(hijos);
      pendientes.addAll(hijos.map((hijo) => hijo.id));
    }
    return resultado;
  }

  Future<File> _archivoPrivado(String rutaRelativa) async {
    if (rutaRelativa.contains('/') || rutaRelativa.contains('\\')) {
      throw StateError('La ruta relativa del documento no es válida.');
    }
    final carpeta = await _baseDatos.carpetaDocumentos;
    return File('${carpeta.path}${Platform.pathSeparator}$rutaRelativa');
  }

  String _nombreValido(String nombre) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw ArgumentError.value(nombre, 'nombre', 'Escribe un nombre.');
    }
    if (limpio.length > 140) {
      throw ArgumentError.value(
        nombre,
        'nombre',
        'El nombre es demasiado largo.',
      );
    }
    if (limpio.contains('/') || limpio.contains('\\')) {
      throw ArgumentError.value(
        nombre,
        'nombre',
        'El nombre no puede tener / ni \\.',
      );
    }
    return limpio;
  }

  String _nombreDeRuta(String ruta) {
    final partes = ruta.split(RegExp(r'[\\/]'));
    return partes.last;
  }

  String _extensionDeNombre(String nombre) {
    final punto = nombre.lastIndexOf('.');
    if (punto <= 0 || punto == nombre.length - 1) return '';
    return nombre.substring(punto + 1).toLowerCase();
  }

  String? _mimeDesdeExtension(String extension) {
    return switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => null,
    };
  }
}

class _NodoCurso {
  const _NodoCurso({
    required this.tipo,
    required this.nombre,
    required this.contenido,
    required this.hijos,
  });

  final TipoElementoDrive tipo;
  final String nombre;
  final String contenido;
  final List<_NodoCurso> hijos;
}
