import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/herramienta_scaffold.dart';
import '../../../services/theme_config_service.dart';
import 'appflowy_custom_blocks.dart';
import '../datos/drive_base_datos.dart';
import '../datos/drive_repositorio.dart';
import '../modelos/drive_elemento.dart';

class NotaEditorScreen extends StatefulWidget {
  const NotaEditorScreen({
    super.key,
    required this.nota,
    required this.repositorio,
  });

  final DriveElemento nota;
  final DriveRepositorio repositorio;

  @override
  State<NotaEditorScreen> createState() => _NotaEditorScreenState();
}

class _NotaEditorScreenState extends State<NotaEditorScreen> {
  static const _debounce = Duration(milliseconds: 700);

  late final EditorState _editorState;
  StreamSubscription<EditorTransactionValue>? _transactions;
  Timer? _saveTimer;
  bool _modoEdicion = false;
  bool _cambiosPendientes = false;
  bool _puedeSalir = false;
  bool _saliendo = false;
  late DateTime _modificado;
  late final Map<String, BlockComponentBuilder> _blockComponentBuilders;

  @override
  void initState() {
    super.initState();
    _modificado = widget.nota.modificado;
    _editorState = _buildEditorState(widget.nota.contenido ?? '');
    _blockComponentBuilders = {
      ...standardBlockComponentBuilderMap,
      ...customBlockBuilders,
    };
    _editorState.editable = false;
    _transactions = _editorState.transactionStream.listen((_) {
      if (!_modoEdicion || !mounted) return;
      setState(() => _cambiosPendientes = true);
      _saveTimer?.cancel();
      _saveTimer = Timer(_debounce, _guardar);
    });
  }

