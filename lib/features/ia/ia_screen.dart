import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/bouncing_widget.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/media_preview.dart';
import '../../services/theme_config_service.dart';
import '../../services/document_reader.dart';
import '../drive/datos/drive_repositorio.dart';
import '../drive/modelos/drive_elemento.dart';
import 'chat_ia_controlador.dart';
import 'modelos/mensaje_chat.dart';
import 'rendering/message_renderer.dart';
import 'widgets/selector_carpeta_contexto.dart';

class IaScreen extends StatefulWidget {
  const IaScreen({super.key});

  @override
  State<IaScreen> createState() => _IaScreenState();
}

class _IaScreenState extends State<IaScreen> with TickerProviderStateMixin {
  static const _tamanoMaximoAdjunto = 100 * 1024 * 1024;

  late final ChatIaControlador _controlador;
  late final TextEditingController _textoCtr;
  late final ScrollController _scrollCtr;
  late final FocusNode _foco;
  bool _procesandoAdjuntos = false;
  String? _estadoAdjuntos;

  @override
  void initState() {
    super.initState();
    _controlador = ChatIaControlador();
    _textoCtr = TextEditingController();
    _scrollCtr = ScrollController();
    _foco = FocusNode();
    _controlador.addListener(_onControladorCambio);
    _controlador.cargarChatsRecientes();
  }

