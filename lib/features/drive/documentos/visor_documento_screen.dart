import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/widgets/herramienta_scaffold.dart';
import '../modelos/drive_elemento.dart';

/// Pantalla que muestra un documento importado en el Drive.
///
/// - PDF: previsualización con zoom (pdfx).
/// - Imágenes: previsualización con zoom (InteractiveViewer).
/// - Word, Excel, PowerPoint y formatos desconocidos: tarjeta con nombre/tamaño
///   y botón para abrir con una app externa.
class VisorDocumentoScreen extends StatefulWidget {
  const VisorDocumentoScreen({
    super.key,
    required this.elemento,
    required this.archivo,
  });

  final DriveElemento elemento;
  final File archivo;

  @override
  State<VisorDocumentoScreen> createState() => _VisorDocumentoScreenState();
}

class _VisorDocumentoScreenState extends State<VisorDocumentoScreen> {
  PdfControllerPinch? _controladorPdfContinuo;
  PdfController? _controladorPdfPagina;
  late final Future<PdfDocument> _documentoPdf;
  bool _cargandoPdf = true;
  bool _modoPagina = false;
  int _paginaActual = 1;
  int _totalPaginas = 0;
  String? _errorPdf;

  bool get _esPdf => widget.elemento.mime == 'application/pdf';
  bool get _esImagen => widget.elemento.mime?.startsWith('image/') ?? false;

  @override
  void initState() {
    super.initState();
    if (_esPdf) {
      _documentoPdf = PdfDocument.openFile(widget.archivo.path);
      _abrirPdf();
    }
  }

  @override
  void dispose() {
    _controladorPdfContinuo?.dispose();
    _controladorPdfPagina?.dispose();
    super.dispose();
  }

  Future<void> _abrirPdf() async {
    try {
      final controlador = PdfControllerPinch(
        document: _documentoPdf,
        initialPage: _paginaActual,
      );
      if (!mounted) return;
      setState(() {
        _controladorPdfContinuo = controlador;
        _cargandoPdf = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPdf = 'No se pudo abrir el PDF.';
        _cargandoPdf = false;
      });
    }
  }

  void _cambiarModo(bool modoPagina) {
    if (_modoPagina == modoPagina || !mounted) return;
    final pagina = _paginaActual;
    setState(() {
      _modoPagina = modoPagina;
      _cargandoPdf = true;
      if (modoPagina) {
        _controladorPdfContinuo?.dispose();
        _controladorPdfContinuo = null;
        _controladorPdfPagina = PdfController(
          document: _documentoPdf,
          initialPage: pagina,
        );
      } else {
        _controladorPdfPagina?.dispose();
        _controladorPdfPagina = null;
        _controladorPdfContinuo = PdfControllerPinch(
          document: _documentoPdf,
          initialPage: pagina,
        );
      }
      _cargandoPdf = false;
    });
  }

  void _actualizarPagina(int pagina) {
    if (!mounted) return;
    setState(() => _paginaActual = pagina);
  }

