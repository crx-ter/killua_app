import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DialogoImportarJson extends StatefulWidget {
  const DialogoImportarJson({super.key});

  @override
  State<DialogoImportarJson> createState() => _DialogoImportarJsonState();
}

class _DialogoImportarJsonState extends State<DialogoImportarJson> {
  final _controladorTexto = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _controladorTexto.dispose();
    super.dispose();
  }

  Future<void> _importarDesdeArchivo() async {
    HapticFeedback.selectionClick();
    if (_cargando) return;
    setState(() => _cargando = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      final archivo = result == null || result.files.isEmpty
          ? null
          : result.files.first;
      if (archivo == null || !mounted) return;

      final ruta = archivo.path;
      if (ruta == null) {
        setState(() => _error = 'No se pudo obtener la ruta del archivo.');
        return;
      }

      final contenido = await File(ruta).readAsString();
      _intentarParsear(contenido);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al leer el archivo.');
    } finally {
      if (mounted && _cargando) setState(() => _cargando = false);
    }
  }

  void _importarDesdeTexto() {
    HapticFeedback.selectionClick();
    if (_cargando) return;
    setState(() => _cargando = true);
    _intentarParsear(_controladorTexto.text);
  }

  void _intentarParsear(String texto) {
    if (texto.trim().isEmpty) {
      setState(() {
        _error = 'El texto está vacío.';
        _cargando = false;
      });
      return;
    }

    try {
      final data = jsonDecode(texto);
      if (mounted) Navigator.of(context).pop(data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Formato JSON inválido.';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Importar Curso',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controladorTexto,
            maxLines: 6,
            minLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Pega el código JSON aquí...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargando ? null : _importarDesdeArchivo,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('O seleccionar un archivo .json'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _cargando ? null : _importarDesdeTexto,
                child: _cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Importar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