  @override
  void dispose() {
    _controlador.removeListener(_onControladorCambio);
    _controlador.dispose();
    _textoCtr.dispose();
    _scrollCtr.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _onControladorCambio() {
    if (mounted) {
      setState(() {});
      _irAlFinal();
    }
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtr.hasClients) {
        _scrollCtr.animateTo(
          _scrollCtr.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _textoCtr.text.trim();
    final imagenesAdjuntas = _controlador.parteImagenesAdjunta;
    if (texto.isEmpty &&
        (imagenesAdjuntas == null || imagenesAdjuntas.isEmpty)) {
      return;
    }
    if (_controlador.cargando) return;
    _textoCtr.clear();
    _controlador.parteImagenesAdjunta = null;
    HapticFeedback.lightImpact();
    await _controlador.enviar(texto, imagenesAdjuntas: imagenesAdjuntas);
  }

  Future<void> _abrirSelectorCarpeta() async {
    HapticFeedback.selectionClick();
    final carpeta = await showModalBottomSheet<DriveElemento>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SelectorCarpetaContexto(repositorio: DriveRepositorio()),
    );
    if (carpeta == null || !mounted) return;
    await _controlador.asignarCarpetaContexto(carpeta);
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfigService>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo dinámico
          if (themeConfig.isSolidBlack)
            Container(color: Colors.black)
          else if (themeConfig.isSolidWhite)
            Container(color: Colors.white)
          else
            Image.asset(themeConfig.fondoPath, fit: BoxFit.cover),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(themeConfig),
                _buildChipContexto(themeConfig),
                Expanded(child: _buildListaMensajes(themeConfig)),
                _buildBarraInput(themeConfig),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AppBar glass ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(ThemeConfigService themeConfig) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
      child: Row(
        children: [
          BouncingWidget(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Icono de estrella animado
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KILLUA AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _controlador.cargando
                      ? 'Escribiendo...'
                      : 'Asistente inteligente',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Chats recientes',
            child: IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white70),
              onPressed: _mostrarChatsRecientes,
            ),
          ),
          // Botón adjuntar contexto
          Tooltip(
            message: 'Adjuntar carpeta como contexto',
            child: IconButton(
              icon: Icon(
                Icons.folder_copy_outlined,
                color: _controlador.carpetaContexto != null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
              onPressed: _abrirSelectorCarpeta,
            ),
          ),
          // Botón limpiar historial
          if (_controlador.historial.isNotEmpty)
            Tooltip(
              message: 'Limpiar conversación',
              child: IconButton(
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 22,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _controlador.limpiarHistorial();
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _mostrarChatsRecientes() async {
    final chat = await showModalBottomSheet<ChatGuardado>(
      context: context,
      backgroundColor: const Color(0xFF20222B),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 420,
          child: _controlador.chatsRecientes.isEmpty
              ? const Center(
                  child: Text(
                    'Todavía no hay chats guardados.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _controlador.chatsRecientes.length,
                  itemBuilder: (_, index) {
                    final reciente = _controlador.chatsRecientes[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white70,
                      ),
                      title: Text(
                        reciente.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${reciente.mensajes.length} mensajes',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () => Navigator.pop(sheetContext, reciente),
                    );
                  },
                ),
        ),
      ),
    );
    if (chat != null && mounted) await _controlador.abrirChatReciente(chat);
  }

  // ─── Chip de contexto ─────────────────────────────────────────────────────────

  Widget _buildChipContexto(ThemeConfigService themeConfig) {
    final carpeta = _controlador.carpetaContexto;
    if (carpeta == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Contexto: ${carpeta.nombre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _controlador.quitarCarpetaContexto,
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Lista de mensajes ────────────────────────────────────────────────────────

  Widget _buildListaMensajes(ThemeConfigService themeConfig) {
    final historial = _controlador.historial;

    if (historial.isEmpty && !_controlador.cargando) {
      return _buildEstadoVacio();
    }

    return ListView.builder(
      controller: _scrollCtr,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: historial.length + (_controlador.cargando ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == historial.length) {
          // Indicador de "escribiendo"
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _TypingIndicator(),
            ),
          );
        }
        final mensaje = historial[i];
        return _BurbujaMensaje(mensaje: mensaje);
      },
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono central brillante
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'KILLUA AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu asistente de segundo cerebro.\nPuedo crear notas, organizar ideas\ny actuar sobre tu Drive.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // Sugerencias rápidas
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SugerenciaChip(
                  texto: '📁 Adjunta una carpeta',
                  onTap: _abrirSelectorCarpeta,
                ),
                _SugerenciaChip(
                  texto: '📝 Crea un curso sobre...',
                  onTap: () {
                    _textoCtr.text = 'Crea un curso completo sobre ';
                    _foco.requestFocus();
                  },
                ),
                _SugerenciaChip(
                  texto: '💡 Resume mis notas',
                  onTap: () {
                    _textoCtr.text =
                        'Resume las notas del contexto seleccionado';
                    _foco.requestFocus();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Barra de input ───────────────────────────────────────────────────────────

  Widget _buildBarraInput(ThemeConfigService themeConfig) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        radius: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controlador.parteImagenesAdjunta?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildAdjuntosPreview(),
              ),
            if (_procesandoAdjuntos)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Row(
                    children: [
                      if (_procesandoAdjuntos)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_procesandoAdjuntos) const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _estadoAdjuntos ?? 'Procesando adjuntos...',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Botón adjuntar imagen
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.white.withValues(alpha: 0.6),
                  onPressed: _procesandoAdjuntos
                      ? null
                      : _abrirSelectorAdjuntos,
                  tooltip: 'Adjuntar imagen o documento',
                ),
                Expanded(
                  child: TextField(
                    controller: _textoCtr,
                    focusNode: _foco,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe algo a KILLUA...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                _BotonEnviar(
                  activo:
                      (_textoCtr.text.trim().isNotEmpty ||
                          (_controlador.parteImagenesAdjunta?.isNotEmpty ??
                              false)) &&
                      !_controlador.cargando &&
                      !_procesandoAdjuntos,
                  cargando: _controlador.cargando,
                  onTap: _enviar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirSelectorAdjuntos() async {
    if (_procesandoAdjuntos) return;
    setState(() {
      _procesandoAdjuntos = true;
      _estadoAdjuntos = 'Selecciona uno o varios archivos...';
    });
    late final List<PlatformFile> resultado;
    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      resultado = pickResult?.files ?? <PlatformFile>[];
    } catch (_) {
      if (mounted) {
        setState(() {
          _procesandoAdjuntos = false;
          _estadoAdjuntos = 'No se pudo abrir el selector de archivos.';
        });
      }
      return;
    }
    if (!mounted) return;
    if (resultado.isEmpty) {
      setState(() {
        _procesandoAdjuntos = false;
        _estadoAdjuntos = 'No se seleccionó ningún archivo.';
      });
      return;
    }

    final partes = <ParteMensaje>[];
    setState(
      () => _estadoAdjuntos = 'Procesando ${resultado.length} archivo(s)...',
    );
    for (final seleccionado in resultado) {
      final ruta = seleccionado.path;
      try {
        if (ruta == null) {
          continue;
        }
        final archivo = File(ruta);
        final bytes = await archivo.readAsBytes();
        if (bytes.length > _tamanoMaximoAdjunto) {
          continue;
        }
        final extension = (seleccionado.extension ?? '').toLowerCase();
        if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'].contains(extension)) {
          final mime = switch (extension) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'gif' => 'image/gif',
            'bmp' => 'image/bmp',
            _ => 'image/jpeg',
          };
          partes.add(
            ParteMensaje.imagen('data:$mime;base64,${base64Encode(bytes)}'),
          );
          continue;
        }
        final texto = await _leerAdjunto(bytes, extension);
        if (texto != null && texto.trim().isNotEmpty) {
          partes.add(
            ParteMensaje.documento(
              nombre: seleccionado.name,
              contenido: texto.length > 12000
                  ? '${texto.substring(0, 12000)}\n[contenido truncado]'
                  : texto,
            ),
          );
        } else {
          partes.add(
            ParteMensaje.documento(
              nombre: seleccionado.name,
              contenido: '[No se pudo extraer texto de este formato. Usa el archivo como referencia y solicita una conversión si necesitas analizarlo.]',
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    if (!mounted) return;
    if (partes.isEmpty) {
      setState(() {
        _procesandoAdjuntos = false;
        _estadoAdjuntos = 'No se pudo procesar el archivo seleccionado.';
      });
      return;
    }
    _controlador.parteImagenesAdjunta = partes;
    setState(() {
      _procesandoAdjuntos = false;
      _estadoAdjuntos = null;
    });
  }

  Widget _buildAdjuntosPreview() {
    final adjuntos = _controlador.parteImagenesAdjunta!;
    return Row(
      children: [
        for (final parte in adjuntos.where(
          (parte) => parte.tipo == TipoParte.imagen,
        ))
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MiniaturaImagen(
              parte: parte,
              onDelete: () => setState(
                () => _controlador.parteImagenesAdjunta = adjuntos
                    .where((item) => item != parte)
                    .toList(),
              ),
            ),
          ),
        if (adjuntos.any((parte) => parte.tipo == TipoParte.documento))
          Expanded(
            child: Chip(
              avatar: const Icon(Icons.attach_file, size: 16),
              label: Text(_nombresAdjuntos()),
              onDeleted: () =>
                  setState(() => _controlador.parteImagenesAdjunta = null),
            ),
          ),
      ],
    );
  }

  String _nombresAdjuntos() {
    final nombres = _controlador.parteImagenesAdjunta!
        .map((parte) => parte.nombreArchivo ?? 'archivo')
        .take(2)
        .join(', ');
    final total = _controlador.parteImagenesAdjunta!.length;
    return total > 2 ? '$nombres +${total - 2}' : nombres;
  }

  Future<String?> _leerAdjunto(List<int> bytes, String extension) async {
    const textoPlano = {
      'txt',
      'md',
      'markdown',
      'json',
      'csv',
      'rtf',
      'xml',
      'yaml',
      'yml',
      'html',
      'log',
      'ini',
      'sql',
      'dart',
      'py',
      'js',
      'ts',
      'java',
      'kt',
      'css',
      'c',
      'cpp',
      'h',
    };
    if (textoPlano.contains(extension)) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    final mime = switch (extension) {
      'pdf' => 'application/pdf',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };
    return DocumentReader.extractText(bytes, mime: mime);
  }
}

// ─── Burbuja de mensaje ───────────────────────────────────────────────────────

class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.rol == RolMensaje.usuario;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: esUsuario
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esUsuario) ...[_AvatarAsistente(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: esUsuario
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _BurbujaContenido(mensaje: mensaje, esUsuario: esUsuario),
                if (mensaje.comando != null && mensaje.comando!.ejecutado)
                  _ChipAccionEjecutada(
                    descripcion: mensaje.comando!.descripcion ?? '',
                  ),
              ],
            ),
          ),
          if (esUsuario) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _AvatarAsistente extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
    );
  }
}

class _BurbujaContenido extends StatelessWidget {
  const _BurbujaContenido({required this.mensaje, required this.esUsuario});

  final MensajeChat mensaje;
  final bool esUsuario;

  @override
  Widget build(BuildContext context) {
    final textos = mensaje.partes
        .where((p) => p.tipo == TipoParte.texto)
        .map((p) => p.texto ?? '')
        .toList();
    final imagenes = mensaje.partes
        .where((p) => p.tipo == TipoParte.imagen)
        .toList();
    final documentos = mensaje.partes
        .where((p) => p.tipo == TipoParte.documento)
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(esUsuario ? 20 : 4),
          bottomRight: Radius.circular(esUsuario ? 4 : 20),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: esUsuario
              ? [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.12),
                ]
              : mensaje.esError
              ? [
                  Colors.red.withValues(alpha: 0.18),
                  Colors.red.withValues(alpha: 0.08),
                ]
              : [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.04),
                ],
        ),
        border: Border.all(
          color: esUsuario
              ? Colors.white.withValues(alpha: 0.28)
              : mensaje.esError
              ? Colors.red.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: esUsuario
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < textos.length; i++) ...[
            if (textos[i].isNotEmpty)
              // ── Mensajes del asistente: renderizador completo ───────────
              // ── Mensajes del usuario: texto simple (no escriben markdown)
              esUsuario
                  ? SelectableText(
                      textos[i],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    )
                  : MessageRenderer(
                      markdown: textos[i],
                      isError: mensaje.esError,
                    ),
            if (i < imagenes.length) _buildImagen(context, imagenes[i]),
          ],
          if (imagenes.length > textos.length)
            for (int i = textos.length; i < imagenes.length; i++)
              _buildImagen(context, imagenes[i]),
          for (final documento in documentos) _buildDocumento(documento),
        ],
      ),
    );
  }