  EditorState _buildEditorState(String raw) {
    if (raw.trim().isEmpty) return EditorState.blank(withInitialText: true);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['document'] is Map) {
        return EditorState(document: Document.fromJson(decoded));
      }
    } catch (_) {
      // Markdown or plain text fallback.
    }

    try {
      return EditorState(document: markdownToDocument(raw));
    } catch (_) {
      return EditorState.blank(withInitialText: true);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _transactions?.cancel();
    _editorState.dispose();
    super.dispose();
  }

  void _alternarEdicion() {
    if (widget.nota.protegida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta nota fue generada por IA y está protegida.'),
        ),
      );
      return;
    }
    setState(() {
      _modoEdicion = !_modoEdicion;
      _editorState.editable = _modoEdicion;
    });
    if (!_modoEdicion && _cambiosPendientes) unawaited(_guardar());
  }

  Future<void> _guardar() async {
    _saveTimer?.cancel();
    if (!_cambiosPendientes) return;
    setState(() => _cambiosPendientes = false);
    final contenido = jsonEncode(_editorState.document.toJson());
    try {
      await widget.repositorio.actualizarNota(widget.nota.id, contenido);
      if (mounted) setState(() => _modificado = DateTime.now());
    } catch (_) {
      if (!mounted) return;
      setState(() => _cambiosPendientes = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la nota.')),
      );
    }
  }

  Future<void> _salir() async {
    if (_saliendo) return;
    _saliendo = true;
    await _guardar();
    if (!mounted) return;
    setState(() => _puedeSalir = true);
    Navigator.of(context).pop();
  }

  Future<void> _insertarImagen() async {
    if (!_modoEdicion) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final sourcePath = result == null || result.files.isEmpty
        ? null
        : result.files.first.path;
    if (sourcePath == null) return;

    final folder = await DriveBaseDatos.instancia.carpetaDocumentos;
    final source = File(sourcePath);
    final extension = source.path.split('.').last.toLowerCase();
    final destination = File(
      '${folder.path}${Platform.pathSeparator}${const Uuid().v4()}.$extension',
    );
    await destination.parent.create(recursive: true);
    await source.copy(destination.path);
    await _editorState.insertImageNode(destination.path);
  }

  Future<void> _insertarBloque(_TipoBloque tipo) async {
    if (!_modoEdicion) return;

    try {
      final node = await _crearNodoBloque(tipo);
      if (node == null || !mounted) return;

      final selectedBlock = _bloqueSeleccionado();
      final children = _editorState.document.root.children;
      final path =
          selectedBlock?.path.next ??
          (children.isEmpty ? <int>[0] : children.last.path.next);
      final paragraphPath = path.next;
      final transaction = _editorState.transaction
        ..insertNode(path, node)
        ..insertNode(paragraphPath, paragraphNode())
        ..afterSelection = Selection.collapsed(Position(path: paragraphPath));
      await _editorState.apply(transaction);
    } catch (_) {
      _mostrarError('No se pudo insertar el bloque. Inténtalo de nuevo.');
    }
  }

  Future<Node?> _crearNodoBloque(_TipoBloque tipo) async {
    switch (tipo) {
      case _TipoBloque.encabezado1:
        return headingNode(level: 1);
      case _TipoBloque.encabezado2:
        return headingNode(level: 2);
      case _TipoBloque.bullets:
        return bulletedListNode();
      case _TipoBloque.numerada:
        return numberedListNode();
      case _TipoBloque.checklist:
        return todoListNode(checked: false);
      case _TipoBloque.cita:
        return quoteNode();
      case _TipoBloque.separador:
        return dividerNode();
      case _TipoBloque.tabla:
        return TableNode.fromList([
          ['', ''],
          ['', ''],
        ]).node;
      case _TipoBloque.codigo:
        final values = await _pedirDatosBloque(
          titulo: 'Bloque de código',
          campos: const ['Lenguaje', 'Código'],
          valoresIniciales: const ['dart', ''],
          campoMultilinea: 1,
        );
        if (values == null) return null;
        return _crearBloquePersonalizado(
          CustomBlockData(
            type: 'code_block',
            language: values[0],
            content: values[1],
          ),
        );
      case _TipoBloque.enlace:
        final values = await _pedirDatosBloque(
          titulo: 'Vista previa de enlace',
          campos: const ['URL', 'Título'],
        );
        if (values == null) return null;
        return _crearBloquePersonalizado(
          CustomBlockData(
            type: 'link_preview',
            url: values[0],
            title: values[1],
          ),
        );
      case _TipoBloque.video:
        final values = await _pedirDatosBloque(
          titulo: 'Video',
          campos: const ['URL del video', 'Título'],
        );
        if (values == null) return null;
        return _crearBloquePersonalizado(
          CustomBlockData(
            type: 'video_block',
            url: values[0],
            title: values[1],
          ),
        );
    }
  }

  Node? _bloqueSeleccionado() {
    final selection = _editorState.selection;
    if (selection == null) return null;
    var node = _editorState.getNodeAtPath(selection.start.path);
    while (node != null && node.parent?.type != PageBlockKeys.type) {
      node = node.parent;
    }
    return node;
  }

  Future<void> _editarBloqueSeleccionado() async {
    final node = _bloqueSeleccionado();
    if (node == null) return;

    final type = node.type;
    final values = switch (type) {
      'code_block' => await _pedirDatosBloque(
        titulo: 'Editar bloque de código',
        campos: const ['Lenguaje', 'Código'],
        valoresIniciales: [
          node.attributes['language'] as String? ?? 'text',
          node.attributes['content'] as String? ?? '',
        ],
        campoMultilinea: 1,
      ),
      'link_preview' => await _pedirDatosBloque(
        titulo: 'Editar enlace',
        campos: const ['URL', 'Título'],
        valoresIniciales: [
          node.attributes['url'] as String? ?? '',
          node.attributes['title'] as String? ?? '',
        ],
      ),
      'video_block' => await _pedirDatosBloque(
        titulo: 'Editar video',
        campos: const ['URL del video', 'Título'],
        valoresIniciales: [
          node.attributes['url'] as String? ?? '',
          node.attributes['title'] as String? ?? '',
        ],
      ),
      _ => null,
    };
    if (values == null || !mounted) return;

    final attributes = switch (type) {
      'code_block' => {'language': values[0], 'content': values[1]},
      _ => {'url': values[0], 'title': values[1]},
    };
    final transaction = _editorState.transaction..updateNode(node, attributes);
    await _editorState.apply(transaction);
  }

  Future<void> _agregarFilaOColumna({required bool fila}) async {
    final table = _bloqueSeleccionado();
    if (table == null || table.type != TableBlockKeys.type) return;

    final cols = table.attributes[TableBlockKeys.colsLen] as int;
    final rows = table.attributes[TableBlockKeys.rowsLen] as int;
    final oldCellCount = table.children.length;
    final addedCount = fila ? cols : rows;
    final newPosition = fila ? rows : cols;
    final transaction = _editorState.transaction;

    for (var offset = 0; offset < addedCount; offset++) {
      final col = fila ? offset : newPosition;
      final row = fila ? newPosition : offset;
      final cell = Node(
        type: TableCellBlockKeys.type,
        attributes: {
          TableCellBlockKeys.colPosition: col,
          TableCellBlockKeys.rowPosition: row,
        },
        children: [paragraphNode()],
      );
      transaction.insertNode(table.path + [oldCellCount + offset], cell);
    }

    transaction.updateNode(table, {
      if (fila) TableBlockKeys.rowsLen: rows + 1,
      if (!fila) TableBlockKeys.colsLen: cols + 1,
    });
    transaction.afterSelection = Selection.collapsed(
      Position(path: table.path + [oldCellCount, 0]),
    );
    await _editorState.apply(transaction);
  }

  Future<void> _eliminarBloqueSeleccionado() async {
    final node = _bloqueSeleccionado();
    if (node == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar bloque'),
        content: const Text('Esta acción eliminará el bloque seleccionado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final children = _editorState.document.root.children;
    final path = node.path;
    final transaction = _editorState.transaction..deleteNode(node);
    if (children.length == 1) {
      transaction
        ..insertNode(path, paragraphNode())
        ..afterSelection = Selection.collapsed(Position(path: path));
    } else {
      transaction.afterSelection = null;
    }
    await _editorState.apply(transaction);
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Node _crearBloquePersonalizado(CustomBlockData data) =>
      Node(type: data.type, attributes: data.toAttributes());

  Future<List<String>?> _pedirDatosBloque({
    required String titulo,
    required List<String> campos,
    List<String> valoresIniciales = const [],
    int campoMultilinea = -1,
  }) async {
    final controllers = List.generate(
      campos.length,
      (index) => TextEditingController(
        text: index < valoresIniciales.length ? valoresIniciales[index] : '',
      ),
    );
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < campos.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                TextField(
                  controller: controllers[index],
                  autofocus: index == 0,
                  minLines: index == campoMultilinea ? 5 : 1,
                  maxLines: index == campoMultilinea ? 10 : 1,
                  decoration: InputDecoration(
                    labelText: campos[index],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controllers.map((controller) => controller.text.trim()).toList(),
            ),
            child: const Text('Insertar'),
          ),
        ],
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (values == null || values.first.isEmpty) return null;
    return values;
  }

  Widget _buildToolbar() {
    if (!_modoEdicion) return const SizedBox.shrink();
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(
              Icons.format_bold,
              'Negrita',
              () => _editorState.toggleAttribute(AppFlowyRichTextKeys.bold),
            ),
            _toolbarButton(
              Icons.format_italic,
              'Cursiva',
              () => _editorState.toggleAttribute(AppFlowyRichTextKeys.italic),
            ),
            _toolbarButton(
              Icons.format_underlined,
              'Subrayado',
              () =>
                  _editorState.toggleAttribute(AppFlowyRichTextKeys.underline),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<_TipoBloque>(
              tooltip: 'Insertar bloque',
              icon: const Icon(Icons.add_box_outlined),
              onSelected: (tipo) => unawaited(_insertarBloque(tipo)),
              itemBuilder: (context) => [
                _itemBloque(
                  _TipoBloque.encabezado1,
                  'Encabezado 1',
                  Icons.title,
                ),
                _itemBloque(
                  _TipoBloque.encabezado2,
                  'Encabezado 2',
                  Icons.text_fields,
                ),
                _itemBloque(
                  _TipoBloque.bullets,
                  'Lista con viñetas',
                  Icons.format_list_bulleted,
                ),
                _itemBloque(
                  _TipoBloque.numerada,
                  'Lista numerada',
                  Icons.format_list_numbered,
                ),
                _itemBloque(
                  _TipoBloque.checklist,
                  'Checklist',
                  Icons.checklist,
                ),
                _itemBloque(_TipoBloque.cita, 'Cita', Icons.format_quote),
                _itemBloque(
                  _TipoBloque.separador,
                  'Separador',
                  Icons.horizontal_rule,
                ),
                _itemBloque(
                  _TipoBloque.tabla,
                  'Tabla 2 x 2',
                  Icons.table_chart_outlined,
                ),
                _itemBloque(_TipoBloque.codigo, 'Bloque de código', Icons.code),
                _itemBloque(
                  _TipoBloque.enlace,
                  'Vista previa de enlace',
                  Icons.link,
                ),
                _itemBloque(
                  _TipoBloque.video,
                  'Video',
                  Icons.video_library_outlined,
                ),
              ],
            ),
            _toolbarButton(
              Icons.image_outlined,
              'Insertar imagen',
              _insertarImagen,
            ),
            PopupMenuButton<_AccionBloque>(
              tooltip: 'Acciones del bloque',
              icon: const Icon(Icons.more_horiz),
              onSelected: (accion) {
                switch (accion) {
                  case _AccionBloque.editar:
                    unawaited(_editarBloqueSeleccionado());
                  case _AccionBloque.agregarFila:
                    unawaited(_agregarFilaOColumna(fila: true));
                  case _AccionBloque.agregarColumna:
                    unawaited(_agregarFilaOColumna(fila: false));
                  case _AccionBloque.eliminar:
                    unawaited(_eliminarBloqueSeleccionado());
                }
              },
              itemBuilder: (context) {
                final block = _bloqueSeleccionado();
                final isCustom =
                    block?.type == 'code_block' ||
                    block?.type == 'link_preview' ||
                    block?.type == 'video_block';
                final isTable = block?.type == TableBlockKeys.type;
                return [
                  if (isCustom)
                    const PopupMenuItem(
                      value: _AccionBloque.editar,
                      child: Text('Editar bloque'),
                    ),
                  if (isTable) ...[
                    const PopupMenuItem(
                      value: _AccionBloque.agregarFila,
                      child: Text('Añadir fila'),
                    ),
                    const PopupMenuItem(
                      value: _AccionBloque.agregarColumna,
                      child: Text('Añadir columna'),
                    ),
                  ],
                  if (block != null)
                    const PopupMenuItem(
                      value: _AccionBloque.eliminar,
                      child: Text('Eliminar bloque'),
                    ),
                  if (block == null)
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('Selecciona un bloque primero'),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_TipoBloque> _itemBloque(
    _TipoBloque tipo,
    String label,
    IconData icon,
  ) => PopupMenuItem(
    value: tipo,
    child: Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
    ),
  );

  Widget _toolbarButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon, color: Colors.white70, size: 20),
  );

  @override
  Widget build(BuildContext context) {
    final textColor = Provider.of<ThemeConfigService>(context).currentTextColor;
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _puedeSalir,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_salir());
      },
      child: HerramientaScaffold(
        titulo: widget.nota.nombre,
        alVolver: () => unawaited(_salir()),
        acciones: [
          if (_cambiosPendientes)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white54,
                ),
              ),
            ),
          if (_modoEdicion)
            IconButton(
              tooltip: 'Deshacer',
              onPressed: _editorState.undoManager.undoStack.isEmpty
                  ? null
                  : _editorState.undoManager.undo,
              icon: const Icon(Icons.undo, color: Colors.white70),
            ),
          if (_modoEdicion)
            IconButton(
              tooltip: 'Rehacer',
              onPressed: _editorState.undoManager.redoStack.isEmpty
                  ? null
                  : _editorState.undoManager.redo,
              icon: const Icon(Icons.redo, color: Colors.white70),
            ),
          IconButton(
            tooltip: _modoEdicion ? 'Guardar y salir' : 'Editar',
            onPressed: _alternarEdicion,
            icon: Icon(
              _modoEdicion ? Icons.check_circle_outline : Icons.edit_outlined,
              color: _modoEdicion ? Colors.greenAccent : Colors.white70,
            ),
          ),
        ],
        barraInferior: _modoEdicion && tecladoAbierto ? _buildToolbar() : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _fechaCorta(_modificado),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: AppFlowyEditor(
                  editorState: _editorState,
                  editable: _modoEdicion,
                  autoFocus: false,
                  blockComponentBuilders: _blockComponentBuilders,
                  editorStyle: EditorStyle.mobile(
                    cursorColor: _modoEdicion
                        ? const Color(0xFF00BCF0)
                        : Colors.transparent,
                    selectionColor: _modoEdicion
                        ? const Color.fromARGB(53, 111, 201, 231)
                        : Colors.transparent,
                    dragHandleColor: _modoEdicion
                        ? const Color(0xFF00BCF0)
                        : Colors.transparent,
                    textStyleConfiguration: TextStyleConfiguration(
                      text: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fechaCorta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')} '
        '${_mes(fecha.month)} · ${fecha.hour.toString().padLeft(2, '0')}'
        ':${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _mes(int month) {
    const meses = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return meses[month - 1];
  }
}

enum _TipoBloque {
  encabezado1,
  encabezado2,
  bullets,
  numerada,
  checklist,
  cita,
  separador,
  tabla,
  codigo,
  enlace,
  video,
}

enum _AccionBloque { editar, agregarFila, agregarColumna, eliminar }