  Future<void> _paginaAnterior() async {
    if (!_modoPagina || _controladorPdfPagina == null || _paginaActual <= 1) {
      return;
    }
    await _controladorPdfPagina!.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _paginaSiguiente() async {
    if (!_modoPagina ||
        _controladorPdfPagina == null ||
        _paginaActual >= _totalPaginas) {
      return;
    }
    await _controladorPdfPagina!.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _abrirConAppExterna() async {
    HapticFeedback.selectionClick();
    final resultado = await OpenFilex.open(
      widget.archivo.path,
      type: widget.elemento.mime,
    );
    if (!mounted) return;
    if (resultado.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensajeError(resultado.type)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _mensajeError(ResultType tipo) => switch (tipo) {
    ResultType.noAppToOpen =>
      'No hay ninguna app instalada que pueda abrir este archivo.',
    ResultType.permissionDenied => 'Sin permiso para abrir el archivo.',
    ResultType.error => 'No se pudo abrir el archivo.',
    _ => 'Error desconocido.',
  };

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: widget.elemento.nombre,
      acciones: [
        // Siempre disponible como alternativa al visor interno
        IconButton(
          tooltip: 'Abrir con otra app',
          onPressed: _abrirConAppExterna,
          icon: const Icon(Icons.open_in_new_outlined, color: Colors.white),
        ),
      ],
      child: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_esPdf) return _vistaPdf();
    if (_esImagen) return _vistaImagen();
    return _tarjetaExterna();
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Widget _vistaPdf() {
    if (_cargandoPdf) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    if (_errorPdf != null) {
      return _estadoError(_errorPdf!);
    }
    return Column(
      children: [
        _controlesPdf(),
        Expanded(
          child: _modoPagina ? _vistaPdfPorPagina() : _vistaPdfContinuo(),
        ),
      ],
    );
  }

  Widget _controlesPdf() {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_agenda_outlined),
                  label: Text('Continuo'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('Página'),
                ),
              ],
              selected: {_modoPagina},
              onSelectionChanged: (selection) => _cambiarModo(selection.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStatePropertyAll(Colors.white),
                side: WidgetStatePropertyAll(
                  BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                ),
              ),
            ),
            const Spacer(),
            if (_modoPagina) ...[
              IconButton(
                tooltip: 'Página anterior',
                onPressed: _paginaActual > 1 ? _paginaAnterior : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                _totalPaginas == 0
                    ? '$_paginaActual'
                    : '$_paginaActual / $_totalPaginas',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              IconButton(
                tooltip: 'Página siguiente',
                onPressed: _paginaActual < _totalPaginas
                    ? _paginaSiguiente
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ] else
              Text(
                _totalPaginas == 0 ? 'PDF' : '$_totalPaginas páginas',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _vistaPdfContinuo() {
    return PdfViewPinch(
      controller: _controladorPdfContinuo!,
      scrollDirection: Axis.vertical,
      padding: 12,
      onPageChanged: _actualizarPagina,
      onDocumentLoaded: (document) {
        if (mounted) setState(() => _totalPaginas = document.pagesCount);
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => _cargadorPdf(),
        pageLoaderBuilder: (_) => _cargadorPaginaPdf(),
        errorBuilder: (_, error) => _estadoError(error.toString()),
      ),
    );
  }

  Widget _vistaPdfPorPagina() {
    return PdfView(
      controller: _controladorPdfPagina!,
      scrollDirection: Axis.horizontal,
      renderer: (page) => page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      ),
      onPageChanged: _actualizarPagina,
      onDocumentLoaded: (document) {
        if (mounted) setState(() => _totalPaginas = document.pagesCount);
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => _cargadorPdf(),
        pageLoaderBuilder: (_) => _cargadorPaginaPdf(),
        errorBuilder: (_, error) => _estadoError(error.toString()),
      ),
    );
  }

  Widget _cargadorPdf() {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }

  Widget _cargadorPaginaPdf() {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }

  // ─── IMAGEN ───────────────────────────────────────────────────────────────

  Widget _vistaImagen() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6.0,
      child: Center(
        child: Image.file(
          widget.archivo,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              _estadoError('No se pudo mostrar la imagen.'),
        ),
      ),
    );
  }

  // ─── OFFICE / DESCONOCIDO ─────────────────────────────────────────────────

  Widget _tarjetaExterna() {
    final tamano = widget.elemento.tamano;
    final mime = widget.elemento.mime ?? '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconoPorMime(widget.elemento.mime),
              size: 38,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.elemento.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (tamano != null)
            Text(
              _formatoTamano(tamano),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            _etiquetaMime(mime),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 36),
          _botonAbrir(),
          const SizedBox(height: 16),
          Text(
            'Este tipo de archivo se abre con una app externa.\nFlutter no tiene un visor nativo para este formato.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonAbrir() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _abrirConAppExterna,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          height: 52,
          width: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_new_outlined, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Abrir con app externa',
                style: TextStyle(
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

  Widget _estadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 42,
              color: Colors.white.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _abrirConAppExterna,
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Abrir con otra app'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Utilidades ───────────────────────────────────────────────────────────

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

  static String _etiquetaMime(String mime) => switch (mime) {
    'application/msword' => 'WORD',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
      'WORD',
    'application/vnd.ms-excel' => 'EXCEL',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
      'EXCEL',
    'application/vnd.ms-powerpoint' => 'POWERPOINT',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
      'POWERPOINT',
    String s when s.startsWith('image/') => 'IMAGEN',
    'application/pdf' => 'PDF',
    _ => mime.toUpperCase(),
  };

  static String _formatoTamano(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
