import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_dialog.dart';
import 'datos/drive_repositorio.dart';
import 'documentos/visor_documento_screen.dart';
import 'modelos/drive_elemento.dart';
import 'notas/nota_editor_screen.dart';
import 'widgets/dialogo_importar_json.dart';
import 'codigo/codigo_editor_screen.dart';

/// Contenido de la pestaña Drive. No usa Scaffold porque Home ya dibuja el
/// fondo, el encabezado y la barra inferior flotante.
class DriveScreen extends StatefulWidget {
  const DriveScreen({
    super.key,
    this.repositorio,
    this.carpetaInicialId,
    this.rutaInicial,
  });

  final DriveRepositorio? repositorio;
  final String? carpetaInicialId;
  final List<DriveElemento>? rutaInicial;

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  late final DriveRepositorio _repositorio;
  String? _carpetaActualId;
  List<DriveElemento> _ruta = [];
  late Future<List<DriveElemento>> _elementos;
  bool _importando = false;

  @override
  void initState() {
    super.initState();
    _repositorio = widget.repositorio ?? DriveRepositorio();
    _carpetaActualId = widget.carpetaInicialId;
    _ruta = widget.rutaInicial ?? [];
    _recargar();
  }

  void _recargar() {
    _elementos = _repositorio.listar(_carpetaActualId);
  }

  Future<void> _actualizar() async {
    setState(_recargar);
    await _elementos;
  }

  Future<void> _entrarEn(DriveElemento carpeta) async {
    HapticFeedback.selectionClick();
    final ruta = await _repositorio.rutaDe(carpeta.id);
    if (!mounted) return;
    setState(() {
      _carpetaActualId = carpeta.id;
      _ruta = ruta;
      _recargar();
    });
  }

  Future<void> _irARuta(int indice) async {
    HapticFeedback.selectionClick();
    if (indice < 0) {
      setState(() {
        _carpetaActualId = null;
        _ruta = [];
        _recargar();
      });
      return;
    }
    final carpeta = _ruta[indice];
    setState(() {
      _carpetaActualId = carpeta.id;
      _ruta = _ruta.take(indice + 1).toList();
      _recargar();
    });
  }

  Future<void> _crearCarpeta() async {
    HapticFeedback.selectionClick();
    final nombre = await _pedirNombre(
      titulo: 'Nueva carpeta',
      etiqueta: 'Nombre de la carpeta',
      accion: 'Crear',
    );
    if (nombre == null || !mounted) {
      return;
    }
    try {
      await _repositorio.crearCarpeta(_carpetaActualId, nombre);
      if (!mounted) return;
      await _actualizar();
    } on ArgumentError catch (error) {
      if (mounted) {
        _mostrarError(error.message?.toString() ?? 'Nombre inválido.');
      }
    }
  }

  Future<void> _crearNota() async {
    HapticFeedback.selectionClick();
    final nombre = await _pedirNombre(
      titulo: 'Nueva nota',
      etiqueta: 'Título de la nota',
      accion: 'Crear',
    );
    if (nombre == null || !mounted) {
      return;
    }
    try {
      final nota = await _repositorio.crearNota(_carpetaActualId, nombre);
      if (!mounted) return;
      await _abrirNota(nota);
    } on ArgumentError catch (error) {
      if (mounted) {
        _mostrarError(error.message?.toString() ?? 'Nombre inválido.');
      }
    } catch (e) {
      if (mounted) _mostrarError('No se pudo crear la nota.');
    }
  }

  /// Abre el selector de archivos del sistema y copia el documento al Drive.
  Future<void> _importarDocumento() async {
    HapticFeedback.selectionClick();
    if (_importando) return;
    setState(() => _importando = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
        ],
      );
      final archivo = result == null || result.files.isEmpty
          ? null
          : result.files.first;
      if (archivo == null || !mounted) return;

      final ruta = archivo.path;
      if (ruta == null) {
        _mostrarError('No se pudo obtener la ruta del archivo.');
        return;
      }