  Widget _buildDocumento(ParteMensaje parte) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                parte.nombreArchivo ?? 'Documento adjunto',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagen(BuildContext context, ParteMensaje parte) {
    final dataUrl = parte.dataUrl;
    if (dataUrl == null || !dataUrl.startsWith('data:')) {
      return const SizedBox.shrink();
    }
    final commaIdx = dataUrl.indexOf(',');
    final base64Str = commaIdx > 0 ? dataUrl.substring(commaIdx + 1) : dataUrl;
    final bytes = base64.decode(base64Str);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _ImagenFija(
        bytes: bytes,
        onTap: () => showMediaPreview(context, image: MemoryImage(bytes)),
      ),
    );
  }
}

class _MiniaturaImagen extends StatelessWidget {
  const _MiniaturaImagen({required this.parte, required this.onDelete});

  final ParteMensaje parte;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dataUrl = parte.dataUrl ?? '';
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return const SizedBox.shrink();
    final bytes = base64.decode(dataUrl.substring(comma + 1));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _ImagenFija(
          bytes: bytes,
          onTap: () => showMediaPreview(context, image: MemoryImage(bytes)),
          width: 72,
          height: 52,
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: onDelete,
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black87,
              child: Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagenFija extends StatelessWidget {
  const _ImagenFija({
    required this.bytes,
    required this.onTap,
    this.width = mediaPreviewWidth,
    this.height = mediaPreviewHeight,
  });

  final List<int> bytes;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ColoredBox(
              color: Colors.white.withValues(alpha: 0.1),
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipAccionEjecutada extends StatelessWidget {
  const _ChipAccionEjecutada({required this.descripcion});

  final String descripcion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.greenAccent.withValues(alpha: 0.12),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 12,
              color: Colors.greenAccent.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 5),
            Text(
              descripcion,
              style: TextStyle(
                color: Colors.greenAccent.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final offset = sin((_anim.value * 2 * pi) - (i * pi / 3));
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.translate(
                  offset: Offset(0, -3 * offset.clamp(-1.0, 1.0)),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                        alpha: 0.4 + 0.5 * ((offset + 1) / 2),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─── Botón enviar ─────────────────────────────────────────────────────────────

class _BotonEnviar extends StatelessWidget {
  const _BotonEnviar({
    required this.activo,
    required this.cargando,
    required this.onTap,
  });

  final bool activo;
  final bool cargando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: activo
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: activo ? null : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: Colors.white.withValues(alpha: activo ? 0.35 : 0.12),
          ),
        ),
        child: cargando
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: activo ? 1.0 : 0.3),
              ),
      ),
    );
  }
}

// ─── Chip de sugerencia ───────────────────────────────────────────────────────

class _SugerenciaChip extends StatelessWidget {
  const _SugerenciaChip({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
