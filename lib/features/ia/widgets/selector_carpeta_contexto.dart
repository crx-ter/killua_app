import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../drive/datos/drive_repositorio.dart';
import '../../drive/modelos/drive_elemento.dart';

/// Bottom sheet navegable para seleccionar una carpeta del Drive como
/// contexto del chat IA.
class SelectorCarpetaContexto extends StatefulWidget {
  const SelectorCarpetaContexto({super.key, required this.repositorio});

  final DriveRepositorio repositorio;

  @override
  State<SelectorCarpetaContexto> createState() =>
      _SelectorCarpetaContextoState();
}

class _SelectorCarpetaContextoState extends State<SelectorCarpetaContexto> {
  /// Pila de carpetas navegadas (para poder ir hacia atrás).
  final List<DriveElemento> _pilaNavegacion = [];
  String? _carpetaActualId;
  late Future<List<DriveElemento>> _elementos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _elementos = widget.repositorio.listar(_carpetaActualId).then(
      (lista) => lista
          .where((e) => e.tipo == TipoElementoDrive.carpeta)
          .toList(),
    );
  }

  void _entrar(DriveElemento carpeta) {
    HapticFeedback.selectionClick();
    setState(() {
      _pilaNavegacion.add(carpeta);
      _carpetaActualId = carpeta.id;
      _cargar();
    });
  }

  void _retroceder() {
    HapticFeedback.selectionClick();
    if (_pilaNavegacion.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _pilaNavegacion.removeLast();
      _carpetaActualId =
          _pilaNavegacion.isEmpty ? null : _pilaNavegacion.last.id;
      _cargar();
    });
  }

  void _seleccionar(DriveElemento carpeta) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(carpeta);
  }

  @override
  Widget build(BuildContext context) {
    final carpetaActual = _pilaNavegacion.isEmpty
        ? null
        : _pilaNavegacion.last;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D26),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // ── Encabezado ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _pilaNavegacion.isEmpty
                        ? Icons.close
                        : Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  onPressed: _retroceder,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seleccionar carpeta',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        carpetaActual?.nombre ?? 'Drive',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botón "Usar esta carpeta" si estamos dentro de alguna
                if (carpetaActual != null)
                  TextButton.icon(
                    onPressed: () => _seleccionar(carpetaActual),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: const Text('Usar esta'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.85),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white10),

          // ── Lista de carpetas ─────────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: FutureBuilder<List<DriveElemento>>(
              future: _elementos,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error al cargar carpetas.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                }
                final carpetas = snap.data!;
                if (carpetas.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 32,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          carpetaActual == null
                              ? 'No tienes carpetas aún.\nCrea una en el Drive primero.'
                              : 'Esta carpeta no tiene subcarpetas.\nPuedes usar esta carpeta directamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: carpetas.length,
                  itemBuilder: (context, i) {
                    final carpeta = carpetas[i];
                    return _ItemCarpeta(
                      carpeta: carpeta,
                      onEntrar: () => _entrar(carpeta),
                      onSeleccionar: () => _seleccionar(carpeta),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCarpeta extends StatelessWidget {
  const _ItemCarpeta({
    required this.carpeta,
    required this.onEntrar,
    required this.onSeleccionar,
  });

  final DriveElemento carpeta;
  final VoidCallback onEntrar;
  final VoidCallback onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSeleccionar,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.folder_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    carpeta.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Botón de navegación para entrar a subcarpetas
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  onPressed: onEntrar,
                  tooltip: 'Ver subcarpetas',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