      await _repositorio.importarDocumento(_carpetaActualId, File(ruta));
      if (!mounted) return;
      await _actualizar();
    } on ArgumentError catch (e) {
      if (mounted) _mostrarError(e.message?.toString() ?? 'Archivo inválido.');
    } catch (e) {
      if (mounted) _mostrarError('No se pudo importar el archivo.');
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  Future<void> _importarCursoJson() async {
    HapticFeedback.selectionClick();
    final jsonObject = await mostrarGlassDialog<Object>(
      context: context,
      child: const DialogoImportarJson(),
    );
    if (jsonObject == null || !mounted) return;

    if (_importando) return;
    setState(() => _importando = true);

    try {
      await _repositorio.importarArbol(_carpetaActualId, jsonObject);
      if (!mounted) return;
      await _actualizar();
      if (!mounted) return;
      _mostrarError('Curso importado correctamente.');
    } on FormatoCursoInvalido catch (e) {
      if (mounted) _mostrarError(e.mensaje);
    } on FormatException catch (_) {
      if (mounted) _mostrarError('Formato de curso inválido.');
    } catch (e) {
      if (mounted) _mostrarError('Error al importar curso.');
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  Future<void> _mostrarAccionesCrear() async {
    if (_carpetaActualId == null) {
      await _crearCarpeta();
      return;
    }
    HapticFeedback.selectionClick();
    final accion = await showModalBottomSheet<_AccionCrear>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HojaAgregar(),
    );
    if (!mounted || accion == null) return;
    switch (accion) {
      case _AccionCrear.carpeta:
        await _crearCarpeta();
      case _AccionCrear.nota:
        await _crearNota();
      case _AccionCrear.codigo:
        await _crearCodigo();
      case _AccionCrear.documento:
        await _importarDocumento();
      case _AccionCrear.curso:
        await _importarCursoJson();
    }
  }

  Future<void> _abrirElemento(DriveElemento elemento) async {
    switch (elemento.tipo) {
      case TipoElementoDrive.carpeta:
        await _entrarEn(elemento);
      case TipoElementoDrive.nota:
        await _abrirNota(elemento);
      case TipoElementoDrive.codigo:
        await _abrirCodigo(elemento);
      case TipoElementoDrive.documento:
        await _abrirDocumento(elemento);
    }
  }

  Future<void> _abrirCodigo(DriveElemento codigo) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) =>
            CodigoEditorScreen(codigo: codigo, repositorio: _repositorio),
        transitionsBuilder: (_, animacion, _, child) =>
            FadeTransition(opacity: animacion, child: child),
      ),
    );
    if (mounted) await _actualizar();
  }

  Future<void> _crearCodigo() async {
    final nombre = await _pedirNombre(
      titulo: 'Nuevo código',
      etiqueta: 'Nombre del archivo',
      accion: 'Crear',
    );
    if (nombre == null || !mounted) return;

    try {
      final codigo = await _repositorio.crearCodigo(
        padreId: _carpetaActualId,
        nombre: nombre,
      );
      if (!mounted) return;
      await _actualizar();
      await _abrirCodigo(codigo);
    } on ArgumentError catch (e) {
      if (mounted) _mostrarError(e.message?.toString() ?? 'Nombre inválido.');
    } catch (e) {
      if (mounted) _mostrarError('No se pudo crear el archivo.');
    }
  }

  Future<void> _abrirNota(DriveElemento nota) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) =>
            NotaEditorScreen(nota: nota, repositorio: _repositorio),
        transitionsBuilder: (_, animacion, _, child) =>
            FadeTransition(opacity: animacion, child: child),
      ),
    );
    if (mounted) await _actualizar();
  }

  Future<void> _abrirDocumento(DriveElemento documento) async {
    final rutaRelativa = documento.rutaRelativa;
    if (rutaRelativa == null) {
      _mostrarError('Este documento no tiene archivo asociado.');
      return;
    }
    try {
      final archivo = await _repositorio.archivoDeDocumento(rutaRelativa);
      if (!await archivo.exists()) {
        if (mounted) {
          _mostrarError(
            'El archivo ya no existe en el almacenamiento privado.',
          );
        }
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, _, _) =>
              VisorDocumentoScreen(elemento: documento, archivo: archivo),
          transitionsBuilder: (_, animacion, _, child) =>
              FadeTransition(opacity: animacion, child: child),
        ),
      );
    } catch (e) {
      if (mounted) _mostrarError('No se pudo abrir el documento.');
    }
  }

  Future<void> _renombrar(DriveElemento elemento) async {
    HapticFeedback.selectionClick();
    final nombre = await _pedirNombre(
      titulo: 'Renombrar',
      etiqueta: 'Nombre',
      accion: 'Guardar',
      valorInicial: elemento.nombre,
    );
    if (nombre == null || !mounted) {
      return;
    }
    try {
      await _repositorio.renombrar(elemento.id, nombre);
      if (!mounted) return;
      await _actualizar();
    } on ArgumentError catch (error) {
      if (mounted) {
        _mostrarError(error.message?.toString() ?? 'Nombre inválido.');
      }
    } catch (e) {
      if (mounted) _mostrarError('No se pudo renombrar.');
    }
  }

  Future<void> _eliminar(DriveElemento elemento) async {
    HapticFeedback.selectionClick();
    final confirmar = await mostrarGlassDialog<bool>(
      context: context,
      child: _ConfirmarEliminar(elemento: elemento),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _repositorio.eliminar(elemento.id);
    } catch (e) {
      if (mounted) _mostrarError('No se pudo eliminar el elemento.');
      return;
    }
    if (!mounted) return;
    await _actualizar();
  }

  Future<void> _alternarFavorito(DriveElemento elemento) async {
    await _repositorio.alternarFavorito(elemento);
    if (mounted) await _actualizar();
  }

  Future<void> _alternarPrioridad(DriveElemento elemento) async {
    await _repositorio.alternarPrioridad(elemento);
    if (mounted) await _actualizar();
  }

  Future<String?> _pedirNombre({
    required String titulo,
    required String etiqueta,
    required String accion,
    String? valorInicial,
  }) async {
    final resultado = await mostrarGlassDialog<String>(
      context: context,
      child: _DialogoNombre(
        titulo: titulo,
        etiqueta: etiqueta,
        accion: accion,
        valorInicial: valorInicial,
      ),
    );
    return resultado;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriveElemento>>(
      future: _elementos,
      builder: (context, estado) {
        if (estado.hasError) {
          return _EstadoDrive(
            icono: Icons.error_outline,
            titulo: 'No se pudo cargar el contenido',
            subtitulo: 'Toca para intentarlo otra vez.',
            onTap: _actualizar,
          );
        }
        if (!estado.hasData) {
          return const Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        }
        return Stack(
          children: [
            _lista(estado.data!),
            if (_importando)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _lista(List<DriveElemento> elementos) {
    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _actualizar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        itemCount: elementos.isEmpty ? 3 : elementos.length + 2,
        itemBuilder: (context, indice) {
          if (indice == 0) return _encabezado();
          if (indice == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _botonAgregar(),
            );
          }
          if (elementos.isEmpty) {
            return _EstadoDrive(
              icono: Icons.folder_open_outlined,
              titulo: 'Esta carpeta está vacía',
              subtitulo: _carpetaActualId == null
                  ? 'Crea una carpeta para organizar tu mundo.'
                  : 'Agrega una carpeta, una nota o un documento.',
              onTap: _mostrarAccionesCrear,
            );
          }
          final elemento = elementos[indice - 2];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ElementoDrive(
              elemento: elemento,
              onAbrir: () => _abrirElemento(elemento),
              onRenombrar: () => _renombrar(elemento),
              onEliminar: () => _eliminar(elemento),
              onAlternarFavorito: () => _alternarFavorito(elemento),
              onAlternarPrioridad: () => _alternarPrioridad(elemento),
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DRIVE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MigaRuta(nombre: 'Drive', onTap: () => _irARuta(-1)),
                for (var i = 0; i < _ruta.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                  _MigaRuta(
                    nombre: _ruta[i].nombre,
                    activa: i == _ruta.length - 1,
                    onTap: () => _irARuta(i),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonAgregar() {
    final enRaiz = _carpetaActualId == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _mostrarAccionesCrear,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                enRaiz ? Icons.create_new_folder_outlined : Icons.add,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                enRaiz ? 'Nueva carpeta' : 'Agregar',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MigaRuta extends StatelessWidget {
  const _MigaRuta({
    required this.nombre,
    required this.onTap,
    this.activa = false,
  });

  final String nombre;
  final VoidCallback onTap;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        nombre,
        style: TextStyle(
          color: Colors.white.withValues(alpha: activa ? 0.95 : 0.65),
          fontSize: 16,
          fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _ElementoDrive extends StatelessWidget {
  const _ElementoDrive({
    required this.elemento,
    required this.onAbrir,
    required this.onRenombrar,
    required this.onEliminar,
    required this.onAlternarFavorito,
    required this.onAlternarPrioridad,
  });

  final DriveElemento elemento;
  final VoidCallback onAbrir;
  final VoidCallback onRenombrar;
  final VoidCallback onEliminar;
  final VoidCallback onAlternarFavorito;
  final VoidCallback onAlternarPrioridad;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAbrir,
        borderRadius: BorderRadius.circular(24),
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(switch (elemento.tipo) {
                  TipoElementoDrive.carpeta => Icons.folder_outlined,
                  TipoElementoDrive.nota => Icons.note_alt_outlined,
                  TipoElementoDrive.documento => _iconoPorMime(elemento.mime),
                  TipoElementoDrive.codigo => Icons.code,
                }, color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elemento.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (elemento.tipo != TipoElementoDrive.carpeta) ...[
                      const SizedBox(height: 2),
                      Text(
                        _subtitulo(elemento),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (elemento.prioridad > 0)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, color: Colors.white70, size: 16),
                ),
              if (elemento.favorita)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.amberAccent,
                    size: 18,
                  ),
                ),
              PopupMenuButton<_AccionElemento>(
                icon: Icon(
                  Icons.more_horiz,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
                color: const Color(0xFF282B34),
                onSelected: (accion) {
                  HapticFeedback.selectionClick();
                  switch (accion) {
                    case _AccionElemento.renombrar:
                      onRenombrar();
                    case _AccionElemento.eliminar:
                      onEliminar();
                    case _AccionElemento.favorito:
                      onAlternarFavorito();
                    case _AccionElemento.prioridad:
                      onAlternarPrioridad();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _AccionElemento.prioridad,
                    child: Text(
                      elemento.prioridad > 0
                          ? 'Quitar prioridad'
                          : 'Fijar al principio',
                    ),
                  ),
                  PopupMenuItem(
                    value: _AccionElemento.favorito,
                    child: Text(
                      elemento.favorita
                          ? 'Quitar de favoritos'
                          : 'Fijar en favoritos',
                    ),
                  ),
                  PopupMenuItem(
                    value: _AccionElemento.renombrar,
                    child: Text('Renombrar'),
                  ),
                  PopupMenuItem(
                    value: _AccionElemento.eliminar,
                    child: Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitulo(DriveElemento e) {
    if (e.tipo == TipoElementoDrive.nota) return 'Nota';
    final tamano = e.tamano;
    if (tamano == null) return 'Documento';
    if (tamano < 1024) return 'Documento · $tamano B';
    if (tamano < 1024 * 1024) {
      return 'Documento · ${(tamano / 1024).toStringAsFixed(1)} KB';
    }
    return 'Documento · ${(tamano / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static IconData _iconoPorMime(String? mime) {
    if (mime == null) return Icons.description_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.contains('msword') || mime.contains('wordprocessingml')) {
      return Icons.article_outlined;
    }
    if (mime.contains('ms-excel') || mime.contains('spreadsheetml')) {
      return Icons.table_chart_outlined;
    }
    if (mime.contains('ms-powerpoint') || mime.contains('presentationml')) {
      return Icons.slideshow_outlined;
    }
    return Icons.description_outlined;
  }
}

enum _AccionElemento { favorito, prioridad, renombrar, eliminar }

enum _AccionCrear { carpeta, nota, codigo, documento, curso }

class _HojaAgregar extends StatelessWidget {
  const _HojaAgregar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F28),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            _OpcionAgregar(
              icono: Icons.create_new_folder_outlined,
              titulo: 'Nueva carpeta',
              onTap: () => Navigator.of(context).pop(_AccionCrear.carpeta),
            ),
            _OpcionAgregar(
              icono: Icons.note_add_outlined,
              titulo: 'Nueva nota',
              onTap: () => Navigator.of(context).pop(_AccionCrear.nota),
            ),
            _OpcionAgregar(
              icono: Icons.code,
              titulo: 'Nuevo fragmento de código',
              onTap: () => Navigator.of(context).pop(_AccionCrear.codigo),
            ),
            _OpcionAgregar(
              icono: Icons.upload_file_outlined,
              titulo: 'Subir documento',
              subtitulo: 'PDF, imagen, Word, Excel, PowerPoint',
              onTap: () => Navigator.of(context).pop(_AccionCrear.documento),
            ),
            _OpcionAgregar(
              icono: Icons.data_object,
              titulo: 'Importar curso JSON',
              subtitulo: 'Carga una estructura completa',
              onTap: () => Navigator.of(context).pop(_AccionCrear.curso),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionAgregar extends StatelessWidget {
  const _OpcionAgregar({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.subtitulo,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activa = onTap != null;
    return ListTile(
      enabled: activa,
      onTap: onTap,
      leading: Icon(
        icono,
        color: Colors.white.withValues(alpha: activa ? 0.88 : 0.32),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          color: Colors.white.withValues(alpha: activa ? 0.95 : 0.42),
        ),
      ),
      subtitle: subtitulo == null
          ? null
          : Text(
              subtitulo!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
            ),
    );
  }
}

class _EstadoDrive extends StatelessWidget {
  const _EstadoDrive({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 38, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(height: 14),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre({
    required this.titulo,
    required this.etiqueta,
    required this.accion,
    this.valorInicial,
  });

  final String titulo;
  final String etiqueta;
  final String accion;
  final String? valorInicial;

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final TextEditingController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.valorInicial);
  }

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
          Text(
            widget.titulo,
            style: const TextStyle(
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
              labelText: widget.etiqueta,
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
                child: Text(widget.accion),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmarEliminar extends StatelessWidget {
  const _ConfirmarEliminar({required this.elemento});

  final DriveElemento elemento;

  @override
  Widget build(BuildContext context) {
    final esCarpeta = elemento.tipo == TipoElementoDrive.carpeta;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            esCarpeta ? '¿Eliminar carpeta?' : '¿Eliminar elemento?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            esCarpeta
                ? '"${elemento.nombre}" y todo su contenido se borrarán definitivamente.'
                : '"${elemento.nombre}" se borrará definitivamente.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.75),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
